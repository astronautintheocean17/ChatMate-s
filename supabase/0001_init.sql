-- ChatMate production schema — FULL FRESH INSTALL
-- Use this on a new/empty Supabase project only.
-- Existing ChatMate project? Run supabase/0002_invite_links.sql, then
-- supabase/0003_three_join_modes.sql.
-- Run in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Safe to re-run: objects use IF NOT EXISTS / CREATE OR REPLACE.

create extension if not exists pgcrypto;
create extension if not exists citext;

do $$ begin
  create type public.room_visibility as enum ('private', 'public');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_status as enum ('pending', 'accepted', 'declined');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.room_join_mode as enum ('open', 'request');
exception when duplicate_object then null; end $$;

-- ───────────────────────────── TABLES ─────────────────────────────

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle citext not null unique,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_handle_format
    check (handle::text ~ '^[a-z0-9_]{3,24}$')
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  visibility public.room_visibility not null default 'private',
  join_mode public.room_join_mode not null default 'request',
  open_to_all boolean not null default false,
  creator_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rooms_name_length check (char_length(btrim(name)) between 1 and 60),
  constraint rooms_code_format check (code ~ '^[A-Z0-9]{6}$')
);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('creator', 'member')),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.room_requests (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('invite', 'join')),
  created_by uuid not null references public.profiles (id) on delete cascade,
  status public.request_status not null default 'pending',
  creator_approved boolean not null default false,
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

-- Safe upgrades for databases created before join modes / creator verification.
alter table public.rooms
  add column if not exists join_mode public.room_join_mode not null
  default 'request';
alter table public.rooms
  add column if not exists open_to_all boolean not null default false;

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

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null default '',
  reveal_sender boolean not null default false,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.profiles (id),
  constraint messages_body_length check (char_length(body) <= 4000)
);

create index if not exists messages_room_created_idx
  on public.messages (room_id, created_at desc);

create table if not exists public.message_reads (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

-- ─────────────────────────── HELPERS ───────────────────────────

create or replace function public.is_room_member(
  p_room_id uuid,
  p_user_id uuid default auth.uid()
) returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = p_user_id
  );
$$;

create or replace function public.is_room_creator(
  p_room_id uuid,
  p_user_id uuid default auth.uid()
) returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = p_user_id and role = 'creator'
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql stable
as $$
  select coalesce(((auth.jwt() -> 'app_metadata') ->> 'is_admin')::boolean, false);
$$;

create or replace function public.generate_room_code()
returns text
language plpgsql volatile
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  i int;
begin
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.rooms where code = v_code);
  end loop;
  return v_code;
end;
$$;

-- ─────────────────────────── RLS ───────────────────────────

alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_requests enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;

drop policy if exists "profiles are readable" on public.profiles;
create policy "profiles are readable" on public.profiles
  for select to authenticated using (true);

drop policy if exists "rooms are readable" on public.rooms;
create policy "rooms are readable" on public.rooms
  for select to authenticated using (
    visibility = 'public' or public.is_room_member(id)
  );

drop policy if exists "members are readable" on public.room_members;
create policy "members are readable" on public.room_members
  for select to authenticated using (public.is_room_member(room_id));

drop policy if exists "requests are readable" on public.room_requests;
create policy "requests are readable" on public.room_requests
  for select to authenticated using (
    user_id = auth.uid()
    or created_by = auth.uid()
    or public.is_room_creator(room_id)
  );

-- Writes are RPC-only. No INSERT/UPDATE/DELETE policies exist on purpose.
revoke all on public.profiles from anon, authenticated;
revoke all on public.rooms from anon, authenticated;
revoke all on public.room_members from anon, authenticated;
revoke all on public.room_requests from anon, authenticated;
revoke all on public.messages from anon, authenticated;
revoke all on public.message_reads from anon, authenticated;

grant select on public.profiles to authenticated;
grant select on public.rooms to authenticated;
grant select on public.room_members to authenticated;
grant select on public.room_requests to authenticated;
-- messages and message_reads are deliberately NOT selectable directly.
-- ─────────────────────── PROFILE FUNCTIONS ───────────────────────

create or replace function public.create_profile(
  p_handle text,
  p_display_name text default null
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_handle citext;
  v_display text;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;
  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'A ChatMate ID already exists for this session.';
  end if;

  v_handle := lower(btrim(coalesce(p_handle, '')))::citext;
  if v_handle::text !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'ID must be 3-24 characters: a-z, 0-9 or underscore.';
  end if;

  v_display := nullif(btrim(coalesce(p_display_name, '')), '');
  if v_display is null then
    v_display := v_handle::text;
  end if;

  begin
    insert into public.profiles (id, handle, display_name)
    values (v_uid, v_handle, v_display);
  exception when unique_violation then
    raise exception 'That ID is already taken. Try another.';
  end;

  return (
    select jsonb_build_object(
      'id', p.id, 'handle', p.handle, 'display_name', p.display_name,
      'created_at', p.created_at
    )
    from public.profiles p where p.id = v_uid
  );
end;
$$;

create or replace function public.change_handle(p_handle text)
returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_handle citext;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;
  if not exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'No ChatMate ID found for this session.';
  end if;

  v_handle := lower(btrim(coalesce(p_handle, '')))::citext;
  if v_handle::text !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'ID must be 3-24 characters: a-z, 0-9 or underscore.';
  end if;

  begin
    update public.profiles
    set handle = v_handle, display_name = v_handle::text, updated_at = now()
    where id = v_uid;
  exception when unique_violation then
    raise exception 'That ID is already taken. Try another.';
  end;

  return (
    select jsonb_build_object(
      'id', p.id, 'handle', p.handle, 'display_name', p.display_name,
      'created_at', p.created_at
    )
    from public.profiles p where p.id = v_uid
  );
end;
$$;

create or replace function public.handle_available(p_handle text)
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select case
    when lower(btrim(coalesce(p_handle, ''))) !~ '^[a-z0-9_]{3,24}$' then false
    else not exists (
      select 1 from public.profiles
      where handle = lower(btrim(p_handle))::citext
    )
  end;
$$;

-- ──────────────────────── ROOM FUNCTIONS ─────────────────────────

-- Return types changed with join modes, so old signatures must be removed
-- before CREATE OR REPLACE. The calls are no-ops on a fresh database.
drop function if exists public.create_room(text, public.room_visibility, uuid[]);
drop function if exists public.create_room(text, public.room_visibility, public.room_join_mode, uuid[]);
drop function if exists public.search_rooms(text);
drop function if exists public.my_rooms();
drop function if exists public.update_room(uuid, text, public.room_visibility);
drop function if exists public.update_room(uuid, text, public.room_visibility, public.room_join_mode);
drop function if exists public.my_requests();
drop function if exists public.room_pending_requests(uuid);

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
    (q.term = '' and r.join_mode = 'open' and r.open_to_all)
    or (
      q.term <> '' and (
        (r.join_mode = 'open' and r.open_to_all
          and (lower(r.name) like '%' || q.term || '%' or r.code = q.code_term))
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

create or replace function public.room_members_list(p_room_id uuid)
returns table (
  user_id uuid,
  handle citext,
  role text,
  joined_at timestamptz
)
language sql stable security definer
set search_path = public, auth
as $$
  select rm.user_id, p.handle, rm.role, rm.joined_at
  from public.room_members rm
  join public.profiles p on p.id = rm.user_id
  where rm.room_id = p_room_id and public.is_room_member(p_room_id)
  order by case when rm.role = 'creator' then 0 else 1 end, p.handle;
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

-- ───────────────────── REQUEST / MEMBERSHIP ──────────────────────

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

  -- Open to all may join by room ID. Open link must use join_room_by_code so
  -- the person proves they have the link/code.
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

create or replace function public.remove_member(
  p_room_id uuid,
  p_user_id uuid
) returns void
language plpgsql security definer
set search_path = public, auth
as $$
begin
  if not public.is_room_creator(p_room_id) then
    raise exception 'Only the room creator can remove members.';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'The creator cannot remove themselves.';
  end if;

  delete from public.room_members
  where room_id = p_room_id and user_id = p_user_id;

  delete from public.room_requests
  where room_id = p_room_id and user_id = p_user_id and status = 'pending';

  update public.rooms set updated_at = now() where id = p_room_id;
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

-- Preview a share link before joining. This is deliberately SECURITY DEFINER:
-- a private room is discoverable when someone presents its code, but it is not
-- searchable. No member or message data is exposed.
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

-- ─────────────────────── MESSAGE FUNCTIONS ───────────────────────

create or replace function public.send_message(
  p_room_id uuid,
  p_body text,
  p_reveal_sender boolean default false
) returns uuid
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;
  if not public.is_room_member(p_room_id) then
    raise exception 'You are not a member of this room.';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 4000 then
    raise exception 'Message must be 1-4000 characters.';
  end if;

  insert into public.messages (room_id, sender_id, body, reveal_sender)
  values (p_room_id, v_uid, v_body, coalesce(p_reveal_sender, false))
  returning id into v_id;

  update public.rooms set updated_at = now() where id = p_room_id;
  return v_id;
end;
$$;

create or replace function public.delete_message(p_message_id uuid)
returns void
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_msg public.messages%rowtype;
begin
  select * into v_msg
  from public.messages
  where id = p_message_id
  for update;

  if not found then
    raise exception 'Message not found.';
  end if;
  if v_msg.deleted_at is not null then
    return;
  end if;
  if v_msg.sender_id <> auth.uid()
     and not public.is_room_creator(v_msg.room_id) then
    raise exception 'Only the sender or room creator can delete this message.';
  end if;

  update public.messages
  set body = '', deleted_at = now(), deleted_by = auth.uid()
  where id = p_message_id;
end;
$$;

create or replace function public.mark_room_read(p_room_id uuid)
returns void
language plpgsql security definer
set search_path = public, auth
as $$
begin
  if not public.is_room_member(p_room_id) then
    raise exception 'You are not a member of this room.';
  end if;

  insert into public.message_reads (message_id, user_id)
  select m.id, auth.uid()
  from public.messages m
  where m.room_id = p_room_id
    and m.sender_id <> auth.uid()
    and m.deleted_at is null
  on conflict (message_id, user_id) do nothing;

  update public.room_members
  set last_read_at = now()
  where room_id = p_room_id and user_id = auth.uid();
end;
$$;

create or replace function public.message_seen_count(p_message_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public, auth
as $$
declare
  v_room uuid;
begin
  select room_id into v_room
  from public.messages
  where id = p_message_id and sender_id = auth.uid();

  if not found then
    raise exception 'Only the sender can see who has seen this message.';
  end if;

  return jsonb_build_object(
    'seen', (select count(*)::int from public.message_reads where message_id = p_message_id),
    'members', (select count(*)::int from public.room_members where room_id = v_room)
  );
end;
$$;

create or replace function public.room_messages(
  p_room_id uuid,
  p_before timestamptz default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  room_id uuid,
  body text,
  created_at timestamptz,
  is_mine boolean,
  is_deleted boolean,
  reveal_sender boolean,
  sender_handle citext,
  seen_count integer
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    m.id,
    m.room_id,
    case when m.deleted_at is null then m.body else null end as body,
    m.created_at,
    (m.sender_id = auth.uid()) as is_mine,
    (m.deleted_at is not null) as is_deleted,
    m.reveal_sender,
    case when m.reveal_sender and m.deleted_at is null then p.handle else null end as sender_handle,
    case when m.sender_id = auth.uid() then (
      select count(*)::int from public.message_reads mr where mr.message_id = m.id
    ) else null end as seen_count
  from public.messages m
  left join public.profiles p on p.id = m.sender_id
  where m.room_id = p_room_id
    and public.is_room_member(p_room_id)
    and (p_before is null or m.created_at < p_before)
  order by m.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

-- ───────────────────────── ADMIN FUNCTIONS ────────────────────────
-- Admin is a Supabase Auth user whose app_metadata.is_admin = true.
-- Ghost mode: admins see every room and every message body, but a message
-- sender is still only exposed when the sender chose to reveal themselves.

create or replace function public.am_i_admin()
returns boolean
language sql stable
as $$
  select public.is_admin();
$$;

create or replace function public.admin_stats()
returns jsonb
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;
  return jsonb_build_object(
    'users', (select count(*)::int from public.profiles),
    'rooms', (select count(*)::int from public.rooms),
    'messages', (select count(*)::int from public.messages where deleted_at is null),
    'private_rooms', (select count(*)::int from public.rooms where visibility = 'private'),
    'public_rooms', (select count(*)::int from public.rooms where visibility = 'public')
  );
end;
$$;

create or replace function public.admin_list_users(p_query text default '')
returns table (
  id uuid,
  handle citext,
  created_at timestamptz,
  room_count integer,
  message_count integer
)
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  return query
  select
    p.id,
    p.handle,
    p.created_at,
    (select count(*)::int from public.room_members rm where rm.user_id = p.id),
    (select count(*)::int from public.messages m where m.sender_id = p.id)
  from public.profiles p
  where btrim(coalesce(p_query, '')) = ''
     or p.handle ilike '%' || btrim(p_query) || '%'
  order by p.created_at desc
  limit 500;
end;
$$;

create or replace function public.admin_list_rooms(p_query text default '')
returns table (
  id uuid,
  name text,
  code text,
  visibility public.room_visibility,
  creator_handle citext,
  member_count integer,
  message_count integer,
  created_at timestamptz
)
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  return query
  select
    r.id,
    r.name,
    r.code,
    r.visibility,
    p.handle,
    (select count(*)::int from public.room_members rm where rm.room_id = r.id),
    (select count(*)::int from public.messages m where m.room_id = r.id and m.deleted_at is null),
    r.created_at
  from public.rooms r
  join public.profiles p on p.id = r.creator_id
  where btrim(coalesce(p_query, '')) = ''
     or lower(r.name) like '%' || lower(btrim(p_query)) || '%'
     or r.code = upper(btrim(p_query))
  order by r.updated_at desc
  limit 500;
end;
$$;

create or replace function public.admin_room_details(p_room_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  select jsonb_build_object(
    'room', jsonb_build_object(
      'id', r.id,
      'name', r.name,
      'code', r.code,
      'visibility', r.visibility,
      'creator_handle', creator.handle,
      'created_at', r.created_at,
      'member_count', (select count(*)::int from public.room_members rm where rm.room_id = r.id)
    ),
    'members', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'handle', p2.handle, 'role', rm.role, 'joined_at', rm.joined_at
      ) order by case when rm.role = 'creator' then 0 else 1 end, p2.handle), '[]'::jsonb)
      from public.room_members rm
      join public.profiles p2 on p2.id = rm.user_id
      where rm.room_id = r.id
    ),
    'requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'kind', rr.kind, 'status', rr.status, 'handle', p3.handle,
        'created_at', rr.created_at
      ) order by rr.created_at desc), '[]'::jsonb)
      from public.room_requests rr
      join public.profiles p3 on p3.id = rr.user_id
      where rr.room_id = r.id
    ),
    'messages', (
      select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb)
      from (
        select
          m.id,
          case when m.deleted_at is null then m.body else null end as body,
          m.created_at,
          m.deleted_at,
          m.reveal_sender,
          case when m.reveal_sender and m.deleted_at is null then p4.handle else null end as sender_handle,
          (select count(*)::int from public.message_reads mr where mr.message_id = m.id) as read_count
        from public.messages m
        left join public.profiles p4 on p4.id = m.sender_id
        where m.room_id = r.id
        order by m.created_at desc
        limit 500
      ) x
    )
  ) into v_result
  from public.rooms r
  join public.profiles creator on creator.id = r.creator_id
  where r.id = p_room_id;

  return v_result;
end;
$$;

-- ───────────────────── FUNCTION PERMISSIONS ──────────────────────

revoke all on function public.is_room_member(uuid, uuid) from public, anon;
revoke all on function public.is_room_creator(uuid, uuid) from public, anon;
revoke all on function public.is_admin() from public, anon;
revoke all on function public.generate_room_code() from public, anon, authenticated;
revoke all on function public.create_profile(text, text) from public, anon;
revoke all on function public.change_handle(text) from public, anon;
revoke all on function public.handle_available(text) from public, anon;
revoke all on function public.create_room(text, public.room_visibility, public.room_join_mode, boolean, uuid[]) from public, anon;
revoke all on function public.search_rooms(text) from public, anon;
revoke all on function public.room_details(uuid) from public, anon;
revoke all on function public.room_access_preview(text) from public, anon;
revoke all on function public.join_room_by_code(text) from public, anon;
revoke all on function public.room_members_list(uuid) from public, anon;
revoke all on function public.my_rooms() from public, anon;
revoke all on function public.request_join(uuid) from public, anon;
revoke all on function public.respond_room_request(uuid, boolean) from public, anon;
revoke all on function public.invite_member(uuid, text) from public, anon;
revoke all on function public.remove_member(uuid, uuid) from public, anon;
revoke all on function public.update_room(uuid, text, public.room_visibility, public.room_join_mode, boolean) from public, anon;
revoke all on function public.my_requests() from public, anon;
revoke all on function public.room_pending_requests(uuid) from public, anon;
revoke all on function public.send_message(uuid, text, boolean) from public, anon;
revoke all on function public.delete_message(uuid) from public, anon;
revoke all on function public.mark_room_read(uuid) from public, anon;
revoke all on function public.message_seen_count(uuid) from public, anon;
revoke all on function public.room_messages(uuid, timestamptz, integer) from public, anon;
revoke all on function public.am_i_admin() from public, anon;
revoke all on function public.admin_stats() from public, anon;
revoke all on function public.admin_list_users(text) from public, anon;
revoke all on function public.admin_list_rooms(text) from public, anon;
revoke all on function public.admin_room_details(uuid) from public, anon;

grant execute on function public.is_room_member(uuid, uuid) to authenticated;
grant execute on function public.is_room_creator(uuid, uuid) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.create_profile(text, text) to authenticated;
grant execute on function public.change_handle(text) to authenticated;
grant execute on function public.handle_available(text) to authenticated;
grant execute on function public.create_room(text, public.room_visibility, public.room_join_mode, boolean, uuid[]) to authenticated;
grant execute on function public.search_rooms(text) to authenticated;
grant execute on function public.room_details(uuid) to authenticated;
grant execute on function public.room_access_preview(text) to authenticated;
grant execute on function public.join_room_by_code(text) to authenticated;
grant execute on function public.room_members_list(uuid) to authenticated;
grant execute on function public.my_rooms() to authenticated;
grant execute on function public.request_join(uuid) to authenticated;
grant execute on function public.respond_room_request(uuid, boolean) to authenticated;
grant execute on function public.invite_member(uuid, text) to authenticated;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
grant execute on function public.update_room(uuid, text, public.room_visibility, public.room_join_mode, boolean) to authenticated;
grant execute on function public.my_requests() to authenticated;
grant execute on function public.room_pending_requests(uuid) to authenticated;
grant execute on function public.send_message(uuid, text, boolean) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;
grant execute on function public.mark_room_read(uuid) to authenticated;
grant execute on function public.message_seen_count(uuid) to authenticated;
grant execute on function public.room_messages(uuid, timestamptz, integer) to authenticated;
grant execute on function public.am_i_admin() to authenticated;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.admin_list_users(text) to authenticated;
grant execute on function public.admin_list_rooms(text) to authenticated;
grant execute on function public.admin_room_details(uuid) to authenticated;

-- Realtime: requests refresh live in the Requests sheet and room info panel.
do $$ begin
  alter publication supabase_realtime add table public.room_requests;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

notify pgrst, 'reload schema';

