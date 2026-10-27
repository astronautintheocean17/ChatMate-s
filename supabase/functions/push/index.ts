// supabase/functions/push/index.ts
//
// Flushes public.push_queue to Firebase Cloud Messaging (HTTP v1).
//
// Deploy:
//   supabase functions deploy push --no-verify-jwt
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat ~/secrets/chatmate-firebase.json)"
//   supabase secrets set PUSH_SECRET="<a long random string>"
//
// The database calls this function every 20 seconds (see 0005_v2_social.sql)
// and passes the shared secret in the x-push-secret header. --no-verify-jwt is
// required because the caller is pg_cron, not a signed-in user; the shared
// secret is what protects the endpoint.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type QueueRow = {
  id: number;
  user_id: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  attempts: number;
};

type TokenRow = { token: string; platform: string };

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const PUSH_SECRET = Deno.env.get('PUSH_SECRET') ?? '';
const SERVICE_ACCOUNT_RAW = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '';

let cachedToken: { value: string; expiresAt: number } | null = null;

function base64Url(input: Uint8Array | string): string {
  const bytes =
    typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function serviceAccount(): ServiceAccount | null {
  if (!SERVICE_ACCOUNT_RAW) return null;
  try {
    const parsed = JSON.parse(SERVICE_ACCOUNT_RAW);
    if (!parsed.private_key || !parsed.client_email) return null;
    return parsed as ServiceAccount;
  } catch {
    return null;
  }
}

async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) {
    return cachedToken.value;
  }

  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );

  const assertion = `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google token exchange failed: ${await response.text()}`);
  }

  const payload = await response.json() as {
    access_token: string;
    expires_in: number;
  };

  cachedToken = {
    value: payload.access_token,
    expiresAt: now + (payload.expires_in ?? 3600),
  };

  return cachedToken.value;
}

async function sendToToken(
  account: ServiceAccount,
  token: string,
  row: QueueRow,
  access: string,
): Promise<'ok' | 'stale' | 'error'> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${access}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: row.title, body: row.body },
          data: Object.fromEntries(
            Object.entries(row.data ?? {}).map(([key, value]) => [
              key,
              String(value),
            ]),
          ),
          android: { priority: 'HIGH', notification: { channel_id: 'chatmate_messages' } },
          webpush: {
            notification: {
              icon: '/icons/Icon-192.png',
              tag: `room-${(row.data ?? {})['room_id'] ?? 'chatmate'}`,
            },
          },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        },
      }),
    },
  );

  if (response.ok) return 'ok';

  const text = await response.text();
  if (response.status === 404 || text.includes('UNREGISTERED')) {
    return 'stale';
  }
  console.error(`FCM ${response.status}: ${text}`);
  return 'error';
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } });
  }

  if (PUSH_SECRET && request.headers.get('x-push-secret') !== PUSH_SECRET) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const account = serviceAccount();
  if (!account) {
    return new Response(
      JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT is not set' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const { data: rows, error } = await admin
    .from('push_queue')
    .select('id, user_id, title, body, data, attempts')
    .is('sent_at', null)
    .lt('attempts', 5)
    .order('id', { ascending: true })
    .limit(100);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const queue = (rows ?? []) as QueueRow[];
  if (queue.length === 0) {
    return new Response(JSON.stringify({ sent: 0, skipped: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const ids = queue.map((row) => row.id);
  const userIds = [...new Set(queue.map((row) => row.user_id))];

  const { data: tokenRows } = await admin
    .from('device_tokens')
    .select('token, user_id, platform')
    .in('user_id', userIds);

  const tokensByUser = new Map<string, TokenRow[]>();
  for (const row of (tokenRows ?? []) as Array<TokenRow & { user_id: string }>) {
    const list = tokensByUser.get(row.user_id) ?? [];
    list.push({ token: row.token, platform: row.platform });
    tokensByUser.set(row.user_id, list);
  }

  let access: string;
  try {
    access = await accessToken(account);
  } catch (tokenError) {
    console.error(tokenError);
    return new Response(JSON.stringify({ error: 'Could not reach FCM' }), {
      status: 502,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let sent = 0;
  let skipped = 0;
  const stale: string[] = [];

  for (const row of queue) {
    const targets = tokensByUser.get(row.user_id) ?? [];
    if (targets.length === 0) {
      skipped++;
      await admin
        .from('push_queue')
        .update({ sent_at: new Date().toISOString(), last_error: 'no devices' })
        .eq('id', row.id);
      continue;
    }

    let delivered = 0;
    let lastError: string | null = null;

    for (const target of targets) {
      const result = await sendToToken(account, target.token, row, access);
      if (result === 'ok') {
        delivered++;
      } else if (result === 'stale') {
        stale.push(target.token);
      } else {
        lastError = 'fcm rejected the message';
      }
    }

    if (delivered > 0) {
      sent++;
      await admin
        .from('push_queue')
        .update({ sent_at: new Date().toISOString(), last_error: null })
        .eq('id', row.id);
    } else {
      await admin
        .from('push_queue')
        .update({
          attempts: (row.attempts ?? 0) + 1,
          last_error: lastError ?? 'undelivered',
        })
        .eq('id', row.id);
    }
  }

  if (stale.length > 0) {
    await admin.from('device_tokens').delete().in('token', stale);
  }

  // Keep the table from growing forever.
  await admin
    .from('push_queue')
    .delete()
    .lt('created_at', new Date(Date.now() - 86_400_000).toISOString());

  return new Response(
    JSON.stringify({ sent, skipped, stale: stale.length, queued: ids.length }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});

