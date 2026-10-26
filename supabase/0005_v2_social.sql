-- ChatMate v2 — identities, direct chats, replies, reactions, room identity modes
-- and push-notification plumbing.
--
-- RUN THIS AFTER 0004_media.sql. Safe to run more than once.
--
-- Everything here is additive: every v1 function keeps its behaviour, and new
-- columns/parameters only extend it. Nothing is removed.

begin;

-- ═══════════════════════════ 1. ROOM SHAPE ═══════════════════════════

-- 'group'  = a normal room (the v1 behaviour).
-- 'direct' = the private 1:1 chat created when somebody accepts a chat request.
alter table public.rooms
  add column if not exists kind text not null default 'group';

alter table public.rooms drop constraint if exists rooms_kind_check;
alter table public.rooms
  add constraint rooms_kind_check check (kind in ('group', 'direct'));

-- `direct:<uuidA>:<uuidB>` with the two ids sorted, so a pair can only ever
-- have one direct room no matter who asks first.
alter table public.rooms add column if not exists direct_key text;
create unique index if not exists rooms_direct_key_uniq
  on public.rooms (direct_key) where direct_key is not null;

-- Who can see the sender of a message in this room?
--   'mixed'     = per-message toggle (the v1 behaviour, default for old rooms)
--   'anonymous' = nobody, ever
--   'reveal'    = everybody, on every message, retroactively
alter table public.rooms
  add column if not exists identity_mode text not null default 'mixed';

alter table public.rooms drop constraint if exists rooms_identity_mode_check;
alter table public.rooms
  add constraint rooms_identity_mode_check
  check (identity_mode in ('mixed', 'anonymous', 'reveal'));

-- ═══════════════════════════ 2. CHAT REQUESTS ═══════════════════════════

create table if not exists public.chat_requests (
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null references public.profiles (id) on delete cascade,
  to_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  note text,
  room_id uuid references public.rooms (id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint chat_requests_not_self check (from_id <> to_id),
  constraint chat_requests_note_length
    check (note is null or char_length(note) <= 200)
);

create unique index if not exists chat_requests_pending_pair_uniq
  on public.chat_requests (from_id, to_id) where status = 'pending';
create index if not exists chat_requests_inbox_idx
  on public.chat_requests (to_id, status, created_at desc);
create index if not exists chat_requests_outbox_idx
  on public.chat_requests (from_id, status, created_at desc);

alter table public.chat_requests enable row level security;

drop policy if exists "chat requests are mine" on public.chat_requests;
create policy "chat requests are mine" on public.chat_requests
  for select to authenticated
  using (from_id = auth.uid() or to_id = auth.uid());

revoke all on public.chat_requests from anon, authenticated;
grant select on public.chat_requests to authenticated;


-- ═══════════════════════════ 3. REPLIES + REACTIONS ═══════════════════════════

alter table public.messages
  add column if not exists reply_to_id uuid
  references public.messages (id) on delete set null;

create index if not exists messages_reply_idx
  on public.messages (reply_to_id) where reply_to_id is not null;

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id),
  constraint message_reactions_emoji_check check (emoji in (
    '👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'
  ))
);

create index if not exists message_reactions_message_idx
  on public.message_reactions (message_id);

alter table public.message_reactions enable row level security;

drop policy if exists "reactions follow the room" on public.message_reactions;
create policy "reactions follow the room" on public.message_reactions
  for select to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_id and public.is_room_member(m.room_id)
    )
  );

revoke all on public.message_reactions from anon, authenticated;
grant select on public.message_reactions to authenticated;

-- ═══════════════════════════ 4. DEVICE TOKENS ═══════════════════════════

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null default 'android'
    check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "device tokens are mine" on public.device_tokens;
create policy "device tokens are mine" on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.device_tokens from anon, authenticated;
grant select, insert, update, delete on public.device_tokens to authenticated;

-- ═══════════════════════════ 5. PUSH QUEUE ═══════════════════════════

create table if not exists public.push_queue (
  id bigserial primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

-- ═══════════════════════════ 6. HELPERS ═══════════════════════════

create or replace function public.direct_key_for(a uuid, b uuid)
returns text
language sql immutable
as $$ select least(a, b)::text || ':' || greatest(a, b)::text $$;

revoke all on function public.direct_key_for(uuid, uuid) from public, anon;
grant execute on function public.direct_key_for(uuid, uuid) to authenticated;

-- 'mixed' | 'anonymous' | 'reveal' for a room the caller belongs to.
create or replace function public.room_identity_mode(p_room_id uuid)
returns text
language sql stable security definer
set search_path = public, auth
as $$
  select coalesce((
    select r.identity_mode from public.rooms r
    where r.id = p_room_id and public.is_room_member(p_room_id)
  ), 'mixed');
$$;

revoke all on function public.room_identity_mode(uuid) from public, anon;
grant execute on function public.room_identity_mode(uuid) to authenticated;

-- Resolve the message preview used by conversation lists and notifications.
create or replace function public.message_preview(
  p_kind text,
  p_deleted boolean,
  p_body text,
  p_caption text
) returns text
language sql immutable
as $$
  select case
    when p_deleted then 'Message deleted'
    when p_kind = 'image' then 'Photo'
    when p_kind = 'gif' then 'GIF'
    when p_kind = 'video' then 'Video'
    when p_kind = 'sticker' then 'Sticker'
    when p_caption is not null and btrim(p_caption) <> '' then left(btrim(p_caption), 90)
    else left(btrim(coalesce(p_body, '')), 90)
  end;
$$;

revoke all on function public.message_preview(text, boolean, text, text) from public, anon;
grant execute on function public.message_preview(text, boolean, text, text) to authenticated;

-- ═══════════════════════════ 7. ROOM IDENTITY MODE ═══════════════════════════

create or replace function public.set_room_identity(
  p_room_id uuid,
  p_mode text
) returns void
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_mode text := lower(btrim(coalesce(p_mode, '')));
begin
  if auth.uid() is null then
    raise exception 'You are not signed in.';
  end if;
  if v_mode not in ('mixed', 'anonymous', 'reveal') then
    raise exception 'Unknown identity mode.';
  end if;
  if not public.is_room_creator(p_room_id) then
    raise exception 'Only the room creator can change who is visible.';
  end if;
  if (select kind from public.rooms where id = p_room_id) = 'direct' then
    raise exception 'Direct chats always use the per-message reveal toggle.';
  end if;

  update public.rooms
  set identity_mode = v_mode, updated_at = now()
  where id = p_room_id;
end;
$$;

revoke all on function public.set_room_identity(uuid, text) from public, anon;
grant execute on function public.set_room_identity(uuid, text) to authenticated;


-- ═══════════════════════════ 8. CHAT REQUESTS ═══════════════════════════

create or replace function public.start_direct_chat(
  p_handle text,
  p_note text default null
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_target uuid;
  v_target_handle citext;
  v_key text;
  v_room uuid;
  v_req uuid;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;

  select id, handle into v_target, v_target_handle
  from public.profiles
  where handle = lower(btrim(coalesce(p_handle, '')));

  if v_target is null then
    raise exception 'No one uses that ChatMate ID.';
  end if;
  if v_target = v_uid then
    raise exception 'That is your own ID.';
  end if;

  v_key := public.direct_key_for(v_uid, v_target);

  select id into v_room from public.rooms where direct_key = v_key;
  if v_room is not null then
    return jsonb_build_object(
      'status', 'existing',
      'room_id', v_room,
      'handle', v_target_handle
    );
  end if;

  -- They already asked us: accepting opens the chat straight away.
  select id into v_req
  from public.chat_requests
  where from_id = v_target and to_id = v_uid and status = 'pending'
  order by created_at desc
  limit 1;

  if v_req is not null then
    perform public.respond_chat_request(v_req, true);
    select id into v_room from public.rooms where direct_key = v_key;
    return jsonb_build_object(
      'status', 'accepted',
      'room_id', v_room,
      'handle', v_target_handle
    );
  end if;

  -- We already asked them: stay pending, never spam a second request.
  select id into v_req
  from public.chat_requests
  where from_id = v_uid and to_id = v_target and status = 'pending'
  order by created_at desc
  limit 1;

  if v_req is not null then
    return jsonb_build_object(
      'status', 'requested',
      'request_id', v_req,
      'handle', v_target_handle
    );
  end if;

  insert into public.chat_requests (from_id, to_id, note)
  values (v_uid, v_target, v_note)
  returning id into v_req;

  return jsonb_build_object(
    'status', 'requested',
    'request_id', v_req,
    'handle', v_target_handle
  );
end;
$$;

revoke all on function public.start_direct_chat(text, text) from public, anon;
grant execute on function public.start_direct_chat(text, text) to authenticated;

create index if not exists push_queue_pending_idx
  on public.push_queue (id) where sent_at is null;

alter table public.push_queue enable row level security;
-- No policies: only the service role (the edge function) may read this table.

revoke all on public.push_queue from anon, authenticated;



-- ═══════════════════════════ 9. ACCEPT / DECLINE ═══════════════════════════

create or replace function public.respond_chat_request(
  p_request_id uuid,
  p_accept boolean
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.chat_requests%rowtype;
  v_room uuid;
  v_key text;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;

  select * into v_req
  from public.chat_requests
  where id = p_request_id
  for update;

  if v_req.id is null then
    raise exception 'That request no longer exists.';
  end if;
  if v_req.to_id <> v_uid then
    raise exception 'This request is not addressed to you.';
  end if;
  if v_req.status <> 'pending' then
    return jsonb_build_object('status', v_req.status, 'room_id', v_req.room_id);
  end if;

  if not p_accept then
    update public.chat_requests
    set status = 'declined', responded_at = now()
    where id = v_req.id;
    return jsonb_build_object('status', 'declined');
  end if;

  v_key := public.direct_key_for(v_req.from_id, v_req.to_id);

  select id into v_room from public.rooms where direct_key = v_key;
  if v_room is null then
    insert into public.rooms (
      name, code, visibility, join_mode, open_to_all, creator_id,
      kind, direct_key, identity_mode
    )
    values (
      'Direct chat', public.generate_room_code(), 'private', 'request', false,
      v_req.from_id, 'direct', v_key, 'mixed'
    )
    returning id into v_room;

    insert into public.room_members (room_id, user_id, role)
    values (v_room, v_req.from_id, 'member'), (v_room, v_req.to_id, 'member')
    on conflict do nothing;
  end if;

  update public.chat_requests
  set status = 'accepted', responded_at = now(), room_id = v_room
  where id = v_req.id;

  update public.chat_requests
  set status = 'cancelled', responded_at = now()
  where status = 'pending'
    and id <> v_req.id
    and ((from_id = v_req.from_id and to_id = v_req.to_id)
      or (from_id = v_req.to_id and to_id = v_req.from_id));

  return jsonb_build_object('status', 'accepted', 'room_id', v_room);
end;
$$;

revoke all on function public.respond_chat_request(uuid, boolean) from public, anon;
grant execute on function public.respond_chat_request(uuid, boolean) to authenticated;

create or replace function public.cancel_chat_request(p_request_id uuid)
returns void
language plpgsql security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'You are not signed in.';
  end if;
  update public.chat_requests
  set status = 'cancelled', responded_at = now()
  where id = p_request_id
    and from_id = auth.uid()
    and status = 'pending';
end;
$$;

revoke all on function public.cancel_chat_request(uuid) from public, anon;
grant execute on function public.cancel_chat_request(uuid) to authenticated;

-- ═══════════════════════════ 10. INBOX ═══════════════════════════

create or replace function public.my_chat_requests()
returns table (
  request_id uuid,
  direction text,
  handle citext,
  note text,
  status text,
  created_at timestamptz,
  room_id uuid
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    cr.id,
    case when cr.to_id = auth.uid() then 'incoming' else 'outgoing' end,
    opp.handle,
    cr.note,
    cr.status,
    cr.created_at,
    cr.room_id
  from public.chat_requests cr
  join public.profiles opp
    on opp.id = case when cr.to_id = auth.uid() then cr.from_id else cr.to_id end
  where (cr.to_id = auth.uid() or cr.from_id = auth.uid())
    and cr.status = 'pending'
  order by cr.created_at desc;
$$;

revoke all on function public.my_chat_requests() from public, anon;
grant execute on function public.my_chat_requests() to authenticated;

-- ═══════════════════════════ 11. CONVERSATION LIST ═══════════════════════════

create or replace function public.my_conversations()
returns table (
  id uuid,
  kind text,
  title text,
  other_handle citext,
  code text,
  visibility public.room_visibility,
  join_mode public.room_join_mode,
  open_to_all boolean,
  role text,
  member_count integer,
  unread_count integer,
  last_message_at timestamptz,
  last_preview text,
  last_kind text,
  identity_mode text
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    r.id,
    r.kind,
    case
      when r.kind = 'direct' then coalesce(opp.handle::text, 'Direct chat')
      else r.name
    end as title,
    opp.handle as other_handle,
    r.code,
    r.visibility,
    r.join_mode,
    r.open_to_all,
    rm.role,
    (select count(*)::int from public.room_members x where x.room_id = r.id),
    (select count(*)::int from public.messages m
      where m.room_id = r.id
        and m.created_at > rm.last_read_at
        and m.sender_id <> auth.uid()
        and m.deleted_at is null),
    lm.created_at,
    case
      when lm.id is null then null
      else public.message_preview(
        lm.kind, lm.deleted_at is not null, lm.body, lm.caption
      )
    end as last_preview,
    lm.kind as last_kind,
    r.identity_mode
  from public.room_members rm
  join public.rooms r on r.id = rm.room_id
  left join lateral (
    select p.handle
    from public.room_members om
    join public.profiles p on p.id = om.user_id
    where om.room_id = r.id and om.user_id <> auth.uid()
    limit 1
  ) opp on r.kind = 'direct'
  left join lateral (
    select m.id, m.created_at, m.kind, m.deleted_at, m.body, m.caption
    from public.messages m
    where m.room_id = r.id
    order by m.created_at desc
    limit 1
  ) lm on true
  where rm.user_id = auth.uid()
  order by coalesce(lm.created_at, r.created_at) desc;
$$;

revoke all on function public.my_conversations() from public, anon;
grant execute on function public.my_conversations() to authenticated;




-- ═══════════════════════════ 12. SEARCH ═══════════════════════════

-- Home search: only the rooms I am in and the people I already chat with.
create or replace function public.home_search(p_query text default '')
returns table (
  entry text,
  id uuid,
  title text,
  subtitle text,
  handle citext,
  code text,
  member_count integer,
  last_message_at timestamptz
)
language sql stable security definer
set search_path = public, auth
as $$
  select x.entry, x.id, x.title, x.subtitle, x.handle, x.code,
         x.member_count, x.last_message_at
  from (
    select
      'room'::text as entry,
      r.id,
      r.name as title,
      r.code as subtitle,
      null::citext as handle,
      r.code,
      (select count(*)::int from public.room_members x where x.room_id = r.id)
        as member_count,
      (select max(m.created_at) from public.messages m where m.room_id = r.id)
        as last_message_at
    from public.rooms r
    join public.room_members rm
      on rm.room_id = r.id and rm.user_id = auth.uid()
    where r.kind = 'group'
      and (
        btrim(coalesce(p_query, '')) = ''
        or r.name ilike '%' || btrim(p_query) || '%'
        or lower(r.code) = lower(btrim(p_query))
      )

    union all

    select
      'chat'::text,
      r.id,
      opp.handle::text,
      'Private chat'::text,
      opp.handle,
      r.code,
      2,
      (select max(m.created_at) from public.messages m where m.room_id = r.id)
    from public.rooms r
    join public.room_members rm
      on rm.room_id = r.id and rm.user_id = auth.uid()
    join lateral (
      select p.handle
      from public.room_members om
      join public.profiles p on p.id = om.user_id
      where om.room_id = r.id and om.user_id <> auth.uid()
      limit 1
    ) opp on true
    where r.kind = 'direct'
      and (
        btrim(coalesce(p_query, '')) = ''
        or opp.handle::text ilike '%' || btrim(p_query) || '%'
      )
  ) x
  order by x.last_message_at desc nulls last, x.title
  limit 60;
$$;

revoke all on function public.home_search(text) from public, anon;
grant execute on function public.home_search(text) to authenticated;

-- ID search: keyword only. An empty/blank query returns nothing, so the
-- directory can never be listed in bulk.
create or replace function public.search_profiles(
  p_query text default '',
  p_limit integer default 30
)
returns table (
  id uuid,
  handle citext,
  display_name text,
  relation text,
  room_id uuid
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    p.id,
    p.handle,
    p.display_name,
    case
      when exists (
        select 1 from public.rooms r
        where r.direct_key = public.direct_key_for(auth.uid(), p.id)
      ) then 'chat'
      when exists (
        select 1 from public.chat_requests cr
        where cr.from_id = auth.uid() and cr.to_id = p.id and cr.status = 'pending'
      ) then 'pending_out'
      when exists (
        select 1 from public.chat_requests cr
        where cr.from_id = p.id and cr.to_id = auth.uid() and cr.status = 'pending'
      ) then 'pending_in'
      else 'none'
    end as relation,
    (
      select r.id from public.rooms r
      where r.direct_key = public.direct_key_for(auth.uid(), p.id)
      limit 1
    ) as room_id
  from public.profiles p
  where p.id <> auth.uid()
    -- No keyword, no results: the directory is never browsable in bulk.
    and btrim(coalesce(p_query, '')) <> ''
    and (
      p.handle::text ilike '%' || btrim(p_query) || '%'
      or coalesce(p.display_name, '') ilike '%' || btrim(p_query) || '%'
    )
  order by
    case when p.handle::text ilike btrim(coalesce(p_query, '')) || '%' then 0 else 1 end,
    p.handle
  limit least(greatest(coalesce(p_limit, 30), 1), 60);
$$;

revoke all on function public.search_profiles(text, integer) from public, anon;
grant execute on function public.search_profiles(text, integer) to authenticated;




-- ═══════════════════════════ 13. EXTENDED v1 FUNCTIONS ═══════════════════════════

-- room_details keeps every old key and adds kind / identity_mode / other_handle.
create or replace function public.room_details(p_room_id uuid)
returns jsonb
language sql stable security definer
set search_path = public, auth
as $$
  select jsonb_build_object(
    'id', r.id,
    'name', case
      when r.kind = 'direct' then coalesce(opp.handle::text, 'Direct chat')
      else r.name
    end,
    'code', r.code,
    'visibility', r.visibility,
    'join_mode', r.join_mode,
    'open_to_all', r.open_to_all,
    'creator_id', r.creator_id,
    'creator_handle', p.handle,
    'member_count', (select count(*)::int from public.room_members rm where rm.room_id = r.id),
    'my_role', (select rm.role from public.room_members rm
                 where rm.room_id = r.id and rm.user_id = auth.uid()),
    'created_at', r.created_at,
    'kind', r.kind,
    'identity_mode', r.identity_mode,
    'other_handle', opp.handle
  )
  from public.rooms r
  join public.profiles p on p.id = r.creator_id
  left join lateral (
    select pr.handle
    from public.room_members om
    join public.profiles pr on pr.id = om.user_id
    where om.room_id = r.id and om.user_id <> auth.uid()
    limit 1
  ) opp on r.kind = 'direct'
  where r.id = p_room_id and public.is_room_member(p_room_id);
$$;

revoke all on function public.room_details(uuid) from public, anon;
grant execute on function public.room_details(uuid) to authenticated;

-- my_rooms keeps every old column and adds the v2 ones at the end.
drop function if exists public.my_rooms();

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
  last_message_at timestamptz,
  kind text,
  identity_mode text,
  other_handle citext
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    c.id,
    c.title::text as name,
    c.code,
    c.visibility,
    c.join_mode,
    c.open_to_all,
    p.handle as creator_handle,
    c.role,
    c.member_count,
    c.unread_count,
    c.last_message_at,
    c.kind,
    c.identity_mode,
    c.other_handle
  from public.my_conversations() c
  join public.rooms r on r.id = c.id
  join public.profiles p on p.id = r.creator_id
  where c.kind = 'group'
  order by c.last_message_at desc nulls last;
$$;

revoke all on function public.my_rooms() from public, anon;
grant execute on function public.my_rooms() to authenticated;




-- ═══════════════════════════ 14. MESSAGES: REPLY ═══════════════════════════

drop function if exists public.send_message(uuid, text, boolean, text, text, text, integer, integer, text, text, integer);

create or replace function public.send_message(
  p_room_id uuid,
  p_body text default null,
  p_reveal_sender boolean default false,
  p_kind text default 'text',
  p_media_path text default null,
  p_mime text default null,
  p_width integer default null,
  p_height integer default null,
  p_caption text default null,
  p_sticker_id text default null,
  p_duration_ms integer default null,
  p_reply_to uuid default null
) returns uuid
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_kind text := lower(btrim(coalesce(p_kind, 'text')));
  v_body text := btrim(coalesce(p_body, ''));
  v_caption text := nullif(btrim(coalesce(p_caption, '')), '');
  v_sticker text := nullif(btrim(coalesce(p_sticker_id, '')), '');
  v_media_path text := nullif(btrim(coalesce(p_media_path, '')), '');
  v_mime text := nullif(lower(btrim(coalesce(p_mime, ''))), '');
  v_reply uuid := p_reply_to;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;
  if not public.is_room_member(p_room_id) then
    raise exception 'You are not a member of this room.';
  end if;
  if v_kind not in ('text', 'image', 'gif', 'video', 'sticker') then
    raise exception 'Unsupported message type.';
  end if;
  if v_caption is not null and char_length(v_caption) > 1024 then
    raise exception 'Caption must be 1024 characters or fewer.';
  end if;

  if v_reply is not null then
    if not exists (
      select 1 from public.messages m
      where m.id = v_reply and m.room_id = p_room_id
    ) then
      raise exception 'You can only reply to a message in this room.';
    end if;
  end if;

  if v_kind = 'text' then
    if char_length(v_body) < 1 or char_length(v_body) > 4000 then
      raise exception 'Message must be 1-4000 characters.';
    end if;
    if v_media_path is not null or v_sticker is not null then
      raise exception 'Text messages cannot include media.';
    end if;
    v_mime := null;
    v_caption := null;
    v_sticker := null;
  elsif v_kind = 'sticker' then
    if v_sticker is null or v_sticker !~ '^[a-z0-9_]{2,64}$' then
      raise exception 'Invalid sticker.';
    end if;
    if v_media_path is not null then
      raise exception 'Stickers are bundled and cannot include an upload.';
    end if;
    v_body := '';
    v_mime := null;
    v_caption := null;
  else
    if not public.is_chat_media_path(v_media_path, p_room_id) then
      raise exception 'Invalid media path.';
    end if;
    if v_mime is null then
      raise exception 'Media type is required.';
    end if;
    if v_kind = 'image' and v_mime not in ('image/jpeg', 'image/png', 'image/webp') then
      raise exception 'Images must be JPEG, PNG or WebP.';
    elsif v_kind = 'gif' and v_mime <> 'image/gif' then
      raise exception 'GIF messages must use image/gif.';
    elsif v_kind = 'video' and v_mime not in ('video/mp4', 'video/quicktime', 'video/webm') then
      raise exception 'Videos must be MP4, MOV or WebM.';
    end if;

    if v_kind in ('image', 'gif') then
      if p_width is null or p_height is null
         or p_width <= 0 or p_height <= 0
         or p_width > 16000 or p_height > 16000 then
        raise exception 'Image dimensions are required.';
      end if;
      if p_duration_ms is not null then
        raise exception 'Images cannot have a duration.';
      end if;
    else
      if p_duration_ms is null
         or p_duration_ms < 1000
         or p_duration_ms > 30000 then
        raise exception 'Videos must be between 1 and 30 seconds.';
      end if;
    end if;

    v_body := '';
    v_sticker := null;
  end if;

  insert into public.messages (
    room_id, sender_id, body, reveal_sender, kind, media_path, mime,
    width, height, caption, sticker_id, duration_ms, reply_to_id
  )
  values (
    p_room_id, v_uid, v_body, coalesce(p_reveal_sender, false), v_kind,
    v_media_path, v_mime,
    case when v_kind in ('image', 'gif', 'video') then p_width else null end,
    case when v_kind in ('image', 'gif', 'video') then p_height else null end,
    v_caption, v_sticker,
    case when v_kind = 'video' then p_duration_ms else null end,
    v_reply
  )
  returning id into v_id;

  update public.rooms set updated_at = now() where id = p_room_id;
  return v_id;
end;
$$;

revoke all on function public.send_message(uuid, text, boolean, text, text, text, integer, integer, text, text, integer, uuid) from public, anon;
grant execute on function public.send_message(uuid, text, boolean, text, text, text, integer, integer, text, text, integer, uuid) to authenticated;




-- ═══════════════════════════ 15. MESSAGES: READ ═══════════════════════════

drop function if exists public.room_messages(uuid, timestamptz, integer);

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
  seen_count integer,
  kind text,
  media_path text,
  mime text,
  width integer,
  height integer,
  caption text,
  sticker_id text,
  duration_ms integer,
  reply_to_id uuid,
  reply_preview text,
  reply_handle citext,
  reactions jsonb
)
language sql stable security definer
set search_path = public, auth
as $$
  select
    m.id,
    m.room_id,
    case when m.deleted_at is null and m.kind = 'text' then m.body else null end as body,
    m.created_at,
    (m.sender_id = auth.uid()) as is_mine,
    (m.deleted_at is not null) as is_deleted,
    m.reveal_sender,
    case
      when m.deleted_at is not null then null
      when r.identity_mode = 'reveal' then p.handle
      when r.identity_mode = 'anonymous' then null
      when m.reveal_sender then p.handle
      else null
    end as sender_handle,
    case when m.sender_id = auth.uid() then (
      select count(*)::int from public.message_reads mr where mr.message_id = m.id
    ) else null end as seen_count,
    case when m.deleted_at is null then m.kind else 'text' end as kind,
    case when m.deleted_at is null then m.media_path else null end as media_path,
    case when m.deleted_at is null then m.mime else null end as mime,
    case when m.deleted_at is null then m.width else null end as width,
    case when m.deleted_at is null then m.height else null end as height,
    case when m.deleted_at is null then m.caption else null end as caption,
    case when m.deleted_at is null then m.sticker_id else null end as sticker_id,
    case when m.deleted_at is null then m.duration_ms else null end as duration_ms,
    m.reply_to_id,
    case
      when rm.id is null then null
      else public.message_preview(
        rm.kind, rm.deleted_at is not null, rm.body, rm.caption
      )
    end as reply_preview,
    case
      when rm.id is null or rm.deleted_at is not null then null
      when r.identity_mode = 'reveal' then rp.handle
      when r.identity_mode = 'anonymous' then null
      when rm.reveal_sender then rp.handle
      else null
    end as reply_handle,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'emoji', y.emoji, 'count', y.cnt, 'mine', y.mine
      ) order by y.first_at)
      from (
        select
          re.emoji,
          count(*)::int as cnt,
          bool_or(re.user_id = auth.uid()) as mine,
          min(re.created_at) as first_at
        from public.message_reactions re
        where re.message_id = m.id
        group by re.emoji
      ) y
    ), '[]'::jsonb) as reactions
  from public.messages m
  join public.rooms r on r.id = m.room_id
  left join public.profiles p on p.id = m.sender_id
  left join public.messages rm on rm.id = m.reply_to_id
  left join public.profiles rp on rp.id = rm.sender_id
  where m.room_id = p_room_id
    and public.is_room_member(p_room_id)
    and (p_before is null or m.created_at < p_before)
  order by m.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.room_messages(uuid, timestamptz, integer) from public, anon;
grant execute on function public.room_messages(uuid, timestamptz, integer) to authenticated;

-- ═══════════════════════════ 16. REACTIONS ═══════════════════════════

create or replace function public.react_message(
  p_message_id uuid,
  p_emoji text
) returns jsonb
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_room uuid;
  v_emoji text := btrim(coalesce(p_emoji, ''));
  v_existing text;
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;

  select room_id into v_room from public.messages where id = p_message_id;
  if v_room is null then
    raise exception 'That message no longer exists.';
  end if;
  if not public.is_room_member(v_room) then
    raise exception 'You are not a member of this room.';
  end if;
  if v_emoji not in ('👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏') then
    raise exception 'That reaction is not available.';
  end if;

  select emoji into v_existing
  from public.message_reactions
  where message_id = p_message_id and user_id = v_uid;

  if v_existing = v_emoji then
    delete from public.message_reactions
    where message_id = p_message_id and user_id = v_uid;
    return jsonb_build_object('action', 'removed', 'emoji', v_emoji);
  end if;

  insert into public.message_reactions (message_id, user_id, emoji)
  values (p_message_id, v_uid, v_emoji)
  on conflict (message_id, user_id)
  do update set emoji = excluded.emoji, created_at = now();

  return jsonb_build_object('action', 'set', 'emoji', v_emoji);
end;
$$;

revoke all on function public.react_message(uuid, text) from public, anon;
grant execute on function public.react_message(uuid, text) to authenticated;




-- ═══════════════════════════ 17. DEVICE TOKENS ═══════════════════════════

create or replace function public.register_device_token(
  p_token text,
  p_platform text default 'android'
) returns void
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := btrim(coalesce(p_token, ''));
  v_platform text := lower(btrim(coalesce(p_platform, 'android')));
begin
  if v_uid is null then
    raise exception 'You are not signed in.';
  end if;
  if char_length(v_token) < 20 or char_length(v_token) > 4096 then
    raise exception 'Invalid device token.';
  end if;
  if v_platform not in ('android', 'ios', 'web') then
    v_platform := 'android';
  end if;

  insert into public.device_tokens (token, user_id, platform)
  values (v_token, v_uid, v_platform)
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;

create or replace function public.remove_device_token(p_token text)
returns void
language plpgsql security definer
set search_path = public, auth
as $$
begin
  delete from public.device_tokens
  where token = btrim(coalesce(p_token, '')) and user_id = auth.uid();
end;
$$;

revoke all on function public.remove_device_token(text) from public, anon;
grant execute on function public.remove_device_token(text) to authenticated;




-- ═══════════════════════════ 18. PUSH TRIGGERS ═══════════════════════════

create or replace function public.push_on_message()
returns trigger
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_room public.rooms%rowtype;
  v_sender text;
  v_title text;
  v_body text;
  v_recipient uuid;
begin
  select * into v_room from public.rooms where id = new.room_id;
  if v_room.id is null then
    return new;
  end if;

  select coalesce(handle::text, 'someone') into v_sender
  from public.profiles where id = new.sender_id;

  v_body := public.message_preview(new.kind, false, new.body, new.caption);

  if v_room.kind = 'direct' then
    v_title := '@' || coalesce(v_sender, 'someone');
  elsif v_room.identity_mode = 'reveal'
     or (v_room.identity_mode = 'mixed' and new.reveal_sender) then
    v_title := '@' || coalesce(v_sender, 'someone') || ' in ' || v_room.name;
  else
    v_title := 'New message in ' || v_room.name;
  end if;

  for v_recipient in
    select user_id from public.room_members
    where room_id = new.room_id and user_id <> new.sender_id
  loop
    insert into public.push_queue (user_id, title, body, data)
    values (
      v_recipient,
      v_title,
      v_body,
      jsonb_build_object(
        'type', 'message',
        'room_id', new.room_id,
        'message_id', new.id,
        'room_kind', v_room.kind
      )
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists chatmate_push_on_message on public.messages;
create trigger chatmate_push_on_message
after insert on public.messages
for each row execute function public.push_on_message();




create or replace function public.push_on_chat_request()
returns trigger
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_from text;
  v_to text;
begin
  select coalesce(handle::text, 'someone') into v_from
  from public.profiles where id = new.from_id;
  select coalesce(handle::text, 'someone') into v_to
  from public.profiles where id = new.to_id;

  if tg_op = 'INSERT' and new.status = 'pending' then
    insert into public.push_queue (user_id, title, body, data)
    values (
      new.to_id,
      '@' || v_from || ' sent you a chat request',
      coalesce(nullif(btrim(new.note), ''), 'Tap to accept and start chatting.'),
      jsonb_build_object('type', 'chat_request', 'request_id', new.id, 'from', v_from)
    );
  elsif tg_op = 'UPDATE' and old.status = 'pending' then
    if new.status = 'accepted' then
      insert into public.push_queue (user_id, title, body, data)
      values (
        new.from_id,
        '@' || v_to || ' accepted your chat request',
        'Your private chat is open. Say something.',
        jsonb_build_object('type', 'chat_accepted', 'room_id', new.room_id)
      );
    elsif new.status = 'declined' then
      insert into public.push_queue (user_id, title, body, data)
      values (
        new.from_id,
        '@' || v_to || ' declined your chat request',
        'They are not taking new chats right now.',
        jsonb_build_object('type', 'chat_declined')
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists chatmate_push_on_chat_request on public.chat_requests;
create trigger chatmate_push_on_chat_request
after insert or update on public.chat_requests
for each row execute function public.push_on_chat_request();




create or replace function public.push_on_room_request()
returns trigger
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_by text;
  v_room text;
begin
  select coalesce(handle::text, 'someone') into v_by
  from public.profiles where id = new.created_by;
  select name into v_room from public.rooms where id = new.room_id;

  if tg_op = 'INSERT' and new.status = 'pending' then
    insert into public.push_queue (user_id, title, body, data)
    values (
      new.user_id,
      case when new.kind = 'invite'
        then '@' || v_by || ' invited you to ' || coalesce(v_room, 'a room')
        else '@' || v_by || ' asked to join ' || coalesce(v_room, 'your room')
      end,
      case when new.kind = 'invite'
        then 'Tap to accept the invite.'
        else 'Tap to review the request.'
      end,
      jsonb_build_object(
        'type', 'room_request',
        'kind', new.kind,
        'room_id', new.room_id,
        'request_id', new.id
      )
    );
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status <> 'pending' then
    insert into public.push_queue (user_id, title, body, data)
    values (
      new.created_by,
      case when new.status = 'accepted'
        then coalesce(v_room, 'Your room') || ': request accepted'
        else coalesce(v_room, 'Your room') || ': request declined'
      end,
      case when new.status = 'accepted'
        then 'You are in. Open the room and say the thing.'
        else 'That one did not go through.'
      end,
      jsonb_build_object('type', 'room_request_response', 'room_id', new.room_id)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists chatmate_push_on_room_request on public.room_requests;
create trigger chatmate_push_on_room_request
after insert or update on public.room_requests
for each row execute function public.push_on_room_request();




-- ═══════════════════════════ 19. PUSH DISPATCH ═══════════════════════════
--
-- The triggers above only *enqueue* rows in public.push_queue. Delivery is
-- done by the `push` edge function (see supabase/functions/push/index.ts),
-- which needs the FIREBASE_SERVICE_ACCOUNT secret.
--
-- One-time setup (run once, after deploying the function):
--
--   select vault.create_secret(
--     'https://<PROJECT-REF>.functions.supabase.co/push', 'push_url');
--   select vault.create_secret(
--     '<a long random string you also set as PUSH_SECRET>', 'push_secret');
--
-- The function below is what the cron job calls every 20 seconds.

create or replace function public.trigger_push_flush()
returns void
language plpgsql security definer
set search_path = public, auth, vault, net
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'push_url' limit 1;

  if v_url is null or btrim(v_url) = '' then
    return;
  end if;

  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_secret' limit 1;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', coalesce(v_secret, '')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 8000
  );
end;
$$;

revoke all on function public.trigger_push_flush() from public, anon, authenticated;

-- Optional: schedule the flush. Silently skipped when pg_cron is unavailable
-- (for example on a local Postgres without the extension).
do $$
begin
  execute 'create extension if not exists pg_cron';
  execute 'create extension if not exists pg_net';
exception when others then
  raise notice 'pg_cron / pg_net unavailable, skipping schedule: %', sqlerrm;
end;
$$;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'chatmate-push-flush') then
    perform cron.unschedule('chatmate-push-flush');
  end if;

  perform cron.schedule(
    'chatmate-push-flush',
    '20 seconds',
    'select public.trigger_push_flush();'
  );
exception when others then
  raise notice 'Could not schedule chatmate-push-flush: %', sqlerrm;
end;
$$;

-- Housekeeping: keep the queue small. Anything older than a day is noise.
delete from public.push_queue
where created_at < now() - interval '1 day';

notify pgrst, 'reload schema';


commit;
