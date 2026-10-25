-- ChatMate — invite links + join modes upgrade
--
-- RUN THIS FILE ONLY IF YOUR SUPABASE PROJECT ALREADY HAS THE CHATMATE SCHEMA.
-- It is the short delta file for an existing project. It is safe to run twice.
--
-- IMPORTANT: Run supabase/0003_three_join_modes.sql afterwards. 0002 is the
-- schema/base upgrade; 0003 is the current three-mode join behavior.
--
-- Fresh/empty Supabase project? Run supabase/0001_init.sql instead.

begin;

-- ───────────────────────────── SCHEMA ─────────────────────────────

do $$ begin
  create type public.room_join_mode as enum ('open', 'request');
exception when duplicate_object then null; end $$;

alter table public.rooms
  add column if not exists join_mode public.room_join_mode not null
  default 'request';

-- Existing pending invites were created by the creator under the old rules,
-- so they stay acceptable. New rows default to "not creator-approved".
alter table public.room_requests
  add column if not exists creator_approved boolean not null default true;
alter table public.room_requests
  alter column creator_approved set default false;

create unique index if not exists room_requests_pending_uniq
  on public.room_requests (room_id, user_id) where status = 'pending';
create index if not exists room_requests_user_idx
  on public.room_requests (user_id, status);
create index if not exists room_requests_creator_idx
  on public.room_requests (created_by, status);

-- Old argument lists / return types must be removed before recreating.
drop function if exists public.create_room(text, public.room_visibility, uuid[]);
drop function if exists public.update_room(uuid, text, public.room_visibility);
drop function if exists public.search_rooms(text);
drop function if exists public.my_rooms();
drop function if exists public.my_requests();
drop function if exists public.room_pending_requests(uuid);

-- ─────────────────────────── FUNCTIONS ────────────────────────────

create or replace function public.create_room(
  p_name text,
  p_visibility public.room_visibility default 'private',
  p_join_mode public.room_join_mode default 'request',
  p_member_ids uuid[] default '{}'
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_visibility public.room_visibility := coalesce(p_visibility, 'private');
  v_join_mode public.room_join_mode := coalesce(p_join_mode, 'request');
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

  v_code := public.generate_room_code();
  insert into public.rooms (name, code, visibility, join_mode, creator_id)
  values (v_name, v_code, v_visibility, v_join_mode, v_uid)
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
    p.handle as creator_handle,
    (select count(*)::int from public.room_members rm where rm.room_id = r.id),
    public.is_room_member(r.id),
    (select rr.status from public.room_requests rr
      where rr.room_id = r.id
        and rr.user_id = auth.uid()
        and rr.status = 'pending'
      order by rr.created_at desc
      limit 1)
  from public.rooms r
  join public.profiles p on p.id = r.creator_id
  cross join q
  where
    (q.term = '' and r.visibility = 'public')
    or (
      q.term <> '' and (
        (r.visibility = 'public'
          and (lower(r.name) like '%' || q.term || '%' or r.code = q.code_term))
        or (r.visibility = 'private' and r.code = q.code_term)
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
      'join_mode', v_room.join_mode
    );
  end if;

  -- Both modes are creator-gated. Open mode means the invite link can be
  -- shared freely; a successful join still waits for the creator's approval.
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
      'join_mode', v_room.join_mode
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
    'join_mode', v_room.join_mode
  );
end;
$$;

create or replace function public.respond_room_request(
  p_request_id uuid,
  p_accept boolean
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.room_requests%rowtype;
  v_new_status public.request_status;
  v_is_creator boolean;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;

  select * into v_req
  from public.room_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found.';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'This request is already closed.';
  end if;

  v_is_creator := public.is_room_creator(v_req.room_id);

  if v_req.kind = 'invite' then
    if v_req.user_id = v_uid then
      -- The invited person accepts only after the creator verifies. Creator
      -- invites are verified at creation time; member invites in open rooms
      -- arrive unverified and wait for this check.
      if p_accept and not v_req.creator_approved then
        raise exception 'The room creator must verify this invite first.';
      end if;
    elsif v_is_creator then
      if not p_accept then
        update public.room_requests
        set status = 'declined', responded_at = now()
        where id = p_request_id;

        return jsonb_build_object(
          'request_id', p_request_id,
          'room_id', v_req.room_id,
          'kind', v_req.kind,
          'status', 'declined',
          'creator_approved', v_req.creator_approved
        );
      end if;

      if v_req.creator_approved then
        raise exception 'This invite is already verified.';
      end if;

      update public.room_requests
      set creator_approved = true
      where id = p_request_id;

      return jsonb_build_object(
        'request_id', p_request_id,
        'room_id', v_req.room_id,
        'kind', v_req.kind,
        'status', 'approved',
        'creator_approved', true
      );
    else
      raise exception 'Only the invited person or the room creator can respond to this invite.';
    end if;
  elsif v_req.kind = 'join' then
    if not v_is_creator then
      raise exception 'Only the room creator can approve join requests.';
    end if;
  end if;

  v_new_status := case when p_accept then 'accepted'::public.request_status
                       else 'declined'::public.request_status end;

  update public.room_requests
  set status = v_new_status, responded_at = now()
  where id = p_request_id;

  if p_accept then
    insert into public.room_members (room_id, user_id, role)
    values (v_req.room_id, v_req.user_id, 'member')
    on conflict (room_id, user_id) do nothing;

    update public.rooms set updated_at = now() where id = v_req.room_id;
  end if;

  return jsonb_build_object(
    'request_id', p_request_id,
    'room_id', v_req.room_id,
    'kind', v_req.kind,
    'status', v_new_status::text,
    'creator_approved', true
  );
end;
$$;

create or replace function public.invite_member(
  p_room_id uuid,
  p_handle text
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_target public.profiles%rowtype;
  v_join_mode public.room_join_mode;
  v_is_creator boolean;
  v_approved boolean;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;
  if not public.is_room_member(p_room_id) then
    raise exception 'Only room members can add people.';
  end if;

  select join_mode into v_join_mode from public.rooms where id = p_room_id;
  if not found then
    raise exception 'Room not found.';
  end if;
  v_is_creator := public.is_room_creator(p_room_id);
  -- Request-only rooms are stricter: only the creator may add people by ID.
  -- In open rooms any member can invite, but the creator still verifies it.
  if v_join_mode = 'request' and not v_is_creator then
    raise exception 'Only the room creator can invite people in this room.';
  end if;
  v_approved := v_is_creator;

  select * into v_target
  from public.profiles
  where handle = lower(btrim(coalesce(p_handle, '')))::citext;

  if not found then
    raise exception 'No ChatMate ID matches that handle.';
  end if;
  if v_target.id = v_uid then
    raise exception 'You are already in this room.';
  end if;
  if public.is_room_member(p_room_id, v_target.id) then
    raise exception 'That person is already in this room.';
  end if;

  if exists (
    select 1 from public.room_requests
    where room_id = p_room_id and user_id = v_target.id and status = 'pending'
  ) then
    raise exception 'There is already a pending request for that person.';
  end if;

  insert into public.room_requests
    (room_id, user_id, kind, created_by, status, creator_approved)
  values (p_room_id, v_target.id, 'invite', v_uid, 'pending', v_approved);

  return jsonb_build_object(
    'status', 'pending',
    'room_id', p_room_id,
    'handle', v_target.handle,
    'creator_approved', v_approved,
    'needs_creator_approval', not v_approved
  );
end;
$$;

create or replace function public.update_room(
  p_room_id uuid,
  p_name text,
  p_visibility public.room_visibility,
  p_join_mode public.room_join_mode default 'request'
) returns void
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_join_mode public.room_join_mode := coalesce(p_join_mode, 'request');
begin
  if not public.is_room_creator(p_room_id) then
    raise exception 'Only the room creator can edit this room.';
  end if;
  if char_length(v_name) < 1 or char_length(v_name) > 60 then
    raise exception 'Room name must be 1-60 characters.';
  end if;

  update public.rooms
  set name = v_name,
      visibility = p_visibility,
      join_mode = v_join_mode,
      updated_at = now()
  where id = p_room_id;
end;
$$;

create or replace function public.my_requests()
returns table (
  request_id uuid,
  room_id uuid,
  room_name text,
  room_code text,
  visibility public.room_visibility,
  member_count integer,
  kind text,
  status public.request_status,
  other_handle citext,
  creator_approved boolean,
  created_at timestamptz
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    rr.id as request_id,
    r.id as room_id,
    r.name as room_name,
    r.code as room_code,
    r.visibility,
    (select count(*)::int from public.room_members rm where rm.room_id = r.id),
    rr.kind,
    rr.status,
    case when rr.kind = 'invite' then inviter.handle else creator.handle end as other_handle,
    rr.creator_approved,
    rr.created_at
  from public.room_requests rr
  join public.rooms r on r.id = rr.room_id
  join public.profiles creator on creator.id = r.creator_id
  left join public.profiles inviter on inviter.id = rr.created_by
  where (rr.kind = 'invite' and rr.user_id = auth.uid())
     or (rr.kind = 'join' and rr.created_by = auth.uid())
  order by rr.created_at desc
  limit 100;
$$;

create or replace function public.room_pending_requests(p_room_id uuid)
returns table (
  request_id uuid,
  kind text,
  status public.request_status,
  user_handle citext,
  created_by_handle citext,
  creator_approved boolean,
  created_at timestamptz
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    rr.id,
    rr.kind,
    rr.status,
    p.handle,
    COALESCE(creator.handle, p.handle) as created_by_handle,
    rr.creator_approved,
    rr.created_at
  from public.room_requests rr
  join public.profiles p on p.id = rr.user_id
  left join public.profiles creator on creator.id = rr.created_by
  where rr.room_id = p_room_id
    and rr.status = 'pending'
    and public.is_room_creator(p_room_id)
  order by rr.created_at;
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
    'creator_handle', p.handle,
    'member_count', (
      select count(*)::int from public.room_members rm where rm.room_id = r.id
    ),
    'is_member', public.is_room_member(r.id),
    'request_status', (
      select rr.status from public.room_requests rr
      where rr.room_id = r.id
        and rr.user_id = auth.uid()
        and rr.status = 'pending'
      order by rr.created_at desc limit 1
    ),
    'request_kind', (
      select rr.kind from public.room_requests rr
      where rr.room_id = r.id
        and rr.user_id = auth.uid()
        and rr.status = 'pending'
      order by rr.created_at desc limit 1
    ),
    'request_creator_approved', (
      select rr.creator_approved from public.room_requests rr
      where rr.room_id = r.id
        and rr.user_id = auth.uid()
        and rr.status = 'pending'
      order by rr.created_at desc limit 1
    )
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
  v_room_id uuid;
begin
  if auth.uid() is null then
    raise exception 'You are not signed in.';
  end if;

  select id into v_room_id
  from public.rooms
  where code = upper(btrim(coalesce(p_code, '')));

  if not found then
    raise exception 'That invite link is not valid. Ask for a new one.';
  end if;

  return public.request_join(v_room_id);
end;
$$;


-- ────────────────────────── PERMISSIONS ───────────────────────────

revoke all on function public.create_room(text, public.room_visibility, public.room_join_mode, uuid[]) from public, anon;
revoke all on function public.search_rooms(text) from public, anon;
revoke all on function public.room_details(uuid) from public, anon;
revoke all on function public.my_rooms() from public, anon;
revoke all on function public.request_join(uuid) from public, anon;
revoke all on function public.respond_room_request(uuid, boolean) from public, anon;
revoke all on function public.invite_member(uuid, text) from public, anon;
revoke all on function public.update_room(uuid, text, public.room_visibility, public.room_join_mode) from public, anon;
revoke all on function public.my_requests() from public, anon;
revoke all on function public.room_pending_requests(uuid) from public, anon;
revoke all on function public.room_access_preview(text) from public, anon;
revoke all on function public.join_room_by_code(text) from public, anon;

grant execute on function public.create_room(text, public.room_visibility, public.room_join_mode, uuid[]) to authenticated;
grant execute on function public.search_rooms(text) to authenticated;
grant execute on function public.room_details(uuid) to authenticated;
grant execute on function public.my_rooms() to authenticated;
grant execute on function public.request_join(uuid) to authenticated;
grant execute on function public.respond_room_request(uuid, boolean) to authenticated;
grant execute on function public.invite_member(uuid, text) to authenticated;
grant execute on function public.update_room(uuid, text, public.room_visibility, public.room_join_mode) to authenticated;
grant execute on function public.my_requests() to authenticated;
grant execute on function public.room_pending_requests(uuid) to authenticated;
grant execute on function public.room_access_preview(text) to authenticated;
grant execute on function public.join_room_by_code(text) to authenticated;

commit;

-- Force Supabase/PostgREST to refresh the exposed RPC signatures.
select pg_notify('pgrst', 'reload schema');

