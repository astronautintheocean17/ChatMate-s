-- ChatMate — exact three-way join modes
--
-- RUN THIS ON AN EXISTING PROJECT AFTER 0002_invite_links.sql.
-- It is safe to run more than once.
--
-- 1. Request only  -> private + request: exact code/ID, creator approves.
-- 2. Open link     -> public + open + open_to_all = false: link/code only,
--                     joins instantly, never appears in search.
-- 3. Open to all   -> public + open + open_to_all = true: searchable, joins
--                     instantly with or without the link.
--
-- Existing "open" rooms become Open link rooms (instant, link-only), which
-- fixes rooms that used to ask the creator for approval despite being "open".

begin;

-- ───────────────────────────── SCHEMA ─────────────────────────────

alter table public.rooms
  add column if not exists open_to_all boolean not null default false;

-- Normalize legacy two-toggle rows into the three supported combinations.
update public.rooms
set visibility = 'private'
where join_mode = 'request' and visibility <> 'private';

update public.rooms
set visibility = 'public'
where join_mode = 'open' and visibility <> 'public';

alter table public.rooms drop constraint if exists rooms_access_mode_check;
alter table public.rooms
  add constraint rooms_access_mode_check check (
    (join_mode = 'request' and visibility = 'private' and not open_to_all)
    or (join_mode = 'open' and visibility = 'public')
  );

-- New argument lists cannot be CREATE OR REPLACE'd over old signatures.
drop function if exists public.create_room(text, public.room_visibility, public.room_join_mode, uuid[]);
drop function if exists public.update_room(uuid, text, public.room_visibility, public.room_join_mode);
drop function if exists public.search_rooms(text);
drop function if exists public.my_rooms();

-- ─────────────────────────── FUNCTIONS ────────────────────────────

create or replace function public.create_room(
  p_name text,
  p_visibility public.room_visibility default 'private',
  p_join_mode public.room_join_mode default 'request',
  p_open_to_all boolean default false,
  p_member_ids uuid[] default '{}'
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_join_mode public.room_join_mode := coalesce(p_join_mode, 'request');
  v_visibility public.room_visibility;
  v_open_to_all boolean;
  v_code text;
  v_room_id uuid;
  v_created timestamptz;
  v_member uuid;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;
  if char_length(v_name) < 1 or char_length(v_name) > 60 then
    raise exception 'Room name must be 1-60 characters.';
  end if;

  -- Visibility and open_to_all are derived, never trusted from the client.
  if v_join_mode = 'request' then
    v_visibility := 'private';
    v_open_to_all := false;
  else
    v_visibility := 'public';
    v_open_to_all := coalesce(p_open_to_all, false);
  end if;

  v_code := public.generate_room_code();
  insert into public.rooms
    (name, code, visibility, join_mode, open_to_all, creator_id)
  values
    (v_name, v_code, v_visibility, v_join_mode, v_open_to_all, v_uid)
  returning id, created_at into v_room_id, v_created;

  insert into public.room_members (room_id, user_id, role)
  values (v_room_id, v_uid, 'creator');

  for v_member in
    select distinct x from unnest(coalesce(p_member_ids, '{}'::uuid[])) as x
  loop
    if v_member <> v_uid
       and exists (select 1 from public.profiles where id = v_member) then
      insert into public.room_requests
        (room_id, user_id, kind, created_by, status, creator_approved)
      values (v_room_id, v_member, 'invite', v_uid, 'pending', true)
      on conflict (room_id, user_id) where status = 'pending' do nothing;
    end if;
  end loop;

  return jsonb_build_object(
    'id', v_room_id,
    'name', v_name,
    'code', v_code,
    'visibility', v_visibility,
    'join_mode', v_join_mode,
    'open_to_all', v_open_to_all,
    'created_at', v_created
  );
end;
$$;

create or replace function public.search_rooms(p_query text default '')
returns table (
  id uuid,
  name text,
  code text,
  visibility public.room_visibility,
  join_mode public.room_join_mode,
  open_to_all boolean,
  creator_handle citext,
  member_count integer,
  is_member boolean,
  request_status public.request_status
)
language sql stable security definer
set search_path = public, auth
as $$
  with q as (
    select lower(btrim(coalesce(p_query, ''))) as term,
           upper(btrim(coalesce(p_query, ''))) as code_term
  )
  select
    r.id,
    r.name,
    r.code,
    r.visibility,
    r.join_mode,
    r.open_to_all,
    p.handle as creator_handle,
    (select count(*)::int from public.room_members rm where rm.room_id = r.id),
    public.is_room_member(r.id),
    case when r.join_mode = 'open' then null::public.request_status
      else (select rr.status from public.room_requests rr
        where rr.room_id = r.id
          and rr.user_id = auth.uid()
          and rr.status = 'pending'
        order by rr.created_at desc
        limit 1)
    end
  from public.rooms r
  join public.profiles p on p.id = r.creator_id
  cross join q
  where
    -- Empty search: only Open to all rooms are discoverable.
    (q.term = '' and r.join_mode = 'open' and r.open_to_all)
    or (
      q.term <> '' and (
        -- Open to all: name or exact code.
        (r.join_mode = 'open' and r.open_to_all
          and (lower(r.name) like '%' || q.term || '%' or r.code = q.code_term))
        -- Request-only and Open link: exact code only, never by name.
        or (not r.open_to_all and r.code = q.code_term)
      )
    )
  order by r.updated_at desc
  limit 40;
$$;

create or replace function public.room_details(p_room_id uuid)
returns jsonb
language sql stable security definer
set search_path = public, auth
as $$
  select jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'code', r.code,
    'visibility', r.visibility,
    'join_mode', r.join_mode,
    'open_to_all', r.open_to_all,
    'creator_id', r.creator_id,
    'creator_handle', p.handle,
    'member_count', (select count(*)::int from public.room_members rm where rm.room_id = r.id),
    'my_role', (select rm.role from public.room_members rm
                 where rm.room_id = r.id and rm.user_id = auth.uid()),
    'created_at', r.created_at
  )
  from public.rooms r
  join public.profiles p on p.id = r.creator_id
  where r.id = p_room_id and public.is_room_member(p_room_id);
$$;

create or replace function public.my_rooms()
returns table (
  id uuid,
  name text,
  code text,
  visibility public.room_visibility,
  join_mode public.room_join_mode,
  open_to_all boolean,
  creator_handle citext,
  role text,
  member_count integer,
  unread_count integer,
  last_message_at timestamptz
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    r.id,
    r.name,
    r.code,
    r.visibility,
    r.join_mode,
    r.open_to_all,
    p.handle as creator_handle,
    rm.role,
    (select count(*)::int from public.room_members rm2 where rm2.room_id = r.id),
    (select count(*)::int from public.messages m
      where m.room_id = r.id
        and m.created_at > rm.last_read_at
        and m.sender_id <> auth.uid()
        and m.deleted_at is null),
    (select max(m.created_at) from public.messages m where m.room_id = r.id)
  from public.room_members rm
  join public.rooms r on r.id = rm.room_id
  join public.profiles p on p.id = r.creator_id
  where rm.user_id = auth.uid()
  order by r.updated_at desc;
$$;

create or replace function public.request_join(p_room_id uuid)
returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.room_requests%rowtype;
  v_room public.rooms%rowtype;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  if not found then
    raise exception 'Room not found.';
  end if;
  if public.is_room_member(p_room_id) then
    return jsonb_build_object(
      'status', 'member',
      'room_id', p_room_id,
      'room_name', v_room.name,
      'code', v_room.code,
      'join_mode', v_room.join_mode,
      'open_to_all', v_room.open_to_all
    );
  end if;

  -- Open to all is the only mode that may join by room ID. Open link must
  -- arrive through join_room_by_code, which proves the person has the link.
  if v_room.join_mode = 'open' then
    if not v_room.open_to_all then
      raise exception 'This room only opens from its invite link. Use the link or code from the creator.';
    end if;

    insert into public.room_members (room_id, user_id, role)
    values (p_room_id, v_uid, 'member')
    on conflict (room_id, user_id) do nothing;

    update public.room_requests
    set status = 'accepted', responded_at = now()
    where room_id = p_room_id and user_id = v_uid and status = 'pending';

    update public.rooms set updated_at = now() where id = p_room_id;

    return jsonb_build_object(
      'status', 'member',
      'room_id', p_room_id,
      'room_name', v_room.name,
      'code', v_room.code,
      'join_mode', v_room.join_mode,
      'open_to_all', v_room.open_to_all
    );
  end if;

  -- Request only.
  select * into v_req
  from public.room_requests
  where room_id = p_room_id and user_id = v_uid and status = 'pending'
  order by created_at desc
  limit 1;

  if found then
    return jsonb_build_object(
      'status', v_req.status::text,
      'kind', v_req.kind,
      'creator_approved', v_req.creator_approved,
      'request_id', v_req.id,
      'room_id', p_room_id,
      'room_name', v_room.name,
      'code', v_room.code,
      'join_mode', v_room.join_mode,
      'open_to_all', v_room.open_to_all
    );
  end if;

  insert into public.room_requests (room_id, user_id, kind, created_by, status)
  values (p_room_id, v_uid, 'join', v_uid, 'pending')
  returning * into v_req;

  return jsonb_build_object(
    'status', 'pending',
    'kind', 'join',
    'creator_approved', false,
    'request_id', v_req.id,
    'room_id', p_room_id,
    'room_name', v_room.name,
    'code', v_room.code,
    'join_mode', v_room.join_mode,
    'open_to_all', v_room.open_to_all
  );
end;
$$;

create or replace function public.update_room(
  p_room_id uuid,
  p_name text,
  p_visibility public.room_visibility,
  p_join_mode public.room_join_mode default 'request',
  p_open_to_all boolean default false
) returns void
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_join_mode public.room_join_mode := coalesce(p_join_mode, 'request');
  v_visibility public.room_visibility;
  v_open_to_all boolean;
begin
  if not public.is_room_creator(p_room_id) then
    raise exception 'Only the room creator can edit this room.';
  end if;
  if char_length(v_name) < 1 or char_length(v_name) > 60 then
    raise exception 'Room name must be 1-60 characters.';
  end if;

  if v_join_mode = 'request' then
    v_visibility := 'private';
    v_open_to_all := false;
  else
    v_visibility := 'public';
    v_open_to_all := coalesce(p_open_to_all, false);
  end if;

  update public.rooms
  set name = v_name,
      visibility = v_visibility,
      join_mode = v_join_mode,
      open_to_all = v_open_to_all,
      updated_at = now()
  where id = p_room_id;
end;
$$;

create or replace function public.room_access_preview(p_code text)
returns jsonb
language sql stable security definer
set search_path = public, auth
as $$
  select jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'code', r.code,
    'visibility', r.visibility,
    'join_mode', r.join_mode,
    'open_to_all', r.open_to_all,
    'creator_handle', p.handle,
    'member_count', (
      select count(*)::int from public.room_members rm where rm.room_id = r.id
    ),
    'is_member', public.is_room_member(r.id),
    -- Open rooms never wait on a stale pending row from an older mode.
    'request_status', case when r.join_mode = 'open'
      then null::public.request_status
      else (select rr.status from public.room_requests rr
        where rr.room_id = r.id
          and rr.user_id = auth.uid()
          and rr.status = 'pending'
        order by rr.created_at desc limit 1)
      end,
    'request_kind', case when r.join_mode = 'open' then null
      else (select rr.kind from public.room_requests rr
        where rr.room_id = r.id
          and rr.user_id = auth.uid()
          and rr.status = 'pending'
        order by rr.created_at desc limit 1)
      end,
    'request_creator_approved', case when r.join_mode = 'open' then null
      else (select rr.creator_approved from public.room_requests rr
        where rr.room_id = r.id
          and rr.user_id = auth.uid()
          and rr.status = 'pending'
        order by rr.created_at desc limit 1)
      end
  )
  from public.rooms r
  join public.profiles p on p.id = r.creator_id
  where auth.uid() is not null
    and r.code = upper(btrim(coalesce(p_code, '')))
  limit 1;
$$;

create or replace function public.join_room_by_code(p_code text)
returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;

  select * into v_room
  from public.rooms
  where code = upper(btrim(coalesce(p_code, '')));

  if not found then
    raise exception 'That invite link is not valid. Ask for a new one.';
  end if;

  if public.is_room_member(v_room.id) then
    return jsonb_build_object(
      'status', 'member',
      'room_id', v_room.id,
      'room_name', v_room.name,
      'code', v_room.code,
      'join_mode', v_room.join_mode,
      'open_to_all', v_room.open_to_all
    );
  end if;

  -- Having the code is the link proof for both open modes.
  if v_room.join_mode = 'open' then
    insert into public.room_members (room_id, user_id, role)
    values (v_room.id, v_uid, 'member')
    on conflict (room_id, user_id) do nothing;

    update public.room_requests
    set status = 'accepted', responded_at = now()
    where room_id = v_room.id and user_id = v_uid and status = 'pending';

    update public.rooms set updated_at = now() where id = v_room.id;

    return jsonb_build_object(
      'status', 'member',
      'room_id', v_room.id,
      'room_name', v_room.name,
      'code', v_room.code,
      'join_mode', v_room.join_mode,
      'open_to_all', v_room.open_to_all
    );
  end if;

  return public.request_join(v_room.id);
end;
$$;

-- ────────────────────────── PERMISSIONS ───────────────────────────

revoke all on function public.create_room(text, public.room_visibility, public.room_join_mode, boolean, uuid[]) from public, anon;
revoke all on function public.update_room(uuid, text, public.room_visibility, public.room_join_mode, boolean) from public, anon;
revoke all on function public.search_rooms(text) from public, anon;
revoke all on function public.my_rooms() from public, anon;
revoke all on function public.room_details(uuid) from public, anon;
revoke all on function public.request_join(uuid) from public, anon;
revoke all on function public.room_access_preview(text) from public, anon;
revoke all on function public.join_room_by_code(text) from public, anon;

grant execute on function public.create_room(text, public.room_visibility, public.room_join_mode, boolean, uuid[]) to authenticated;
grant execute on function public.update_room(uuid, text, public.room_visibility, public.room_join_mode, boolean) to authenticated;
grant execute on function public.search_rooms(text) to authenticated;
grant execute on function public.my_rooms() to authenticated;
grant execute on function public.room_details(uuid) to authenticated;
grant execute on function public.request_join(uuid) to authenticated;
grant execute on function public.room_access_preview(text) to authenticated;
grant execute on function public.join_room_by_code(text) to authenticated;

commit;

-- Force Supabase/PostgREST to refresh the exposed RPC signatures.
select pg_notify('pgrst', 'reload schema');
