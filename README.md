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

`analysis_options.yaml` excludes `build/**` on purpose: Xcode's Swift Package
Manager checkouts (`build/ios/SourcePackages/…`) get linted otherwise and buried
the real output in third-party noise.

The app targets Flutter with Supabase Auth/Postgres/Realtime. See
`supabase/0001_init.sql` … `supabase/0006_push_diagnostics.sql` and
`supabase/SETUP.md` for the backend contract, and `supabase/PUSH.md` for the
push chain. Existing Supabase projects run the numbered files in order; every
one of them is safe to re-run.

## v2 in one screen

- **Profile / Home / Search** bottom tabs. Home is a WhatsApp-style list of every
  conversation; Groups is a separate screen of joined rooms only.
- **Private 1:1 chats** open on tap: `start_direct_chat` reuses or creates exactly
  one shared `direct` room per pair, so neither side can open a second one.
  RequestsScreen still accepts/declines/cancels chat requests and room join
  requests.
- **In-chat**: replies with a quoted preview, emoji reactions (long-press or
  double-tap ❤️), clickable `http`/`https`/`www` links in text and captions.
- **Room identity** is a creator switch: *anonymous* (no names, ever), *reveal*
  (every message signed, retroactively) or the v1 *per-message* toggle.
- **Push** via FCM HTTP v1, with a queued, cron-flushed delivery path.



---

## Code map — every file, in one line

`path (lines)` — what it owns. Folders: `data/` = Supabase + Firebase calls,
`screens/` = UI only, `theme/` = design tokens, `common/` = shared UI + services.

### Boot, shell, process-wide rules

| File | Owns |
|---|---|
| `lib/main.dart` (88) | `Supabase.initialize`, FCM background handler, `MaterialApp` (themes, `navigatorKey: appNavigatorKey`), `AppExitGuard` around the root, `PushService.boot()` after `runApp` |
| `lib/supabase-config.dart` (19) | URL + anon key from `--dart-define`, `isSupabaseConfigured` |
| `lib/firebase_options.dart` (89) | Generated FCM config per platform (web `appId` mirrors the service worker) |
| `lib/theme/app-theme.dart` (190) | Light/dark palettes (`AppTheme.bg/ink/surface/muted/accent/line`) and type helpers (`AppText.serif/body/mono`) |
| `lib/theme/theme-controller.dart` (43) | `ChangeNotifier` for light/dark/system + `SharedPreferences` persistence |
| `lib/common/back/back-coordinator.dart` (117) | **The only place that may close the app.** Singleton interceptor stack + the "Leave ChatMate?" dialog |
| `lib/common/widgets/app-exit-guard.dart` (38) | `PopScope(canPop: false)` on the root route → hands every system back press to the coordinator |
| `lib/common/widgets/link-text.dart` (168) | Detects `http/https/www` and renders tappable links (`url_launcher`) |
| `lib/common/widgets/mate-avatar.dart` (79) | Deterministic initial-avatar per handle (no photos, no identity leak) |
| `lib/common/widgets/swipe-to-reply.dart` (65) | Swipe-right gesture + haptic used by message bubbles |
| `lib/common/widgets/theme-toggle-button.dart` (70) | Sun/moon button; writes through `ThemeController` |
| `lib/common/utils/format.dart` (42) | Relative time, day headers, compact counts, file sizes |

### First-run and routing (`lib/common/screens/`)

| File | Owns |
|---|---|
| `session-gate.dart` (122) | **The router.** Decides Landing / Create ID / AppShell / Admin dashboard / Room invite from session + profile + role + invite code |
| `landing-screen.dart` (2045) | Marketing first-run page with its own palette (`_C`) and type scale (`_T`); CTAs into Create ID; intentionally not themed by `AppTheme` |
| `create-id-screen.dart` (427) | Handle + display name form → `ProfileService.create`, then `PushService.syncToken`; link to admin sign-in |
| `setup-required-screen.dart` (76) | Shown when `isSupabaseConfigured` is false (missing `--dart-define`) |
| `app-shell.dart` (178) | 3-tab `IndexedStack` (Profile / Home / Search), bottom bar, `AppShellScope`, registers the "back → Home" interceptor, fires `PushService.maybePrompt()` after the first frame |

### App tabs and room flows (`lib/users/screens/`)

| File | Owns |
|---|---|
| `home-screen.dart` (943) | WhatsApp-style conversation list (`social-service`) with an **ALL / GROUPS / CHATS** switch, pending-request banner, action cards (new room / join / browse), pull-to-refresh |
| `search-screen.dart` (315) | Debounced handle search; tapping a person calls `SocialService.startChat` and opens the shared direct room |
| `profile-screen.dart` (526) | Profile tab: stats, ACCOUNT rows (change ID, chat requests, groups), **Push notifications** row, theme toggle |
| `chat-room-screen.dart` (2244) | The room: realtime messages, send/reply/react/edit/delete, media bubbles, typing + read receipts, room info sheet |
| `room-info-sheet.dart` (1102) | Members, join mode, room code/link, invites, identity mode switch, remove member, leave/delete room |
| `requests-screen.dart` (446) | Incoming/outgoing chat requests + room join requests; accept → opens the shared direct room |
| `groups-screen.dart` (236) | Groups tab: only joined rooms |
| `create-room-screen.dart` (584) | New room (name, code, join mode, identity mode) → opens it |
| `join-room-screen.dart` (419) | Join by six-character code or pasted link |
| `existing-rooms-screen.dart` (311) | Browse public ("open to all") rooms |
| `room-invite-screen.dart` (391) | Landing for `/join/<code>` links: preview → join → open room |


### Admin (`lib/admin/screens/`)

| File | Owns |
|---|---|
| `admin-login-screen.dart` (210) | Email/password sign-in; `AuthService` refuses any account without the admin flag/row |
| `dashboard-screen.dart` (310) | Admin home: counters, entry points, **sign out** (clears the device token first) |
| `admin-users-screen.dart` (329) | User list, role and account actions |
| `admin-rooms-screen.dart` (251) | Room list with search/filters |
| `admin-room-details-screen.dart` (426) | One room: members, messages (ghost mode), moderation |

### Data layer (`lib/data/`)

| File | Owns |
|---|---|
| `auth-service.dart` (61) | Session, `currentUserId`, `hasSession`, `isAdmin`, `signIn`, `signOut` |
| `profile-service.dart` (73) | `current()` profile row, `create` handle, `changeHandle` |
| `room-service.dart` (174) | Room CRUD, join modes, members, join/leave, join requests, invite/remove member |
| `chat-service.dart` (102) | Messages: list, `send`, `sendMedia`, `delete`, `markRead`, `seenReceipt` |
| `social-service.dart` (137) | Conversations list, chat requests, handle search, **`registerDeviceToken` / `removeDeviceToken`** |
| `room-link-service.dart` (77) | Builds/parses `/join/<code>` invite links |
| `admin-service.dart` (47) | The admin RPCs (`admin_*` functions) |
| `models.dart` (652) | Room, message, member, room-request, profile models + enums + JSON mapping |
| `social-models.dart` (218) | Conversation, chat request, social user models (v2 list views) |
| `errors.dart` (17) | `describeError()` — one human sentence for every Supabase/Postgrest failure |
| `push-service.dart` (405) | FCM: `boot`, `maybePrompt`, `enable`, `syncToken`, `signOut`, foreground SnackBar, tap → screen routing |

### Media (`lib/media/`)

| File | Owns |
|---|---|
| `media-service.dart` (317) | Pick/compress/upload to the private `chat-media` bucket, signed URLs |
| `media-catalog.dart` (154) | Kinds (`image/gif/sticker/video`), limits, aspect-ratio helpers |
| `giphy-service.dart` (137) | Giphy trending/search over HTTPS |
| `media-prefs.dart` (141) | Remembers last picker tab / GIF query / sticker pack |
| `media-actions.dart` (120) | Save, share, open (`file_saver`, `share_plus`) |
| `media-attach-sheet.dart` (202) | The "+" chooser sheet |
| `media-preview-sheet.dart` (355) | Preview, trim to 30 s, caption, send |
| `media-bubble-content.dart` (208) | Renders an image/GIF/sticker/video inside a message bubble |
| `media-viewer-screen.dart` (337) | Fullscreen viewer + actions |
| `gif-picker-sheet.dart` (548) | Giphy grid with search |
| `sticker-picker-sheet.dart` (348) | Sticker pack grid |

### Native shell, PWA and backend

| File | Owns |
|---|---|
| `android/.../MainActivity.kt` | Creates the `chatmate_messages` notification channel (Android 8+ drops notifications without it) |
| `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS`, default channel/icon meta-data |
| `ios/Runner/AppDelegate.swift` | Plain Flutter delegate; `firebase_core` configures `FirebaseApp` itself |
| `ios/Runner/Runner.entitlements` | Debug/Profile: `aps-environment=development` + `remote-notification` |
| `ios/Runner/Runner.Release.entitlements` | Release: `aps-environment=production` |
| `web/firebase-messaging-sw.js` | Web push display + click routing (must stay at site root) |
| `web/service-worker.js`, `web/flutter_bootstrap.js`, `web/install.js`, `web/install.css`, `web/manifest.json` | PWA: caching, install tab, manifest |
| `supabase/0001_init.sql` (1449) | Fresh install: enums, rooms, members, messages, RLS, RPCs, admin functions |
| `supabase/0002_invite_links.sql` (652) | Delta for existing projects: invite links |
| `supabase/0003_three_join_modes.sql` (503) | Request only / Open link / Open to all |
| `supabase/0004_media.sql` (481) | `chat-media` bucket, member-only policies, size limits |
| `supabase/0005_v2_social.sql` (1365) | Identities, direct chats, replies, reactions, room identity modes, `device_tokens`, `push_queue`, push triggers, cron |
| `supabase/0006_push_diagnostics.sql` (161) | `public.push_health()` — 7-row diagnostic of the whole push chain |
| `supabase/functions/push/index.ts` | Deno flusher: queue → FCM HTTP v1, prunes stale tokens |
| `supabase/SETUP.md` | Backend setup, top to bottom |
| `supabase/PUSH.md` | Push audit: what was broken, what is fixed, what is left |

### Tests (`test/`)

| File | Proves |
|---|---|
| `app_shell_smoke_test.dart` | All three tabs and Create ID render with no backend; back goes Home, then asks |
| `back_guard_test.dart` | Back never closes the app without EXIT; pushed routes still pop |
| `theme_controller_test.dart` | Theme choice survives a restart |
| `social_models_test.dart` | Conversation/request JSON mapping |
| `room_link_test.dart` | Invite-link build/parse |
| `link_text_test.dart` | URL detection in message bodies |
| `format_test.dart` | Time/day/count formatting |
| `home_hero_type_test.dart` | Landing uses the serif for the hero, not for body copy |
| `swipe_to_reply_test.dart` | Swipe gesture fires exactly once |


---

## Screens, navigation and the logic between them

### One decision point: `SessionGate`

Nothing else decides "what screen am I on" at startup. `SessionGate` rebuilds on
the Supabase auth stream and picks exactly one branch:

```
Supabase not configured              → SetupRequiredScreen   (lib/common/screens/setup-required-screen.dart)
no session, no invite                → LandingScreen         (…/landing-screen.dart) → CTA → CreateIdScreen
no session, invite code in URL      → CreateIdScreen(pendingRoomCode: code)   ← make an ID, then join
session + admin role                 → DashboardScreen       (lib/admin/screens/dashboard-screen.dart)
session, no profile row yet          → CreateIdScreen(pendingRoomCode: invite)
session + profile + invite code      → RoomInviteScreen      (lib/users/screens/room-invite-screen.dart)
session + profile                    → AppShell              (lib/common/screens/app-shell.dart, Home tab first)
load failed                          → same gate with the error + TRY AGAIN (never a blank screen)
```

`AppShell` is the signed-in frame: an `IndexedStack` of **Profile / Home /
Search** plus the bottom bar, and it publishes `AppShellScope` so a child can
switch tabs (Home does this when you tap "Find someone").

### Room flows (all roads end in `ChatRoomScreen`)

```
Home ─┬─ New room          → CreateRoomScreen  ─┐
      ├─ Join with code    → JoinRoomScreen    ─┤
      ├─ Browse rooms      → ExistingRoomsScreen ─┼→ ChatRoomScreen ⇄ RoomInfoSheet
      ├─ Conversation tile ───────────────────────┤      │
      └─ Request banner    → RequestsScreen ──────┘      └→ MediaViewerScreen
Search ── tap a person ── SocialService.startChat() ──→ ChatRoomScreen (shared direct room)
RequestsScreen ── accept a chat request ──→ ChatRoomScreen (the same shared room)
Profile ─┬─ Chat requests → RequestsScreen
         ├─ Groups        → GroupsScreen ──→ ChatRoomScreen
         └─ Push row      → PushService.enable()
Invite URL (?room= / ?join= / ?code= / /join/<code>, cold start) → RoomInviteScreen → ChatRoomScreen
Push notification tap  → PushService._openWhenReady → ChatRoomScreen | RequestsScreen | SessionGate
```

Invite reading is `RoomLinkService.codeFromCurrentUrl()`: it accepts `room`,
`join` and `code` from the query, the fragment or the last path segment, and only
accepts a **six-character room code**. A push click carries a room *id*, not a
code, so a warm web app stays on Home — see `supabase/PUSH.md` §6.

### Where each piece of state lives (and how long it lives)

| State | Owner | Lifetime / notes |
|---|---|---|
| Selected tab | `_AppShellState._tab` | while signed in; Home is the default |
| Tab contents | `IndexedStack` in `app-shell.dart` | screens stay mounted, so scroll position and lists survive tab switches |
| Theme mode | `themeController` (`lib/theme/theme-controller.dart`) | global `ChangeNotifier`, persisted in `SharedPreferences`, listened to in `main.dart` |
| Push status (`PushState.off/ready/denied/unavailable`) | `PushService.state` (`ValueNotifier`) | process; the Profile → Push notifications row listens to it |
| Back interceptors | `BackCoordinator` stack (`lib/common/back/`) | registered by the screen that is mounted; released in `dispose()` |
| Session | Supabase SDK | persisted by the SDK; `AuthService` is a thin read-only wrapper |
| Profiles / rooms / messages | each screen's own `_load()` + `setState` | per screen instance; every list has RETRY + empty and error states |
| Invite code from a link | `RoomLinkService` (`lib/data/room-link-service.dart`) | parsed once, held by `SessionGate` until consumed |

No global store, no provider package: screens load, hold and refresh their own
data, and `PushService` / `ThemeController` are the only process-wide singletons.


---

## Who depends on whom — the full wiring

Five rules explain almost every import in the project:

1. **Screens → services → models.** UI calls a `lib/data/*` class; nothing in
   `lib/data/` builds widgets.
2. **One documented exception:** `push-service.dart` imports screens
   (`chat-room-screen`, `requests-screen`, `session-gate`) because a notification
   tap has to navigate. That import is the price of deep-linking.
3. **`models.dart`, `social-models.dart`, `room-link-service.dart`,
   `format.dart` have no project imports** — pure data/pure functions, which is
   why they are the easiest things to unit-test (see `test/`).
4. **Everything visual reads `theme/app-theme.dart`.** No screen hard-codes a
   colour except `landing-screen.dart`, which deliberately ships its own
   marketing palette (`_C`) and type scale (`_T`).
5. **`data/` owns Supabase, `media/` owns files.** Uploads go through
   `media-service.dart` → `chat-service.sendMedia`, never straight to storage
   from a widget.

### Boot, root and back button

| From | → Depends on | Reason / feature |
|---|---|---|
| `main.dart` | `supabase-config.dart` | URL + anon key, `isSupabaseConfigured` |
| `main.dart` | `session-gate.dart` | the single routing decision after auth |
| `main.dart` | `setup-required-screen.dart` | shown instead of the gate when config is missing |
| `main.dart` | `app-exit-guard.dart` | root `PopScope` = the app never dies on back |
| `main.dart` | `push-service.dart` | `firebase_messaging` background handler + `boot()` |
| `main.dart` | `theme/app-theme.dart`, `theme-controller.dart` | ThemeData pair + persisted mode |
| `app-exit-guard.dart` | `back/back-coordinator.dart` | forwards presses to the interceptor stack |
| `back-coordinator.dart` | `theme/app-theme.dart` | the "Leave ChatMate?" dialog styling |
| `session-gate.dart` | `auth-service.dart`, `profile-service.dart` | is there a session? is there a handle? is it an admin? |
| `session-gate.dart` | `room-link-service.dart` | invite code from `Uri.base` (`?room=`, `?join=`, `?code=`, `/join/<code>`) |
| `session-gate.dart` | `landing`, `create-id`, `app-shell`, `admin/dashboard`, `room-invite` | the five destinations |
| `app-shell.dart` | `back/back-coordinator.dart` | claims back → switch to Home tab |
| `app-shell.dart` | `push-service.dart` | `maybePrompt()` after the first frame |
| `app-shell.dart` | `home-screen`, `profile-screen`, `search-screen` | the three tabs |
| `landing-screen.dart` | `create-id-screen.dart` | every CTA ends in "make an ID" |

### Signed-in screens (who pulls in what, and why)

| From | → Depends on | Reason / feature |
|---|---|---|
| `home-screen` | `social-service`, `social-models` | conversation list, pending requests |
| `home-screen` | `room-service`, `models` | "new room / join / browse" entry cards |
| `home-screen` | `profile-service` | greeting + own handle |
| `home-screen` | `app-shell` | `AppShell.open(context, AppTab.search)` from the empty state and "Find someone" |
| `home-screen` | `chat-room`, `create-room`, `join-room`, `existing-rooms`, `requests` | every navigation target |
| `search-screen` | `social-service`, `social-models` | `searchProfiles` + `startChat` |
| `search-screen` | `mate-avatar`, `chat-room` | result avatar, open the resulting chat |
| `profile-screen` | `profile-service`, `models` (`Profile`) | own row, change handle |
| `profile-screen` | `social-service`, `social-models` | request count + joined group count |
| `profile-screen` | `push-service` | the Push notifications row (`enable()` / status) |
| `profile-screen` | `groups-screen`, `requests-screen` | the two ACCOUNT rows |
| `chat-room-screen` | `chat-service` | messages, send/sendMedia/delete/markRead/seen |
| `chat-room-screen` | `room-service`, `models` | room header, members, join mode |
| `chat-room-screen` | `social-service`, `social-models` | reactions: `react` + `messageReactors` (who reacted) |
| `chat-room-screen` | `auth-service` | own user id → which bubble is "mine" |
| `chat-room-screen` | `room-info-sheet` | the info panel |
| `chat-room-screen` | all 10 `media/*` files | attach, preview, render, view, GIF/sticker pickers |
| `chat-room-screen` | `link-text`, `mate-avatar`, `swipe-to-reply`, `format` | linkifying, avatars, reply gesture, timestamps |
| `room-info-sheet` | `supabase_flutter` (`RealtimeChannel`) | live member list while the sheet is open |
| `room-info-sheet` | `room-service`, `social-service` | members, invites, identity mode |
| `room-info-sheet` | `room-link-service` | copy/share the invite link |
| `room-info-sheet` | `profile-service` (handle helpers), `models`, `errors` | validate typed handles when inviting, error copy |
| `requests-screen` | `social-service`, `social-models` | chat requests in/out |
| `requests-screen` | `room-service`, `models` | room join requests |
| `requests-screen` | `chat-room-screen` | accept → open the direct room |
| `groups-screen` | `room-service`, `models` | joined rooms only |
| `groups-screen` | `create-room`, `join-room`, `chat-room` | the three actions on the tab |
| `create-room-screen` | `room-service`, `profile-service`, `models` | create the room, invite people by handle (`normalizeHandle` + `search`), then open it |
| `join-room-screen` | `room-service`, `models` | `searchRooms` → `joinRoomByCode` / `requestJoin` → open |
| `existing-rooms-screen` | `room-service`, `models` | public room search |
| `room-invite-screen` | `room-service`, `models` | preview + join the invited room |
| `room-invite-screen` | `chat-room-screen`, `app-shell` | open the room, then fall back into the shell |
| all of the above | `errors.dart` | `describeError()` → readable SnackBar/empty-state text |


### Admin screens

| From | → Depends on | Reason / feature |
|---|---|---|
| `admin-login-screen` | `auth-service`, `errors` | email/password sign-in, refuses non-admins |
| `admin-login-screen` | `dashboard-screen` | success → replace route with the dashboard |
| `dashboard-screen` | `admin-service` | counters, room/user lists |
| `dashboard-screen` | `push-service` | **sign-out deletes this device's token before the session dies** (RLS would block it afterwards) |
| `dashboard-screen` | `auth-service`, `landing-screen` | sign out → back to the public landing |
| `dashboard-screen` | `admin-rooms-screen`, `admin-users-screen` | the two admin lists |
| `admin-rooms-screen` | `admin-service`, `admin-room-details-screen` | list → one room |
| `admin-rooms-screen`, `admin-users-screen`, `admin-room-details-screen` | `models` (`AdminRoom*`, `AdminUser`), `format`, `errors` | rows, timestamps, errors |

### Data layer and media (no UI imports, except push)

| From | → Depends on | Reason / feature |
|---|---|---|
| `auth-service.dart` | nothing (Supabase SDK) | the only owner of the session |
| `profile-service.dart` | `auth-service`, `models` | "my profile", create/change handle |
| `room-service.dart` | `auth-service`, `models` | every room + membership RPC |
| `chat-service.dart` | `auth-service`, `models`, `media-service` | message RPCs; media path + size validation before insert |
| `social-service.dart` | `auth-service`, `social-models` | conversations, requests, **device-token register/remove** |
| `admin-service.dart` | `auth-service`, `models` | `admin_*` RPCs |
| `room-link-service.dart` | nothing | pure build/parse of `/join/<code>` |
| `push-service.dart` | `auth-service` | is there a uid to attach the token to? |
| `push-service.dart` | `social-service` | `registerDeviceToken` / `removeDeviceToken` |
| `push-service.dart` | `profile-service` | only notify users who finished onboarding |
| `push-service.dart` | `firebase_options.dart` | platform FCM options |
| `push-service.dart` | `chat-room-screen`, `requests-screen`, `session-gate` | tap → `type` decides the screen (the one UI import in `data/`) |
| `media-service.dart` | `auth-service`, `media-catalog` | who is uploading, what is allowed |
| `giphy-service.dart` | `media-catalog`, `media-service` | catalogue entries + shared HTTP/error helper |
| `media-prefs.dart` | `giphy-service`, `media-catalog` | remembers the last picker state |
| `media-actions.dart` | `media-service` | signed URL → save/share |
| `media-bubble-content.dart` | `models`, `media-catalog`, `media-viewer-screen` | renders a message's media, tap → viewer |
| `media-viewer-screen.dart` | `models`, `media-actions`, `format` | fullscreen + save/share/close |
| `media-preview-sheet.dart` | `media-service`, `media-catalog`, `errors` | trim/compress/caption before upload |
| `gif-picker-sheet`, `sticker-picker-sheet`, `media-attach-sheet` | `media-prefs`, `media-catalog`, `giphy-service` | the three pickers in the composer |

### Reverse map — "if I touch this file, what breaks?"

| File | Directly used by |
|---|---|
| `data/models.dart` | `profile`, `home`, `chat-room`, `room-info-sheet`, `requests`, `groups`, `create-room`, `join-room`, `existing-rooms`, `room-invite`, `admin-users`, `admin-rooms`, `admin-room-details`, `chat-service`, `room-service`, `profile-service`, `admin-service`, `media-bubble`, `media-viewer` |
| `data/social-models.dart` | `home`, `search`, `profile`, `chat-room`, `requests`, `groups`, `social-service` |
| `data/auth-service.dart` | `session-gate`, `create-id`, `chat-room`, `room-info-sheet`, `dashboard`, `admin-login`, `profile-service`, `room-service`, `chat-service`, `social-service`, `admin-service`, `push-service`, `media-service` |
| `data/profile-service.dart` | `session-gate`, `create-id`, `home`, `profile`, `create-room`, `room-info-sheet`, `push-service` |
| `data/push-service.dart` | `main`, `app-shell`, `create-id`, `profile`, `dashboard` |
| `theme/app-theme.dart` | every screen and widget **except** `landing-screen.dart` |
| `theme/theme-controller.dart` | `main`, `theme-toggle-button` |
| `common/back/back-coordinator.dart` | `main` (via `AppExitGuard`), `app-shell` |
| `common/widgets/mate-avatar.dart` | `home`, `search`, `profile`, `chat-room`, `requests`, `groups` |
| `common/utils/format.dart` | `chat-room`, `home`, `groups`, `requests`, `existing-rooms`, `admin-rooms`, `admin-room-details`, `admin-users`, `media-viewer` |
| `common/widgets/link-text.dart` | `chat-room-screen` only |
| `common/widgets/swipe-to-reply.dart` | `chat-room-screen` only |
| `errors.dart` | every screen in `common/screens`, `users/screens`, `admin/screens`, plus `media-preview-sheet` |


### The push chain, file by file

| Step | Lives in |
|---|---|
| A row lands in `messages` / `chat_requests` | `supabase/0005_v2_social.sql` (triggers) |
| The trigger writes a `push_queue` row (sender never notified) | `supabase/0005_v2_social.sql` |
| `pg_cron` every **20 seconds** runs `trigger_push_flush()` → `net.http_post` | `0005` cron job + vault `push_url` / `push_secret` |
| The function drains the queue, mints an OAuth token from `FIREBASE_SERVICE_ACCOUNT` | `supabase/functions/push/index.ts` |
| FCM HTTP v1 → APNs / Web Push | Google, plus `firebase_options.dart` for the app ids |
| The device token came from here | `push-service.syncToken()` → `social-service.registerDeviceToken()` → `device_tokens` |
| Foreground: in-app SnackBar with **OPEN** | `push-service.dart` |
| Background display | Android: `MainActivity.kt` channel · iOS: `Runner*.entitlements` + APNs key · Web: `web/firebase-messaging-sw.js` |
| Tap → screen | `push-service._route()`: `chat_request`/`room_request*` → `RequestsScreen`, `chat_accepted` with room → `ChatRoomScreen`, otherwise `ChatRoomScreen` / `SessionGate` |
| "Why is nothing arriving?" | `select * from public.push_health();` (`supabase/0006_push_diagnostics.sql`) |

### Adding something — the files you actually touch

| I want to… | Edit |
|---|---|
| add a screen | new file in `lib/users/screens/`, `AppTheme`/`AppText` only, `describeError()` for failures, then link it from `home-screen` or `app-shell` |
| add a tab | `AppTab` + `IndexedStack` + `_BottomBar` in `lib/common/screens/app-shell.dart` |
| add a backend call | a static method in the matching `lib/data/*-service.dart` + a model in `models.dart` (or `social-models.dart`) |
| change a database rule | a **new** numbered file `supabase/0007_*.sql`; never edit an applied one |
| add a notification type | trigger in a new SQL file → `type` string → one `case` in `push-service._route()` |
| add a media kind | `media-catalog.dart` (limits + label) → `media-service.dart` (upload) → `media-bubble-content.dart` (render) → `0007_*.sql` bucket policy if the size limit changes |
| change the palette | `lib/theme/app-theme.dart` (and only there, unless it is the landing page) |
| change the exit dialog | `lib/common/back/back-coordinator.dart` — nothing else may call `SystemNavigator.pop()` |

