-- ChatMate — private photos, GIFs, stickers and 30-second videos
--
-- RUN THIS AFTER 0003_three_join_modes.sql (or after 0001 + 0002 + 0003).
-- Safe to run more than once.
--
-- Media is stored in the private `chat-media` bucket. Object names use the
-- room id and a random name, never the sender, so anonymity survives. The
-- bucket can only be read by current room members (and admins in ghost mode),
-- and the app receives short-lived signed URLs instead of public links.
--
-- Limits are deliberately small to protect storage/egress:
--   images: compressed client-side to JPEG, max 1600 px long edge
--   GIFs:   max 8 MiB
--   videos: max 30 seconds, compressed client-side to 720p, hard cap 25 MiB
-- Stickers are bundled app assets, so they cost no storage at all.

begin;

-- ───────────────────────────── MESSAGE SCHEMA ─────────────────────────────

alter table public.messages add column if not exists kind text not null default 'text';
alter table public.messages add column if not exists media_path text;
alter table public.messages add column if not exists mime text;
alter table public.messages add column if not exists width integer;
alter table public.messages add column if not exists height integer;
alter table public.messages add column if not exists caption text;
alter table public.messages add column if not exists sticker_id text;
alter table public.messages add column if not exists duration_ms integer;

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages
  add constraint messages_kind_check
  check (kind in ('text', 'image', 'gif', 'video', 'sticker'));

alter table public.messages drop constraint if exists messages_media_path_check;
alter table public.messages
  add constraint messages_media_path_check
  check (
    media_path is null
    or (
      char_length(media_path) between 40 and 200
      and media_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9_-]{8,80}\.(jpg|jpeg|png|webp|gif|mp4|mov|webm)$'
    )
  );

alter table public.messages drop constraint if exists messages_mime_check;
alter table public.messages
  add constraint messages_mime_check
  check (
    mime is null
    or mime in (
      'image/jpeg', 'image/png', 'image/webp', 'image/gif',
      'video/mp4', 'video/quicktime', 'video/webm'
    )
  );

alter table public.messages drop constraint if exists messages_caption_check;
alter table public.messages
  add constraint messages_caption_check
  check (caption is null or char_length(caption) <= 1024);

alter table public.messages drop constraint if exists messages_sticker_id_check;
alter table public.messages
  add constraint messages_sticker_id_check
  check (sticker_id is null or sticker_id ~ '^[a-z0-9_]{2,64}$');

alter table public.messages drop constraint if exists messages_dimensions_check;
alter table public.messages
  add constraint messages_dimensions_check
  check (
    (width is null or (width > 0 and width <= 16000))
    and (height is null or (height > 0 and height <= 16000))
  );

alter table public.messages drop constraint if exists messages_duration_check;
alter table public.messages
  add constraint messages_duration_check
  check (duration_ms is null or (duration_ms > 0 and duration_ms <= 30000));

-- ─────────────────────────── PATH HELPERS ───────────────────────────

-- Object paths are `<room uuid>/<random>.<ext>`.
create or replace function public.is_chat_media_path(
  p_path text,
  p_room_id uuid default null
) returns boolean
language sql immutable
set search_path = public
as $$
  select
    p_path is not null
    and p_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9_-]{8,80}\.(jpg|jpeg|png|webp|gif|mp4|mov|webm)$'
    and (p_room_id is null or split_part(p_path, '/', 1) = p_room_id::text);
$$;

create or replace function public.chat_media_room_id(p_path text)
returns uuid
language sql immutable
set search_path = public
as $$
  select case
    when p_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9_-]{8,80}\.(jpg|jpeg|png|webp|gif|mp4|mov|webm)$'
      then split_part(p_path, '/', 1)::uuid
    else null
  end;
$$;

-- ─────────────────────────── STORAGE BUCKET ───────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media',
  'chat-media',
  false,
  26214400,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime', 'video/webm'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "chat media members can read" on storage.objects;
create policy "chat media members can read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-media'
    and (
      public.is_room_member(public.chat_media_room_id(name))
      or public.is_admin()
    )
  );

drop policy if exists "chat media members can upload" on storage.objects;
create policy "chat media members can upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and public.is_room_member(public.chat_media_room_id(name))
  );

drop policy if exists "chat media owner or creator can delete" on storage.objects;
create policy "chat media owner or creator can delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-media'
    and (
      owner_id = auth.uid()::text
      or public.is_room_creator(public.chat_media_room_id(name))
      or public.is_admin()
    )
  );

-- ─────────────────────────── SEND MESSAGE ───────────────────────────

-- The old three-argument function is replaced by a wider signature with
-- defaults. Old clients that only send text continue to work unchanged.
drop function if exists public.send_message(uuid, text, boolean);

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
  p_duration_ms integer default null
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
    width, height, caption, sticker_id, duration_ms
  )
  values (
    p_room_id, v_uid, v_body, coalesce(p_reveal_sender, false), v_kind,
    v_media_path, v_mime,
    case when v_kind in ('image', 'gif', 'video') then p_width else null end,
    case when v_kind in ('image', 'gif', 'video') then p_height else null end,
    v_caption, v_sticker,
    case when v_kind = 'video' then p_duration_ms else null end
  )
  returning id into v_id;

  update public.rooms set updated_at = now() where id = p_room_id;
  return v_id;
end;
$$;

-- ─────────────────────────── DELETE MESSAGE ───────────────────────────

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

  -- Remove the media reference immediately. The client also removes the
  -- storage object using the path it already has; a dangling object is
  -- harmless and cannot be read once the message is gone.
  update public.messages
  set
    body = '',
    kind = 'text',
    media_path = null,
    mime = null,
    width = null,
    height = null,
    caption = null,
    sticker_id = null,
    duration_ms = null,
    deleted_at = now(),
    deleted_by = auth.uid()
  where id = p_message_id;
end;
$$;


-- ─────────────────────────── ROOM MESSAGES ───────────────────────────

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
  duration_ms integer
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
    case when m.reveal_sender and m.deleted_at is null then p.handle else null end as sender_handle,
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
    case when m.deleted_at is null then m.duration_ms else null end as duration_ms
  from public.messages m
  left join public.profiles p on p.id = m.sender_id
  where m.room_id = p_room_id
    and public.is_room_member(p_room_id)
    and (p_before is null or m.created_at < p_before)
  order by m.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;



-- ─────────────────────────── ADMIN DETAILS ───────────────────────────

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
          case when m.deleted_at is null and m.kind = 'text' then m.body else null end as body,
          m.created_at,
          m.deleted_at,
          m.reveal_sender,
          case when m.reveal_sender and m.deleted_at is null then p4.handle else null end as sender_handle,
          (select count(*)::int from public.message_reads mr where mr.message_id = m.id) as read_count,
          case when m.deleted_at is null then m.kind else 'text' end as kind,
          case when m.deleted_at is null then m.media_path else null end as media_path,
          case when m.deleted_at is null then m.mime else null end as mime,
          case when m.deleted_at is null then m.width else null end as width,
          case when m.deleted_at is null then m.height else null end as height,
          case when m.deleted_at is null then m.caption else null end as caption,
          case when m.deleted_at is null then m.sticker_id else null end as sticker_id,
          case when m.deleted_at is null then m.duration_ms else null end as duration_ms
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

-- ─────────────────────────── PERMISSIONS ───────────────────────────

revoke all on function public.is_chat_media_path(text, uuid) from public, anon;
revoke all on function public.chat_media_room_id(text) from public, anon;
revoke all on function public.send_message(uuid, text, boolean, text, text, text, integer, integer, text, text, integer) from public, anon;
revoke all on function public.delete_message(uuid) from public, anon;
revoke all on function public.room_messages(uuid, timestamptz, integer) from public, anon;
revoke all on function public.admin_room_details(uuid) from public, anon;

grant execute on function public.is_chat_media_path(text, uuid) to authenticated;
grant execute on function public.chat_media_room_id(text) to authenticated;
grant execute on function public.send_message(uuid, text, boolean, text, text, text, integer, integer, text, text, integer) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;
grant execute on function public.room_messages(uuid, timestamptz, integer) to authenticated;
grant execute on function public.admin_room_details(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;

