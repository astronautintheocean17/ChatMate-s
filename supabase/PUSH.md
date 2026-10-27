# Push notifications — audit, fixes and the last three steps

This file answers *"why did no notification ever arrive?"*. It lists every link
in the chain, what was actually broken, what is now fixed in the repo, and the
three things only you can do (they need your Firebase / Supabase dashboards).

---

## 1. Verdict

| # | Link in the chain | Before | Now |
|---|---|---|---|
| 1 | Permission asked | `main()` asked **before** `runApp`, over a blank frame, and never again | asked from `AppShell` **after the first frame**, once per install (`SharedPreferences`), re-askable from Profile |
| 2 | FCM token | read once, only if a profile already existed | `register()` + `getToken()`, cached, refreshed through `onRegistered` |
| 3 | Token stored | only at boot | boot **+** every auth change **+** after a handle is created |
| 4 | `device_tokens` row | never deleted on sign-out | deleted before `AuthService.signOut()` |
| 5 | DB trigger → `push_queue` | fine (`0005_v2_social.sql`) | unchanged |
| 6 | `pg_cron` → edge function | fine, but silently did nothing without vault secrets | unchanged — **still needs your 2 secrets** |
| 7 | Edge function | **`Deno.serve` was nested inside `sendToToken()`** → no server ever started, every request failed | brace fixed; the module serves again |
| 8 | FCM → Android | `chatmate_messages` channel created in `MainActivity.kt` | fine |
| 9 | FCM → iOS | `Runner.entitlements` existed but **no build config referenced it** → no `aps-environment` in the signed app → APNs never registered | `CODE_SIGN_ENTITLEMENTS` set for Debug/**Profile**/**Release**, plus a production variant for Release |
| 10 | FCM → web | service worker drew a **second** copy of every notification | data-only handler only |
| 11 | Tap → screen | taps either opened a room or **threw the user back to `SessionGate` via `pushAndRemoveUntil`** (looked like the app restarted) | routed by `type`: requests → `RequestsScreen`, messages → `ChatRoomScreen` |
| 12 | Cold-start tap | fixed 600 ms delay, usually lost | waits (bounded) for a navigator + restored session |

Short version: **7 of the 12 links were broken in code.** They are fixed. The
remaining 3 are configuration only (vault secrets, Firebase service account,
APNs key) and are listed in §3.

---

## 2. The chain, and what each link needs

```
user taps "Allow"
  └─ FCM token ......................... lib/data/push-service.dart
      └─ public.device_tokens .......... 0005_v2_social.sql §4
          └─ insert into messages
              └─ trigger push_on_message → public.push_queue ...... 0005 §7
                  └─ pg_cron chatmate-push-flush (every 20s) ...... 0005, tail
                      └─ trigger_push_flush() → net.http_post ..... needs vault: push_url, push_secret
                          └─ supabase/functions/push (Deno)
                              └─ FCM HTTP v1 ......... needs secret FIREBASE_SERVICE_ACCOUNT
                                  └─ Android / iOS / Web
                                      └─ tap → lib/data/push-service.dart → screen
```

### Client (Flutter)

- `lib/data/push-service.dart` — `boot()`, `maybePrompt()`, `enable()`,
  `syncToken()`, `signOut()`, foreground SnackBar, tap routing.
- `lib/common/screens/app-shell.dart` — calls `maybePrompt()` once, after the
  first frame.
- `lib/users/screens/profile-screen.dart` — the "Push notifications" row calls
  `enable()` and tells the truth about *denied* / *unavailable*.
- `lib/main.dart` — registers `chatmateBackgroundHandler` **before** `runApp`
  (required by FCM), then boots push without blocking the first frame.

### Database (`0005_v2_social.sql`)

- `public.device_tokens (token pk, user_id, platform, created_at, updated_at)`,
  RLS: a row is visible only to its owner.
- `public.push_queue (id, user_id, title, body, data jsonb, attempts,
  last_error, created_at, sent_at)`.
- `push_on_message`, `push_on_chat_request`, `push_on_room_request` — one queue
  row per recipient, never to the sender, anonymity respected.
- `trigger_push_flush()` — reads `vault.decrypted_secrets` (`push_url`,
  `push_secret`) and POSTs to the edge function. **Returns silently when
  `push_url` is missing** — the number one reason for "it just never fires".

### Edge function (`supabase/functions/push/index.ts`)

- `--no-verify-jwt`, protected by `x-push-secret` instead.
- `sendToToken()` returns `ok` / `stale` / `error`; `stale` tokens are removed
  from `device_tokens` so a reinstall cannot loop forever.
- A row is marked `sent_at` when at least one device accepted it; otherwise
  `attempts` is bumped and `last_error` stored (5 tries max, rows older than
  24 h pruned).

---

## 3. Three things you still have to do (10 minutes)

### 3.1 Deploy the fixed function

```bash
supabase functions deploy push --no-verify-jwt
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat ~/secrets/chatmate-firebase.json)"
supabase secrets set PUSH_SECRET="$(openssl rand -hex 32)"
```

`FIREBASE_SERVICE_ACCOUNT` comes from Firebase console → Project settings →
**Service accounts** → *Generate new private key*. Keep the JSON out of the
repo.

Then, in the SQL editor, give `pg_cron` the URL and the same secret:

```sql
select vault.create_secret('https://<PROJECT-REF>.functions.supabase.co/push', 'push_url');
select vault.create_secret('<the same PUSH_SECRET value>', 'push_secret');
```

### 3.2 iOS: upload the APNs key

Apple Developer → Keys → **+** → *Apple Push Notifications service (APNs)* →
download the `.p8`. Firebase console → Project settings → **Cloud Messaging** →
*iOS app configuration* → upload it with the Key ID and your Team ID.

The app side is done: `ios/Runner/Runner.entitlements`
(`aps-environment=development`), `ios/Runner/Runner.Release.entitlements`
(`production`), `UIBackgroundModes: remote-notification`, and all three build
configurations point at one of them. Push also needs a real bundle id — see §5.

### 3.3 Web (only if you ship the PWA)

Firebase console → Project settings → Cloud Messaging → **Web Push
certificates** → copy the key pair into `kWebPushVapidKey` in
`lib/data/push-service.dart`. Until then web push reports `unavailable` and the
rest of the app is unaffected. `web/firebase-messaging-sw.js` is in place and
must stay at the site root.

---

## 4. Verify, in this order

1. **Database chain** — run the diagnostic function (added by
   `supabase/0006_push_diagnostics.sql`):

   ```sql
   select * from public.push_health();
   ```

   Seven rows, in the order a notification travels. Fix the first one whose
   `status` is not `ok`; everything below it is untested.

2. **App registers a device** — sign in, open Profile, tap **Push
   notifications**, accept the OS prompt. Then:

   ```sql
   select user_id, platform, updated_at from public.device_tokens order by updated_at desc;
   ```

   No row? The app never got a token (read the *device tokens* hint in
   `push_health`) or the account has no profile handle yet.

3. **Queue fills** — from a second account, send a message, then:

   ```sql
   select id, user_id, title, attempts, last_error, sent_at, created_at
   from public.push_queue order by id desc limit 5;
   ```

   No row → the trigger is missing (`push_health` row 4). Row stays unsent →
   the cron/secret/function link is broken (rows 1–3 and 7).

4. **Function answers** — bypass cron and call it yourself:

   ```bash
   curl -i -X POST "https://<PROJECT-REF>.functions.supabase.co/push" \
        -H "x-push-secret: <PUSH_SECRET>" -H "Content-Type: application/json" -d '{}'
   ```

   `{"sent":0,"skipped":0}` = healthy. `401` = secret mismatch. `500` =
   `FIREBASE_SERVICE_ACCOUNT` missing/invalid. `404` or HTML = not deployed.

5. **Force one notification to yourself** — paste your own user id:

   ```sql
   insert into public.push_queue (user_id, title, body, data)
   values ('<your-user-id>', 'Test push', 'If you can read this, FCM works.',
           '{"type":"message","room_id":"","room_name":"Chat"}'::jsonb);
   ```

   The next cron tick (≤ 20 s) delivers it. Nothing on the device? It is
   FCM → OS: Android (channel + permission), iOS (APNs key + entitlements),
   web (VAPID + HTTPS).

6. **Tap behaviour** — a `chat_request` notification must open **Requests**, a
   message notification must open that room, and back must return to where the
   user was instead of closing the app.

---

## 5. Facts that bite later

- **Bundle id**: `com.example.chatmate` is used by `android/app/build.gradle.kts`,
  the iOS project and `GoogleService-Info.plist`. They must stay identical. A
  real App Store build needs a non-`com.example` id, changed in all of them
  *and* in a new Firebase app (new `GoogleService-Info.plist` +
  `google-services.json`).
- **iOS sandbox vs production**: debug/profile builds use
  `aps-environment=development` (APNs sandbox). Release builds use
  `Runner.Release.entitlements` (`production`). A production push sent to a
  debug build is rejected with `BadDeviceToken` — that is normal.
- **Android 13+** needs the runtime `POST_NOTIFICATIONS` grant; that is what
  `requestPermission()` shows. Declared in `AndroidManifest.xml`, channel
  `chatmate_messages` created in `MainActivity.kt`.
- **One prompt only on iOS**: after "Don't Allow" the prompt never returns; the
  app now reports *blocked* and points at system settings.
- **Foreground** notifications are drawn by the app itself (SnackBar with
  OPEN), because Android and iOS do not display them by default.

## 6. Known limitations

- Badge count is fixed at `1`; there is no unread counter.
- No notification grouping/summary; one notification per queued message.
- Web click opens `/?room=<id>`, but the Flutter app does not read that query
  parameter yet, so it lands on Home.
- Unsent queue rows are deleted after 24 h even if they never went out.
