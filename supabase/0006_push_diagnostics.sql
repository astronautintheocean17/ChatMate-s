-- supabase/0006_push_diagnostics.sql
--
-- One read-only function that answers "why is no push arriving?" without
-- opening six dashboards. Run it in the SQL editor after 0005:
--
--   select * from public.push_health();
--
-- Every row is one link in the chain, in the order a notification travels:
--   message row -> push_queue -> cron -> edge function -> FCM/APNs -> device.
-- Fix the first row whose status is not "ok".
--
-- Safe to re-run. It creates nothing but this function.

create or replace function public.push_health()
returns table (item text, status text, detail text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
  v_jobs int := -1;
  v_schedule text;
  v_pending int := 0;
  v_failed int := 0;
  v_sent_hour int := 0;
  v_oldest interval;
  v_tokens int := 0;
  v_token_users int := 0;
  v_fresh_tokens int := 0;
  v_triggers int := 0;
  v_error text;
  v_error_at timestamptz;
  v_error_attempts int;
begin
  -- ── vault secrets (the flush function reads these two) ──────────────────
  begin
    select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_url' limit 1;
    select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_secret' limit 1;
  exception when others then
    v_url := null;
    v_secret := null;
  end;

  item := '1. vault secret push_url';
  status := case when coalesce(btrim(v_url), '') = '' then 'MISSING' else 'ok' end;
  detail := coalesce(
    v_url,
    'run: select vault.create_secret(''https://<PROJECT-REF>.functions.supabase.co/push'', ''push_url'');'
  );
  return next;

  item := '2. vault secret push_secret';
  status := case when coalesce(btrim(v_secret), '') = '' then 'MISSING' else 'ok' end;
  detail := case
    when v_secret is null then 'the edge function returns 401 for every flush without it'
    else 'set, ' || length(v_secret) || ' characters'
  end;
  return next;

  -- ── pg_cron job ─────────────────────────────────────────────────────────
  begin
    select count(*), max(schedule) into v_jobs, v_schedule
    from cron.job where jobname = 'chatmate-push-flush';
  exception when others then
    v_jobs := -1;
  end;

  item := '3. cron job chatmate-push-flush';
  status := case
    when v_jobs = -1 then 'MISSING'
    when v_jobs = 0 then 'MISSING'
    else 'ok'
  end;
  detail := case
    when v_jobs = -1 then 'pg_cron is not installed on this project'
    when v_jobs = 0 then 're-run the tail of 0005_v2_social.sql'
    else 'schedule ' || coalesce(v_schedule, '?') || ', ' || v_jobs || ' job(s)'
  end;
  return next;

  -- ── triggers that turn writes into queue rows ───────────────────────────
  select count(*) into v_triggers
  from pg_trigger
  where not tgisinternal
    and tgname in (
      'chatmate_push_on_message',
      'chatmate_push_on_chat_request',
      'chatmate_push_on_room_request'
    );

  item := '4. push triggers';
  status := case when v_triggers = 3 then 'ok' else 'MISSING' end;
  detail := v_triggers || ' of 3 installed (message, chat request, room request)';
  return next;

  -- ── queue backlog ───────────────────────────────────────────────────────
  select
    count(*) filter (where sent_at is null and attempts < 5),
    count(*) filter (where sent_at is null and last_error is not null),
    count(*) filter (where sent_at > now() - interval '1 hour'),
    now() - min(created_at) filter (where sent_at is null)
  into v_pending, v_failed, v_sent_hour, v_oldest
  from public.push_queue;

  item := '5. queue backlog';
  status := case
    when v_pending = 0 then 'ok'
    when v_oldest > interval '5 minutes' then 'STUCK'
    else 'busy'
  end;
  detail := v_pending || ' pending, ' || v_failed || ' failing, ' ||
    v_sent_hour || ' sent in the last hour' ||
    coalesce(', oldest pending ' || date_trunc('second', v_oldest)::text, '');
  return next;

  -- ── registered devices ──────────────────────────────────────────────────
  select
    count(*),
    count(distinct user_id),
    count(*) filter (where updated_at > now() - interval '30 days')
  into v_tokens, v_token_users, v_fresh_tokens
  from public.device_tokens;

  item := '6. device tokens';
  status := case when v_tokens = 0 then 'EMPTY' else 'ok' end;
  detail := case
    when v_tokens = 0 then
      'no device ever registered: the app could not get permission, get an FCM token, or find a profile'
    else
      v_tokens || ' tokens for ' || v_token_users || ' users (' ||
      v_fresh_tokens || ' refreshed in the last 30 days)'
  end;
  return next;

  -- ── most recent queue error ─────────────────────────────────────────────
  select last_error, created_at, attempts
  into v_error, v_error_at, v_error_attempts
  from public.push_queue
  where last_error is not null
  order by created_at desc
  limit 1;

  item := '7. last queue error';
  if v_error is null then
    status := 'ok';
    detail := 'no errors recorded';
  else
    status := 'FAILED';
    detail := v_error || ' (' || v_error_attempts || ' attempts, ' ||
      to_char(v_error_at, 'YYYY-MM-DD HH24:MI') || ')';
  end if;
  return next;
end;
$$;

revoke all on function public.push_health() from public, anon, authenticated;
grant execute on function public.push_health() to service_role;
