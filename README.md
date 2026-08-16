# lovit

A private, realtime couples app built with **Flutter** and **Supabase**.

Lovit gives partners a shared space for chat (end-to-end encrypted), a shared
calendar & period tracker, tasks, budgets, cycle tracking, location sharing,
voice notes, and video calls.

## Features

- **Chat** — realtime 1:1 messaging with reactions, edits, unsend, pinned
  messages, voice notes, media, and a customizable background (preset colors or
  a custom image).
- **Calendar** — shared events and period/cycle tracking synced between
  partners across timezones (all timestamps stored UTC).
- **Budget** — shared monthly expense tracker.
- **Tasks** — shared to-dos.
- **Maps** — realtime location sharing with an explicit opt-out.
- **Presence & battery** — partner online status and battery level synced in
  the background (including a background sync service).
- **Video calls** — in-app Jitsi meet rooms.
- **Pairing** — QR-code based pairing flow, enforced server-side.

## Tech Stack

- **Frontend**: Flutter (Dart 3.11+), Riverpod, `supabase_flutter`,
  `go_router`, `flutter_map`, `jitsi_meet_flutter_sdk`, FCM +
  `flutter_local_notifications`, `workmanager` background sync.
- **Backend**: Supabase (PostgreSQL + Realtime + Edge Functions + Storage).
- **Crypto**: `cryptography` — X25519 key exchange + AES-256-GCM for message
  content (see [Security](#security)).

## Project Layout

```
lib/
  main.dart                 App entry, auth listener, HomeShell + navigation
  core/                     Supabase credentials & shared constants
  models/                   Data models (cycle, chat, calendar)
  screens/                  Chat, calendar, home, budget, maps, pairing, ...
  services/                 SupabaseService, sync + notification + encryption
  theme/                    Theme presets & theme selector (theme.dart,
                            theme_selector.dart, index.dart)
  widgets/                  Shared widgets (message bubble, etc.)
supabase/
  migrations/               SQL schema + RLS policies + realtime publications
  functions/send-notification/  Edge function (push notifications)
assets/
  images/                   App art
  memories/                 User memories media
test/                       Unit tests
```

## Getting Started

1. **Dependencies**

   ```sh
   flutter pub get
   ```

2. **Supabase configuration**

   - Create a Supabase project and apply the migrations under
     `supabase/migrations/` (e.g. `supabase db push`).
   - Set your project URL and anon key in
     `lib/core/constants/supabase_constants.dart`.
   - **Enable Realtime for the tables that need it.** Realtime is opt-in per
     table — adding a table to the schema is not enough. The `pairings`,
     `budget_transactions`, and `cycle_tracking` tables must be added to the
     realtime publication (`enable_realtime_for_budget_and_cycles.sql` and the
     pairing-fixes migration do this). Real-time subscriptions silently fail
     for tables that are not published.
   - Deploy the `send-notification` edge function:
     ```sh
     supabase functions deploy send-notification
     ```
   - Configure Firebase/FCM for push notifications on each platform.

3. **Firebase config (Android)**

   `android/app/google-services.json` is **git-ignored** because it contains a
   Google API key (SEC-16). To build the Android app you must have a real file
   on disk:

   ```sh
   cp android/app/google-services.json.example android/app/google-services.json
   ```

   then fill it in with values from your own Firebase project (Console →
   *Project settings → Your apps → Android app*, matching the `applicationId`).
   The Google services Gradle plugin fails the build if the real file is
   missing, so anyone cloning the repo must provide their own.

   The app's application ID is **`com.lovit.app`** (Android `applicationId` and
   iOS bundle identifier — no longer the `com.example` placeholder, SEC-16b).
   When you first set up or regenerate the Firebase config for this package:

   - **Project settings → Your apps → Android app → Add app** with the package
     name `com.lovit.app` (add your signing certificate's **SHA-1** for
     fingerprint verification), download the new `google-services.json` and
     replace the local file.
   - **Project settings → API keys** → restrict the Android key to
     **Android apps: `com.lovit.app`** (+ your SHA-1). The key ships inside
     every APK, so restriction is what makes it useless if extracted.
   - If the key was ever exposed (it was committed to git history before
     SEC-16), **regenerate** it in the console.

4. **Run**

   ```sh
   flutter run
   ```

5. **Verify**

   ```sh
   dart analyze
   flutter test
   ```

## Security

- Client apps use only the anon key; all privileged operations go through RLS
  policies and SECURITY DEFINER RPCs (e.g. `join_pairing`, which atomically
  claims a pending pairing after validating code expiry and status).
- Storage buckets (`avatars`, `messages`, `memories`) are **private** (SEC-14):
  uploads are scoped to path conventions (`<user id>/`, `<pairing id>/`) and
  reads require auth as the owner / pairing member. The client stores storage
  paths and resolves short-lived signed URLs at display time (legacy public
  URLs already in the DB are re-signed transparently).
- Push notifications are sent via the `send-notification` edge function, which
  verifies the caller's JWT, rejects sends without an active pairing, validates
  UUIDs before building filters, and rate-limits. Notification bodies never
  echo message content, and failures return generic errors while details are
  logged server-side (SEC-18).
- FCM push tokens are device secrets and never appear on the partner-readable
  `profiles` row: they live in a private `push_tokens` table that only the
  owner can write and only the edge function (service role) can read (SEC-17).

### End-to-End Encryption (messages)

Message content is end-to-end encrypted in transit and at rest:

- Each device generates an **X25519** key pair on login; the private half lives
  only in platform secure storage (Android Keystore / iOS Keychain via
  `flutter_secure_storage`) and never leaves the device (SEC-15). Keys written
  to the pre-SEC-15 plaintext `SharedPreferences` location are migrated into
  secure storage on first load. The public half is published to the user's
  profile (`preferences.e2ee_pubkey`).
- For a pairing, the **AES-256-GCM** key is derived via ECDH(own private key,
  partner public key) → HKDF-SHA256, so both partners derive the same key and
  the server only ever sees ciphertext.
- Ciphertext uses the envelope `lv1:<nonce>.<ciphertext>.<mac>`; legacy
  plaintext messages pass through unchanged (safe migration).
- **Metadata stays plaintext** because threads, polls, and pins rely on JSONB
  queries and merge-updates.

**Known limitations:** encryption engages once both partners have published
keys; messages sent before then remain legacy plaintext, and rotating a device
key would make older history unreadable. To detect a swapped public key
(MITM), partners compare the key fingerprints shown in **Settings →
Encryption** (SEC-15b).

## Background Sync

- Battery and location sync services run in the background via `workmanager`.
- Background runs restore the session from the stored auth token
  (`SupabaseService.restoreBackgroundSession()`).
- Location sharing is never force-enabled: a user who opts out stays opted out,
  and opting out clears stored coordinates.

## Theme System

Users customize the chat background with a preset color or a custom image.

- `lib/theme/theme.dart` — `ThemePresets` (32 curated colors in 9 categories),
  `ThemeColor` model, and `IGDesignTokens` (design consistency tokens).
- `lib/theme/theme_selector.dart` — `ThemeSelectorPage` with live preview,
  categorized color grid, and image selection.
- Persisted in `SharedPreferences` (`bg_color`, `bg_image_path`).

## Navigation

`HomeShell` (`lib/main.dart`) hosts a 5-page `PageView`:

```
0. HomeScreen       1. BudgetScreen   2. ChatLogScreen
3. CalendarScreen   4. MapsScreen
```

All tabs and home-screen shortcuts route through a single `_navigateToPage()`
(320 ms, `easeInOut`). Chat threads push a separate `ChatScreen` route.
Navigation is gated in release builds (`/debug` route is kDebugMode-only).

## Testing

- `test/cycle_models_test.dart` — 7 unit tests over calendar-date
  normalization and cycle info (period/fertile-day boundaries, cycle wrapping).
- `test/encryption_service_test.dart` — 5 unit tests over the E2EE round trip,
  legacy passthrough, and key derivation.

## Resolution History

Security, performance, correctness, and hygiene issues are tracked here in
condensed form (details resolved in code + migrations):

| ID | Issue | Resolution |
|----|-------|-----------|
| SEC-01 | `send-notification` open endpoint | JWT auth, pairing check, UUID validation, rate limit |
| SEC-02 | Pairing join via permissive RLS | `join_pairing` SECURITY DEFINER RPC |
| SEC-03 | Storage buckets writable by anyone | Path-scoped bucket policies |
| SEC-04 | Location sharing re-enabled on sync | Never force-enable; honor opt-out |
| SEC-05 | Partner could edit/delete anything | Sender-scoped message/cycle RLS |
| SEC-06 | Pre-made active pairings allowed | Insert constrained to pending, self-created |
| SEC-07 | Old coordinates persisted after opt-out | Trigger nullifies location on opt-out |
| SEC-08 | Predictable pairing codes | `Random.secure()` codes |
| SEC-09 | Debug surface in release builds | kDebugMode-gated route + no anon login |
| SEC-10 | Predictable Jitsi room names | Random nonce in room name |
| SEC-11 | Stale pairing cache resurrection | Authoritative null clears cache |
| SEC-12 | Partner FCM token readable | Superseded by SEC-17 |
| SEC-13 | No E2EE despite UI claims | Real X25519 + AES-256-GCM E2EE + honest copy |
| SEC-14 | Public media buckets (anyone with URL) | Buckets private, auth-scoped reads, signed URLs |
| SEC-15 | E2EE key in plaintext SharedPreferences | Secure storage + legacy migration |
| SEC-15b | No MITM detection | Public-key fingerprint comparison in Settings |
| SEC-16 | Firebase API key committed to git | google-services.json ignored + template + docs |
| SEC-16b | Placeholder `com.example.lovit` applicationId | Renamed to `com.lovit.app` (Android + iOS) |
| SEC-17 | Partner FCM token readable (SEC-12) | Token moved to private `push_tokens` table; owner-write, service-read |
| SEC-18 | Edge function leaks internal errors | Generic responses; details logged server-side |
| PERF-01 | N+1 reaction subscriptions | Single `watchAllReactions()` stream |
| PERF-02 | Cache writes on every event | 2s throttled cache write |
| PERF-03 | Read-marking write amplification | RPC only when unread messages present |
| PERF-04 | Leaked subscriptions/timers/channels | Ref-counted typing channels, disposed timers |
| PERF-05 | GlobalKey churn in message list | Stable per-message keys |
| PERF-06 | Duplicate realtime channel | Removed duplicate subscription |
| PERF-07 | Duplicate connectivity listener | Lazily attached once |
| PERF-08 | Extra SELECT per profile write | In-memory row-exists flag |
| BUG-01 | Background sync without session | Session restore in sync services |
| BUG-02 | setState after dispose | `mounted` guards after awaits |
| BUG-03 | Pending messages rendered at top | Prepend to newest-first list |
| BUG-04 | Stale profile cache clobbered DB | Rethrow errors; no stale write-back |
| BUG-05 | Expired/claimed codes accepted | Server-authoritative join RPC |
| BUG-06 | Presence stuck offline | Serialized presence writes |
| BUG-07 | Local-time timestamps persisted | All writes normalized to UTC |
| BUG-08 | `is_shared` heuristic always true | Written explicitly as true |
| BUG-09 | Typing listener bound to stale pairing | Rebinds on pairing change |
| BUG-10 | Reaction toggle races | Per-message in-flight guard |
| BUG-11 | Notifications generation race | `.limit(200)` + generation counter |
| BUG-12 | Toast overlay race | Identity-checked removal |
| BUG-13 | Dead code on every event | Removed unused fields/subscriptions |
| BUG-14 | Debug join test could never succeed | Prompts for a pairing code instead |
| BUG-15 | UTC-ambiguous calendar events | UTC-normalized storage + local display |
| HYG-01 | Placeholder test suite | Real unit tests (7) |
| HYG-02 | Template README | This document |
| HYG-03 | Missing `assets/memories/` | Directory created |
| HYG-04 | Zero-byte dead files | Deleted |
| HYG-05 | Silent catch-and-ignore errors | Rethrow/surface via toasts |
