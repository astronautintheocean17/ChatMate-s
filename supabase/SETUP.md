# ChatMate — Supabase setup (first time, step by step)

Do these in order. Nothing in the app will work until steps 1–5 are done.

---

## 0. What you are setting up

ChatMate uses **Supabase Auth** for identity, **Postgres + Row Level Security** for data,
and **Realtime** for live messages, typing signals and join requests.

- Normal users: anonymous Supabase sessions + one unique ChatMate ID (handle).
- Admin: a real Supabase email/password user with `app_metadata.is_admin = true`.
- Messages: the sender's id is **never** returned to clients. Only an optional
  `sender_handle` is returned, and only for messages where the sender turned on
  "Reveal me" before sending. Admins can read every room (ghost mode) but still
  cannot unmask a sender who stayed anonymous.

---

## 1. Rotate the leaked key (important)

The key that was pasted into `lib/supabase-config.dart` was a **`service_role`** key.
That key bypasses Row Level Security and must never be in an app.

1. Open your project → **Project Settings** → **API**.
2. Open **JWT Settings** → **Generate a new JWT secret** → confirm.
   This invalidates the old anon and service_role keys.
3. Go back to **Project Settings → API → Project API keys** and copy the
   **`anon` / `public`** key (NOT `service_role`).
   If your dashboard shows the newer **publishable** key, that also works.
4. Keep the `service_role` key only inside the Supabase dashboard. Never paste it
   into Flutter, GitHub, screenshots or chat.

> If you already shared the service_role key anywhere, rotating the JWT secret is
> mandatory. Existing users will need to sign in again after rotation.

---

## 2. Enable Anonymous sign-ins

1. **Authentication** → **Providers** (or **Sign In / Providers**).
2. Find **Anonymous sign-ins** → enable it → **Save**.

This is how a normal user gets a private session before choosing a ChatMate ID.
There is no email or password for normal users by design.

Also confirm **Email** provider is enabled (it is by default). The admin uses it.

---

## 3. Create or upgrade the schema

### New / empty Supabase project

1. Open **SQL Editor** → **New query**.
2. Open `supabase/0001_init.sql` from this project, copy **all** of it.
3. Paste into the SQL Editor and click **Run**.

### Existing ChatMate project (already has tables)

Run these files **in order**, each in a new SQL Editor query:

1. `supabase/0002_invite_links.sql`
2. `supabase/0003_three_join_modes.sql`
3. `supabase/0004_media.sql` — private photos, GIFs, stickers, 30-second videos
4. `supabase/0005_v2_social.sql` — the v2 social layer (see below)

Every file is safe to run more than once.

#### What `0005_v2_social.sql` adds

| Piece | What it does |
|---|---|
| `rooms.kind` | `group` or `direct`; a pair can only ever have one direct room |
| `rooms.identity_mode` | `mixed` (per-message, the v1 default), `anonymous`, or `reveal` |
| `chat_requests` | the 1:1 request flow before a direct chat exists |
| `messages.reply_to_id` | quoted replies |
| `message_reactions` | one emoji per person per message |
| `device_tokens` / `push_queue` | FCM token storage and the outbound notification queue |
| `my_conversations()` | one WhatsApp-style list of direct chats *and* groups |
| `home_search()` | search limited to my own rooms and the people I chat with |
| `search_profiles()` | ID search by keyword — blank query returns nothing, never a browse-all |
| `start_direct_chat()` / `respond_chat_request()` | send, accept, decline a chat request |
| `react_message()` / `set_room_identity()` | reactions and the creator's room-wide anonymity switch |
| `register_device_token()` | attach this device to this profile |

The identity switch is deliberately retroactive: setting a group to
**REVEAL CHATS** reveals the sender of every message already in it, and setting
it to **ANONYMOUS CHAT** hides all of them. `room_messages()` and
`my_conversations()` both resolve `sender_handle` from the room's mode, so a
modified client cannot undo it.

#### The three room modes



| Mode | Search | Joining |
|---|---|---|
| **Request only** | Hidden; exact code/ID only | Creates a pending request; creator approves |
| **Open link** | Hidden; exact code/link only | Joins instantly; no approval |
| **Open to all** | Findable by name or code | Joins instantly; no approval |

What the tables contain:

| Table | Purpose |
|---|---|
| `profiles` | one unique handle per auth user |
| `rooms` | name, unique 6-character code, visibility, join mode, `open_to_all` |
| `room_members` | membership + last-read timestamp |
| `room_requests` | creator-verified invites + creator-approved join requests |
| `messages` | message text, optional reveal flag, soft delete |
| `message_reads` | per-message seen receipts (counts only, never names) |

All writes go through `security definer` RPCs. The `messages` and
`message_reads` tables cannot be read directly by the app at all, so a modified
client still cannot recover a hidden sender.

A fresh project should run `0001_init.sql`; it already contains the same columns
and functions, so `0003` is not needed after a fresh install.

When upgrading, any existing room whose old mode was **open** becomes an
**Open link** room: it joins instantly and stops appearing in name search. Any
old **request** room becomes **Request only** and stays private. Any pending
request from the old room is accepted automatically when that person next uses
the room's link.

---

## 4. Create the admin login

The admin screen accepts the ID `yourdad` and maps it to the email
`yourdad@chatmate.app`. Supabase stores passwords hashed; it never stores plain
text.

1. **Authentication** → **Users** → **Add user** → **Create new user**.
2. Email: `yourdad@chatmate.app`
3. Password: `nowaytoguess69` (or change it, then use the new one in the app).
4. Turn **Auto Confirm User** ON (so no email confirmation is needed).
5. Click **Create user**.
6. Go back to **SQL Editor** and run:

```sql
update auth.users
set raw_app_meta_data =
  coalesce(raw_app_meta_data, '{}'::jsonb) || '{"is_admin": true}'::jsonb
where email = 'yourdad@chatmate.app';
```

7. The admin must sign out and back in for the new claim to appear in the JWT.

Admin login link: bottom of the **Create ID** screen (`ADMIN ACCESS`).


---

## 5. Put the anon key into Flutter

Open `lib/supabase-config.dart` and replace the placeholder:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://rdhoxwhrkzyvcpscynsj.supabase.co';
  static const String supabaseAnonKey = 'PASTE_YOUR_ANON_OR_PUBLISHABLE_KEY_HERE';
}
```

Optional (better for CI/release): keep the key out of source and pass:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://rdhoxwhrkzyvcpscynsj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

`lib/supabase-config.dart` already reads those two `--dart-define` values first.

---

## 6. Run

```bash
flutter pub get
flutter run -d chrome        # website
flutter run -d <device-id>   # Android / iOS
```

If the app shows "Supabase is not configured", the anon key is still the
placeholder from step 5.

---

## 7. Test with two accounts

Use two browsers / two devices (or one normal + one incognito).

1. Device A: create ID `alpha_01`, create an **Open to all** room, invite
   nobody.
2. Device B: create ID `beta_02`, Join a Room, search the room name or its
   6-character code → **JOIN**. It opens immediately; no approval.
3. Device A: open the room → info (top-right) → **INVITES & REQUESTS**. There
   should be nothing pending.
4. Device B: the room appears in **Your Rooms**; open it and chat.
5. Send from B with **Reveal me** OFF → A sees no handle, and the three-dot
   menu says "Sender stayed anonymous".
6. Send with **Reveal me** ON → A can tap the three dots → "Sender: @beta_02".
7. A taps three dots on their own message → **Seen by** → count only, no names.
8. Start typing on B → A sees "Someone is typing something…".
9. A creates a **Request only** room and invites B by handle → B gets it in
   **REQUESTS** → accept → room appears.
10. A opens a **Request only** room's info → **SHARE INVITE LINK** → copy. In a
    private/incognito window, open the link → create a new ChatMate ID →
    **REQUEST TO JOIN**. A must approve it in **INVITES & REQUESTS** before
    that person gets access.
11. A creates an **Open link** room → copy its link. Search its exact name in
    Join a Room: it must not appear. Open the link in another window → **JOIN
    ROOM** works immediately with no approval.
12. A creates an **Open to all** room → it appears in Join a Room by name, and
    anyone can tap **JOIN** immediately.
13. A opens room info and switches between **REQUEST ONLY / OPEN LINK / OPEN TO
    ALL**. The search and instant/pending behavior must match the selected
    label exactly.
14. Admin link → `yourdad` / `nowaytoguess69` → Users / Rooms → open any room in
    ghost mode. Anonymous senders stay anonymous.

Permission checks to try (they should all fail):

- B tries to call `delete_message` on A's message in a room where B is not creator.
- B tries to call `admin_stats` from a normal account.
- B tries to open a private room without a code or invite (it will not appear).
- B tries to select `messages` directly through the REST API (permission denied).

---

## 8. Notes and limits (intentional)

- **Anonymous session = this device.** If the app is uninstalled or browser
  storage is cleared, the identity cannot be recovered. There is no logout for
  normal users, as requested. Changing the handle is possible in Profile.
- **Request-only rooms** are private and hidden from name search. They can be
  found by exact 6-character code or invite link, but every join is a request
  until the creator approves it. Only the creator can add people by ChatMate ID.
- **Open link rooms** are public but hidden from name search. Anyone with the
  exact link or code joins instantly; no approval is needed. Any member can add
  someone by ChatMate ID, but that direct invite still needs creator
  verification before the invited person accepts.
- **Open to all rooms** are public and searchable. Anyone can join instantly by
  name/search, link or code; no approval is needed.
- **First member to open a room** marks existing messages read. Seen counts are
  per message and sender-only.
- **Realtime channels** for messages/typing use signal-only payloads
  (`room:<uuid>`), so even a guessed channel name reveals no message text or
  sender. Message content is always fetched through the membership-checked
  `room_messages` RPC.
- **No voice notes** in this build. Photos, GIFs, stickers and 30-second videos
  are supported, plus replies, reactions and an optional per-room reveal switch.
- If realtime requests do not refresh instantly, make sure step 3's
  `alter publication supabase_realtime add table public.room_requests;` ran.
  Pull-to-refresh / reopening the sheet still works.

---

## 9. Push notifications (optional)

Push is a bonus layer. With none of this configured the app still works; it just
never shows a notification while closed.

1. **Deploy the function**

   ```bash
   supabase functions deploy push --no-verify-jwt
   ```

   `--no-verify-jwt` is required because the caller is `pg_cron`, not a signed-in
   user. The `x-push-secret` header is what protects it.

2. **Give it the Firebase service account** (Project settings → Service accounts
   → *Generate new private key*):

   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat ~/secrets/chatmate-firebase.json)"
   supabase secrets set PUSH_SECRET="$(openssl rand -hex 32)"
   ```

   Never commit that JSON file.

3. **Point the schedule at the function** — run once in the SQL editor:

   ```sql
   select vault.create_secret(
     'https://<PROJECT-REF>.functions.supabase.co/push', 'push_url');
   select vault.create_secret(
     '<the same value you passed to PUSH_SECRET>', 'push_secret');
   ```

   `0005_v2_social.sql` already scheduled `chatmate-push-flush` to call
   `public.trigger_push_flush()` every 20 seconds. Until the two vault secrets
   exist that function returns immediately.

4. **Web push** also needs a VAPID key. Firebase console → Project settings →
   Cloud Messaging → Web configuration → *Web Push certificates*. Paste it into
   `kWebPushVapidKey` in `lib/data/push-service.dart` and make sure
   `web/firebase-messaging-sw.js` is deployed with the site.

5. **iOS** needs an Apple Developer Program account: Xcode → Runner → Signing &
   Capabilities → **+ Push Notifications**, then upload an APNs `.p8` key to
   Firebase. `ios/Runner/Runner.entitlements` and the `remote-notification`
   background mode are already in place, so this is the only missing piece.

Notifications respect anonymity. A message in an anonymous room is delivered as
`New message in <room>` with no handle; a revealed room shows `@handle in
<room>`; a direct chat shows `@handle`.

