# ChatMate

**Every room has a secret. Say it. Sign nothing.**

<img src="web/favicon.svg" alt="ChatMate — Where truths unravel." width="180" align="right">

ChatMate is anonymous room chat for students, teams, hostels, friend groups
and anyone who needs a private place to speak honestly. Create an ID, join the
rooms you belong to, and say what needs saying without your name attached. The
sender of a message is never revealed — not to other members, not to room
admins, not to anyone.

**Where truths unravel.**

## The idea

A name makes people careful. A mask makes them honest. ChatMate separates
belonging from speaking: your ID gets you into a room, but it never travels
with the messages you send. Every room is its own circle, with its own people,
its own code and its own secrets.

- Create a request-only, open-link or open-to-all room in seconds.
- Join by search, invite link or six-character room code.
- Invite people directly; they accept before they enter.
- Send, reply, react, edit and delete — always without a sender attached.
- Reveal your handle only when you deliberately choose to.
- See typing state and read receipts without exposing identity.

## Running the app

```bash
flutter pub get
flutter run -d chrome
```

Supabase is configured through `lib/supabase-config.dart` and the compile-time
`SUPABASE_URL` / `SUPABASE_ANON_KEY` dart-defines. Follow
[`supabase/SETUP.md`](supabase/SETUP.md) for the database schema, anonymous
sign-ins, admin account and environment setup.

Never put a `service_role` key in the Flutter app. Only the public anon or
publishable key belongs here.

## Web installation

The web build is a full PWA. It includes:

- Branded title, description, Open Graph and Twitter metadata.
- A generated web manifest with 192px, 512px and maskable icons.
- A branded loading screen carrying the ChatMate quote and slogan.
- `web/install.js` + `web/install.css`: a persistent **INSTALL** tab pinned to
  the side of the app. It appears as soon as the page is ready and stays there
  until ChatMate is installed, so nobody has to wait for a delayed popup.
  Tapping it launches the browser's native installer immediately when Chrome or
  Edge has offered one; otherwise it opens the branded install card with the
  browser's own Install / Add to Home Screen instructions. The card can be
  closed, but the side tab remains.
- `web/flutter_bootstrap.js` + `web/service-worker.js`: disable Flutter's
  generated worker (it unregisters itself), keep an active fetch handler so
  Chromium keeps the app installable, and runtime-cache large static assets
  (CanvasKit wasm, icons, fonts) for faster repeat loads.
- A preload hint for `main.dart.js` and a preconnect to the CanvasKit CDN so the
  first download starts earlier.

Build and serve over HTTPS (or localhost) for the browser to offer install:

```bash
flutter build web --release
```

Chrome and Edge expose the native install flow. On a first visit Chrome may need
about 30 seconds of engagement before it offers the installer; the side tab is
visible the whole time and starts the installer as soon as the browser is ready.
Safari and Firefox have no programmatic install API, so the install card falls
back to the browser's own Install or Add to Home Screen option.

## Launcher icons

`assets/logo/ChatMate-logo.png` is the single source of truth for Android, iOS,
macOS, Windows and web icons. After changing the logo, regenerate everything:

```bash
dart run flutter_launcher_icons
```

## Checks

```bash
flutter analyze
flutter test
flutter build web
```

The app targets Flutter with Supabase Auth/Postgres/Realtime. See
`supabase/0001_init.sql`, `supabase/0002_invite_links.sql`,
`supabase/0003_three_join_modes.sql` and `supabase/SETUP.md` for the backend
contract. Existing Supabase projects must run `0002` and then `0003`; projects
that already ran `0002` only need `0003`.

