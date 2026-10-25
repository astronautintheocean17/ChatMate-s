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

1. Open **SQL Editor** → **New query**.
2. Open `supabase/0002_invite_links.sql`, copy **all** of it.
3. Paste and click **Run**. This is the only file needed for the current
   invite-link / join-mode upgrade.

`0002_invite_links.sql` adds `rooms.join_mode`,
`room_requests.creator_approved`, and the current room RPCs
(`room_access_preview`, `join_room_by_code`, and the updated
create/invite/request functions). It is safe to run more than once.

What the tables contain:

| Table | Purpose |
|---|---|
| `profiles` | one unique handle per auth user |
| `rooms` | name, unique 6-character code, public/private, open/request join mode |
| `room_members` | membership + last-read timestamp |
| `room_requests` | creator-verified invites + creator-approved join requests |
| `messages` | message text, optional reveal flag, soft delete |
| `message_reads` | per-message seen receipts (counts only, never names) |

All writes go through `security definer` RPCs. The `messages` and
`message_reads` tables cannot be read directly by the app at all, so a modified
client still cannot recover a hidden sender.

For an existing project, running `0002_invite_links.sql` is enough. A fresh
project should run `0001_init.sql`, which already contains the same columns and
functions in the full initial schema.

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

1. Device A: create ID `alpha_01`, create a **public** room, invite nobody.
2. Device B: create ID `beta_02`, Join a Room, search the room name or its
   6-character code → **REQUEST TO JOIN**.
3. Device A: open the room → info (top-right) → **INVITES & REQUESTS** → Accept.
4. Device B: the room appears in **Your Rooms**; open it and chat.
5. Send from B with **Reveal me** OFF → A sees no handle, and the three-dot
   menu says "Sender stayed anonymous".
6. Send with **Reveal me** ON → A can tap the three dots → "Sender: @beta_02".
7. A taps three dots on their own message → **Seen by** → count only, no names.
8. Start typing on B → A sees "Someone is typing something…".
9. A creates a **private** room and invites B by handle → B gets it in
   **REQUESTS** → accept → room appears.
10. A opens room info → **SHARE INVITE LINK** → copy. In a private/incognito
    window, open the link → create a new ChatMate ID → **REQUEST TO JOIN**.
    A must verify/approve it in **INVITES & REQUESTS** before that person gets
    access. A link never bypasses creator approval.
11. A opens room info and switches **OPEN LINK / REQUEST ONLY**. In open mode,
    any member can add someone by ID, but A still verifies the invite. In
    request-only mode, only A can add people by ID.
12. Admin link → `yourdad` / `nowaytoguess69` → Users / Rooms → open any room in
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
- **Private rooms** are hidden from name search. They can still be found by
  their exact 6-character code or an invite link, but joining always needs
  creator approval. Invited users also need to accept before they become
  members.
- **Open link rooms** let any member add someone by ChatMate ID, but the creator
  verifies that invite before the invited person can accept. **Request-only
  rooms** limit adding by ID to the creator. In both modes, every link/code join
  is a request until the creator approves it.
- **First member to open a room** marks existing messages read. Seen counts are
  per message and sender-only.
- **Realtime channels** for messages/typing use signal-only payloads
  (`room:<uuid>`), so even a guessed channel name reveals no message text or
  sender. Message content is always fetched through the membership-checked
  `room_messages` RPC.
- **No file uploads / voice notes / reactions** in this build.
- If realtime requests do not refresh instantly, make sure step 3's
  `alter publication supabase_realtime add table public.room_requests;` ran.
  Pull-to-refresh / reopening the sheet still works.
