## [1.13.4] - 2026-09-21
* * Demo account mapping: Added customer@demo.rokct.ai -> customer, set Thandi demo account role to student with default grade: 12.

## 1.13.3

* Fixed (through base_sdk 1.66.8): the login screen showed "Something went
  wrong with the server" for a backend that simply was not answering. Ray,
  2026-09-20: "something went wrong with server is stll showing in splash/
  login screen" - on a phone the login page draws the splash artwork
  full-bleed, so the two read as one screen, and the toast is the login
  page's: `LoginNotifier.checkLanguage` runs from its first post-frame
  callback with no user action, on every open, in BOTH of its branches.
  With a network present the radio guard passes, the language-catalogue
  fetch is attempted, and the failure branch calls
  `AuthErrorPresenter.showTechnical`, which discarded the honest "we
  couldn't reach the server" line the failure already carried and painted
  the generic fallback instead. No auth_sdk code changed; the fix is in the
  presenter this SDK's thin `AuthErrorPresenter` alias delegates to, and in
  `AppHelpers.getTranslation`'s bundled-copy lookup for a device that has
  not chosen a language yet - which is every first-run entry, and the only
  state this screen can be in while the backend is unreachable.
* New: `auth_unreachable_toast_test.dart` - 5 tests over the exact presenter
  call `login_notifier.dart` makes when the language or translation fetch
  fails, with the failure string and status built the way
  `SettingsRepository.getLanguages` builds them. `LoginNotifier` itself
  cannot be constructed in a standalone auth_sdk test (it reaches
  `OfflineAuthService`, whose drift accessors exist only after a host app
  has run build_runner over its composed `AppDatabase`), which is
  pre-existing and is noted in the test's header.
* auth_sdk 1.13.3 requires base_sdk >= 1.66.8 for the presenter fix; on an
  older base_sdk the code still compiles and behaves as it did, the login
  toast just keeps the vague wording.

## 1.13.2

* Fixed: four auth sheets — the OTP confirmation sheet
  (`RegisterConfirmationPage`), the phone-verify sheet (`PhoneVerify`), the
  reset-password sheet (`ResetPasswordPage`) and the set-password sheet
  (`SetPasswordPage`) — now follow a theme-mode flip while they stay open,
  instead of keeping the previous mode's colours until the sheet is closed
  and opened again. Each `build` decided its sheet background, its
  instruction copy, the phone field's ink or the confirm button's idle fill
  from `AppStyle.surfaceDark` / `AppStyle.textDarkSecondary` /
  `AppStyle.textPrimary` — mode-resolving statics, not inherited widgets —
  and the only things they read from the `BuildContext` were
  `MediaQuery.of(context).viewInsets` and `MediaQuery.paddingOf(context)`,
  neither of which changes on a theme flip, so the flip scheduled no rebuild
  of the element. The feature notifiers they watch
  (`registerConfirmationProvider`, `registerProvider`,
  `resetPasswordProvider`) are never notified by a theme-mode change, so they
  are no rebuild trigger either, and every in-repo mount site hands the sheet
  either a `const` instance or one captured value, so a parent rebuild cannot
  deliver the flip. Each build now reads `Theme.of(context).brightness` once,
  outside every inner builder, and names its colours through base_sdk's
  `AppStyle.surfaceFor` / `AppStyle.secondaryInkFor` / `AppStyle.inkFor` role
  helpers — the same seam the registration steps page, the shared glance card
  and the profile footer use. No colour value changed in either mode, and no
  helper was added to base_sdk.
* `SetPasswordPage` now imports `reset_password_provider.dart` directly
  instead of the `auth.dart` barrel. The barrel also exports the
  register-confirmation provider, which drags `OfflineAuthService` into the
  library, and that service's drift accessors exist only after the composer
  has injected auth_sdk's `OfflineUsersTable` into base_sdk's
  `@DriftDatabase` — so the barrel is what made this page impossible to mount
  in a widget test. The sheet only ever used `resetPasswordProvider`.
  `set_password_theme_mode_test.dart` mounts the sheet behind a `const` child
  boundary, flips `AppStyle.setBrightness` plus the Material `themeMode` the
  way `AppNotifier.changeTheme` does, and pumps without remounting.
  `auth_sheet_theme_mode_guard_test.dart` covers the other three on the
  source instead: they reach `OfflineAuthService` through the confirmation
  sheet they push, so no test in this package can import them at all yet.

## 1.13.1

* Fixed: the post-registration steps pipeline
  (`RegistrationStepsPage`) restyles itself the moment the theme mode
  changes, instead of keeping the previous mode's colours until the page is
  built again from scratch. Its `build` decided the Scaffold surface, the
  brand glow's fade-out stop and the `n/m` progress label from
  `AppStyle.surfaceDark` / `AppStyle.textDarkSecondary` — mode-resolving
  statics, not inherited widgets — and read nothing else from the
  `BuildContext`, so a mode flip scheduled no rebuild of the element.
  `RegistrationStepsPage` reads nothing from the context either, so the flip
  could not reach the state through a parent rebuild. The build now reads
  `Theme.of(context).brightness` once and names its colours through
  base_sdk's `AppStyle.surfaceFor` / `AppStyle.secondaryInkFor` role
  helpers, the same seam the shared glance card and profile footer use. No
  colour value changed in either mode. `manifest.json` also catches up to
  the pubspec version, which it had drifted behind at 1.12.1, and declares
  the new floor: both helpers arrived in base_sdk 1.66.4, so this release
  requires base_sdk >= 1.66.4.

## 1.13.0

* Fixed: recognized demo accounts can now authenticate locally even when the device is offline or the backend is completely unreachable.
  Added `MockAuthRepository.isDemoAccount(email)` to check if entered credentials match the SDK's recognized demo account source of truth.
  `LoginNotifier.login()` now checks `MockAuthRepository.isDemoAccount(state.email)` before invoking `AppConnectivity` or `AuthRepository.login()`,
  authenticating recognized demo accounts through `MockAuthRepository` and establishing full local sessions via `_establishSession()` without
  invoking backend services or requiring network connectivity. Arbitrary credentials continue to be sent through standard backend/offline registration pathways.

## 1.12.1

* Build fix: `auth_di.dart` read `AppConstants.isDemo`, which base_sdk
  removed with the `--dart-define=IS_DEMO=true` define, so every composed
  app failed to compile (`The getter 'isDemo' isn't defined for the type
  'AppConstants'`). The `MockAuthRepository` / `AuthRepository` selection now
  reads `AppConstants.isTour`, the one compile-time flag base_sdk still has
  and the one build with no backend and no sign-in to assert the
  demo-account marker with. This is deliberately NOT
  `DemoSession.demoActive`: a demo account is a real account on the
  production backend and must sign in through the real `AuthRepository` to
  receive its marker, so the mock twin stays compile-time gated and can
  never be selected at runtime. `demo_account_test.dart` pins the new
  constant in place of the removed one.

## 1.12.0

* Demo login in production, phase 2 (auth side): the `auth.register`
  outbox handler follows the runtime demo session. `auth_di.dart` now
  registers `DemoHoldSyncHandler(AuthSyncHandler())` (new
  `lib/src/common/infrastructure/services/demo_hold_sync_handler.dart`):
  the hold reads `DemoSession.demoActive` (base_sdk 1.61.0) on every push
  and, while a demo session is active - or in a demo build - answers
  `SyncResult.retryable` (`DemoHoldSyncHandler.sessionHoldError`, worded
  so a sync status surface never names the demo) without handing the op
  to `AuthSyncHandler` at all: no local account row is read, the auth
  repository is never touched. The op stays queued, and the first drain
  after the session ends pushes it: every sign-out path ends in
  `LocalStorage.logout()`, which clears the session, and the engine is
  kicked at boot and on connectivity regain. Read per push, so the
  handler the DI attaches once needs no re-registration. The engine
  offers no hold verdict, so a held op counts an attempt and backs off
  like a transient failure; a demo session sees a kick or two, never the
  ten that park an op (a first-class hold in the engine is the core
  follow-up). `AuthSyncHandler` itself is unchanged.
* Not part of the switch, on purpose: `AuthRepositoryFacade` stays on the
  compile-time `AppConstants.isDemo` in `auth_di.dart`. A demo account
  signs in through the real backend like anyone else, so
  `MockAuthRepository` must never be selected at runtime; the phase-1
  guard in `test/demo_account_test.dart` (one `MockAuthRepository()` on
  the `AppConstants.isDemo` line, no `DemoSession` in the DI code) still
  holds and stays the rule. Nothing on screen changes, nothing rendered
  says demo, and nothing is keyed on a typed address or password.
* Tests: `test/auth_sync_handler_demo_session_test.dart` - through a fake
  inner handler (`AuthSyncHandler` reaches drift's generated
  offline_users table, which this package does not generate standalone):
  a real session pushes as before; an active demo session holds the op
  without reaching the handler; the hold lifts on `clear()`; a demo build
  holds too; `onSynced` passes through; the DI wraps the handler in the
  hold and only the handler; the held error carries no fixture wording
  and the hold never references the mock repository. Requires base_sdk
  1.61.0.

## 1.11.0

* Added: demo login in production (Ray 2026-09-08). The build-time
  `IS_DEMO` tour flag stays; on top of it, real accounts on the
  production backend - one per role: deliveryman, seller, admin - sign in
  through the real `AuthRepository` like anyone else, and only once the
  real backend has accepted the credentials does the app flip base_sdk's
  runtime `DemoSession` (base_sdk 1.61.0). `LoginNotifier
  ._establishSession` now calls the new `applyDemoAccountSession(user)`
  (`lib/src/common/services/demo_account_session.dart`) after it persists
  the accepted account: `DemoSession.instance.activate()` when the
  payload's user carries the backend's `is_demo_account` marker
  (`UserModel.isDemoAccount`), `clear()` for any other account - so a
  demo session left by an earlier sign-in can never leak into a real one.
  Sign-out clears it: every sign-out path ends in `LocalStorage.logout()`,
  which ends the demo session (base_sdk 1.61.0). `sessionProfileOf` lifts
  the marker into the stored session. Nothing is keyed on the typed
  address or the password, and nothing on screen changes or says demo:
  the login screen still renders no credentials hint (the 2026-08-22
  removal stands), `MockAuthRepository` and its address-to-role table
  stay behind the compile-time `AppConstants.isDemo` in `auth_di.dart`
  and are tree-shaken out of every release build.
* Phase 2 (SDK data wiring) follows: the per-SDK DI ternaries that read
  `AppConstants.isDemo` at registration move to `DemoSession.demoActive`
  and re-register on `DemoSession.instance.addListener`, which is what
  serves a demo session from the in-app fixtures and keeps demo actions
  away from real shops, drivers and payments. With only this release
  merged, a marked account signs in and is served exactly like any
  other: the flip changes nothing a user can see beyond the flag.
  Tests: `test/demo_account_session_test.dart` (the flip per role, no flip
  for a normal account, a normal sign-in ending an earlier demo session,
  sign-out clearing it, the stored session carrying the marker and no
  fixture wording); `test/demo_account_test.dart` gains the login-screen
  guard (no string literal reads demo / example / placeholder / sample,
  no `demoUserLogin` / `demoUserPassword` / `isDemo` in its code) and the
  `MockAuthRepository` compile-time-gate guard. Requires base_sdk 1.61.0.

## 1.10.4

* Demo sign-in hands back the demo identity's own email, never the typed
  address. `MockAuthRepository.login` returned `_demoUser.copyWith(email:
  email, ...)`: the address the tour types in (`{demo_email}` -
  `demo.student@example.com` where a shell sets none, `manager@` /
  `partner@` / `admin@demo.rokct.ai` where it does) came back as the
  account's email. Nothing rendered it while auth never persisted the
  login user, but since 1.10.3 `LoginNotifier._establishSession` stores
  that user, and users_sdk's `MockUserRepository.getProfileDetails`
  adopts the stored session's email and role - so supacharge's profile
  still (tour run 34040668065) read "demo.student@example.com" /
  "customer" under Thandi Mokoena instead of
  "thandi.mokoena@outlook.com". The typed address is a credential and a
  role selector only (`_demoRolesByEmail` is unchanged, so `manager@`
  still lands a seller): the account it signs in is always Thandi
  Mokoena, `thandi.mokoena@outlook.com`, `DemoImages.avatar` - the one
  identity users_sdk's demo profile serves - whatever was typed.
  `test/demo_account_test.dart` pins the identity email and that no
  field of the signed-in account reads "demo", "example", "sample" or
  "placeholder" for any tour address; `test/session_profile_test.dart`
  pins that the user the login flow persists for the supacharge tour's
  address carries the identity email, the kernel avatar and no fixture
  wording.

## 1.10.3

* The reset-password sheet's copy matches the app's sign-up type. Every
  variant read the email/link line ("Enter the email address for your
  account and we will send you a link..."), including the phone sign-up
  that shows a phone field and resets by SMS code. `ResetPasswordPage`
  now picks its key by `AppConstants.signUpType`: phone renders
  `TrKeys.resetPasswordPhoneText` (`reset_password_phone_text`, "Enter
  the phone number for your account and we will send you a code to reset
  your password."), both renders `TrKeys.resetPasswordEitherText`
  (`reset_password_either_text`, "...email address or phone number... a
  link or a code..."), and email keeps `TrKeys.resetPasswordText`. Both
  new rows are bundled in `kAuthEnTranslations` (registered by the
  existing `auth_en_bundled_translations` boot hook). The selection
  lives in new `reset_password_copy.dart` (`resetPasswordCopyKey`) so it
  can be pinned for all three types - the sheet itself only compiles
  inside a composed host, since its confirmation step reaches
  `OfflineAuthService` and the table the composer injects. Requires
  base_sdk >= 1.60.4 for the two TrKeys.
  `test/bundled_en_translations_test.dart` pins the rows; new
  `test/reset_password_copy_test.dart` pins the key per sign-up type and
  that the default (phone) copy never mentions email or a link.
* The account is persisted at login, so the profile header has a name and
  avatar on its first paint. base_sdk's `GenericProfilePage` renders
  `state.userData ?? LocalStorage.getUser()`, and only users_sdk's
  `ProfileNotifier.fetchUser` ever wrote the stored user - between
  sign-in and that fetch the header showed the empty "Profile" / "?"
  state. `LoginNotifier._establishSession` (every login variant) now
  stores the login response's user through new
  `lib/src/common/services/session_profile.dart` (`sessionProfileOf`),
  a one-to-one lift of `UserModel` into `ProfileData` (both base_sdk
  models of the same backend user document); profile-only fields
  (wallet, shop, membership) stay unset for the fetch to fill in.
  `MockAuthRepository` reuses the same lift for its verify responses.
  New `test/session_profile_test.dart` pins the mapping and the
  LocalStorage round trip for the demo sign-in.
* `MockAuthRepository` reads the demo avatar from base_sdk's
  `DemoImages.avatar` (new in base_sdk 1.60.4) instead of carrying its
  own copy of the inline SVG literal; users_sdk's `MockUserRepository`
  reads the same constant, so the two demo repositories can no longer
  drift apart.

## 1.10.2

* The reset-password sheet shows real copy instead of its translation
  key. `ResetPasswordPage` renders `TrKeys.resetPasswordText`
  (`reset_password_text`), and every app shell's guided tour captured it
  as the literal "Reset password text": base_sdk bundles no `en` map
  (English is meant to survive through `AppHelpers.humanizeTrKey`), which
  works for keys named after their copy (`reset_password` -> "Reset
  password") but not for a key that NAMES a string, and demo builds take
  their served map from comms_sdk's `MockSettingsRepository`, a handful of
  rows that never carried this key. New
  `lib/src/translations/auth_en_translations.dart` bundles the English
  row ("Enter the email address for your account and we will send you a
  link to reset your password."), and a new manifest `boot_hooks` entry
  (`auth_en_bundled_translations`, lms_sdk's `af` hook pattern) registers
  it into `BundledTranslations` at boot. Backend-served rows still win.
  The other 39 TrKeys this repository's SDKs render all humanize to their
  own copy, so the map carries this one key. New
  `test/bundled_en_translations_test.dart` guards the copy, that every
  bundled key is one this SDK renders, and the hook wiring.
* The demo account (`MockAuthRepository._demoUser`, what every
  `--dart-define=IS_DEMO=true` sign-in hands back) no longer reads like a
  fixture in the account stills. "Demo User" / `demo@example.com` /
  `+1234567890` / a `https://via.placeholder.com/150` avatar / "123 Demo
  St" in San Francisco became Thandi Mokoena - the seller commerce's demo
  shop already seeds - with `+27 82 456 7890`, "42 Marula Avenue, Sandton"
  (Sandton coordinates) and an inline-SVG initials avatar
  (`MockAuthRepository.demoAvatar`, a `data:` URI like base_sdk's
  `DemoImages`, so it renders offline and on the CI tour emulator; the
  placeholder host was a network fetch a demo build cannot make and drew
  the broken-image state). Display data only: `_demoRolesByEmail`, the
  per-shell `{demo_email}` sign-in and the password are untouched - the
  address still decides the role and `login` still returns the typed
  email. New `test/demo_account_test.dart` pins both.

## 1.10.1

* `LoginNotifier` no longer throws `Bad state: Tried to use LoginNotifier
  after 'dispose' was called` when a sign-in completes after the login
  screen has gone. `loginProvider` is `autoDispose`, and every login
  variant lands the user (`AuthSessionPolicy.onAuthenticated`) before its
  final `isLoading: false` write, so the navigation could dispose the
  notifier mid-flight and the write then hit a dead `StateNotifier`
  (seen on the paas_manager guided tour's phone leg right after
  `auth_reset_password`). Each post-`await` state write in `login`,
  `loginWithGoogle`, `loginWithFacebook`, `loginWithApple` and
  `checkLanguage` is now behind `if (!mounted) return;` (the
  `StateNotifier` idiom, as `IntroNotifier.restore` already does). Behaviour
  with the screen still mounted is unchanged; no public API changes.

## 1.10.0

* **auth_sdk no longer routes anyone to the UI-type picker.** base_sdk
  1.58.0 removes `/ui-type` - the screen that let a user pick a home style
  - so the six `isDemo ? replaceUiTypeRoute : goHome` landings here become
  a plain `goHome`: `AuthSessionPolicy.onAuthenticated`,
  `RegistrationFlow.defaultLanding`, the two `LoginPage` dynamic-link
  handlers, `ResetPasswordNotifier` and both `RegisterNotifier` success
  paths. Production sign-ins are unaffected (they already took the `goHome`
  branch); demo builds now land home instead of on the picker.
* The `replaceUiTypeRoute` declaration is dropped from the manifest's
  `app_routes`, so composed shells stop generating it. **Take this version
  before base_sdk 1.58.0** - 1.58.0 removes `AppRoutes.replaceUiTypeRoute`
  from the interface, and a shell still generating that method against the
  new interface will not analyze.
* One `RegisterNotifier` landing (the second success path) had an unbraced
  `if (isDemo) { ... } { ... }` that always fell through to `goHome`
  regardless of the flag; collapsing the branch removes that ambiguity too.

## 1.9.5

* `manifest.json` `app_routes` gains `pushLoginRoute` -> `context.router
  .push(LoginRoute())`. base_sdk's `AppRoutes` seam has declared
  `pushLoginRoute` all along and three customer-side callers use it
  (merchants_sdk shop page, products_sdk, marketplace_sdk: the "sign in to
  continue" prompts on screens the user returns to), but only
  `replaceLoginRoute` was ever filled, so the pushed variant fell through
  to `_UnsetAppRoutes.noSuchMethod` and threw a StateError in every
  customer composition. Same page, same wrapper (`LoginRouteView` in
  `auth_route_pages.dart`), pushed instead of replaced. Manifest-only
  (route map 2026-09-02, row 3). New `test/manifest_wiring_test.dart`
  (radio_sdk pattern) guards that every declared route has its
  `@RoutePage` shell in `templates/routes/` and that both login seams are
  declared and target a route this SDK ships.

## 1.9.1

* `LoginPage`: the guest Skip button now sits pinned in the top-end
  corner of the entry screen (design 25b — "skip is always at a
  corner"), a 16px logical inset from the edge. The header was a Row
  whose loose `Flexible` logo never claims its full flex allocation
  (the `FittedBox` shrinks it), so the Row's `Spacer`s left the
  unclaimed allocation as trailing free space and Skip floated ~170
  logical px inboard of the corner. Now a `Stack` with an
  `AlignmentDirectional.topEnd` child — directional, so RTL locales
  pin Skip to their end corner.

## 1.8.8

* `OfflineAuthService.registerOffline` resumes a pending (unsynced)
  local-first registration instead of failing it: a retried Register press
  for the same phone/email refreshes the existing row's details and
  returns the same row id (so the sync push keeps its idempotency key).
  Previously any existing row — including the one the previous offline
  attempt itself wrote — failed with "already exists", which made
  `register`/`registerWithPhone` skip their offline fallback and surface
  the generic "something went wrong with the server" line on every retry
  while the backend was down (driver Windows report, 2026-08-26). A row
  that already `synced` still fails as before — that account exists on
  the backend and the user should log in.
* `RegisterNotifier.register`/`registerWithPhone`: when the backend is
  unreachable (non-definitive status) AND the local-first write failed,
  show the local error's authored user copy instead of falling through to
  the generic server line — same surface `_completeOffline` already uses
  for a local failure.

## 1.8.5

* `MockAuthRepository._demoRolesByEmail` gains `driver@demo.rokct.ai` ->
  `deliveryman` and `manager@demo.rokct.ai` -> `seller`, so guided tours
  (and manual demo sign-ins) can enter the paas_driver and paas_manager
  compositions through their real login flows. The role strings are the
  exact values those apps' declared session policies admit
  (zones/delivery manifest `app_type.driver.session_policy`: deliveryman
  -> /home; commerce/merchants manifest
  `app_type.manager.session_policy`: seller -> /main). Additive only —
  the existing partner/admin mappings and the default customer role are
  unchanged.

## 1.8.3

* `AuthRepository` calls the registered composed aliases instead of
  unregistered paths that 404 on composed backends:
  `paas.api.user.user.login` -> `paas.api.user.login`; bare
  `paas.api.<fn>` -> `paas.api.user.<fn>` for
  `send_phone_verification_code`, `verify_phone_code`, `forgot_password`,
  `register_user` (x3), `forgot_password_confirm`, `login_with_google`;
  `paas.api.verify_my_email` -> `paas.tenant.api.verify_my_email` (the
  only registered name for that endpoint, in auth/frappe/manifest.json);
  and `paas.api.resend_verification_email` ->
  `paas.api.user.resend_verification_email` (consistency only — the short
  form is also registered). Completes the users_sdk alias fix (#20),
  which deliberately deferred this file behind #16.

## 1.8.2

Security release. (Versioned above main's 1.8.0 and the 1.8.1 claimed by
the in-flight AuthRepository alias-fix PR, Users #24.)

* **Random sync password** (`OfflineAuthService.syncOne`): the offline-sync
  push used to register the backend account with the local row id — a
  predictable epoch-microsecond timestamp — as its durable login password.
  It now sends a cryptographically random secret (32 bytes from
  `Random.secure()`, base64url, 256 bits — `generateSecurePassword` in
  `src/common/services/secure_password.dart`), generated once per row per
  app run and held in memory until the sync succeeds (so a retried push
  re-sends the same value), then discarded: post-sync access is OTP
  verification -> session token, and password login stays recoverable via
  the forgot-password flow.
* **Forced credential rotation** (`SessionPasswordRotation` +
  `OfflineAuthService.onDeferredVerificationCompleted` /
  `retryPendingPasswordRotations`): accounts synced by older releases still
  carry the guessable timestamp password on the backend. The moment a
  deferred account completes OTP verification and receives its first real
  session token, the client now calls the backend's session-scoped
  `update_password` with a fresh random secret (also discarded). Failures
  are non-fatal: a persisted pending flag is retried post-frame by
  `PendingOtpGate` on every boot and app resume, and never blocks login or
  verification. Accounts that BOTH synced AND verified under old releases
  are not client-identifiable (verification re-mints the session token, so
  the stored row token is stale) and are not rotated — see the PR for the
  declared limitation.
* **Honest deferred email resend**: `resendVerificationEmail` now sends
  `requireAuth: false`. The endpoint is allow_guest and identifies the
  account by the email parameter; previously the call presented the local
  `offline:<id>` placeholder as a Bearer credential and only worked because
  the backend's Bearer parser falls through to Guest on malformed tokens.
* Comment fixes: the offline row id is documented as a local-only
  epoch-derived identifier (it was mislabeled "local UUID"), never a
  credential.
* Rotation calls the registered composed alias
  `paas.api.user.update_password` (per the users/frappe manifest's
  whitelisted_methods), not the unregistered raw module path
  `paas.api.user.user.update_password` — same double-segment bug class
  Users #20/#24 fixed elsewhere.

## 1.8.0

* Session token refresh (requires base_sdk >= 1.12.0). Login now persists
  the backend's full token contract — `refresh_token` (to secure
  keystore/keychain storage) and `expires_at` — instead of dropping both,
  so base_sdk's new single-flight `TokenRefreshService` can silently
  rotate the 24h access token (proactively at expiry, and on 401 with one
  retry) instead of dumping the user on the login screen every day. New
  `SessionTokenRefresh` capability interface (same pattern as
  `DeferredOtpEmailResend`): `AuthRepository` implements it by delegating
  to the base_sdk service; facade implementations that skip it simply get
  no explicit renewal hook, the automatic interceptor path still applies.
  When rotation itself fails at the auth level, the stored session is
  cleared and the existing per-notifier 401 -> login routing takes over.
  Version 1.7.0 is claimed by the idempotency-key PR (Users #16), hence
  1.8.0. (The offline-password PR, Users #19, ships above this as 1.8.2.)

## 1.7.0

* `sigUpWithData` sends an `X-Idempotency-Key` header (optional
  `idempotencyKey` named param threaded through the base_sdk
  `AuthRepositoryFacade`): the server's `register_user` endpoint is already
  `@idempotent`, so a retried registration upload now replays the stored
  response instead of double-registering. The key is stable per local
  account row (`OfflineAuthService.registrationIdempotencyKey`, row id +
  identifier, well under the backend's 140-char cap) and is shared by the
  offline-sync push (`syncOne`) and the inline online register path, so a
  retry through either flow dedupes against the other. Requires base_sdk
  with the `idempotencyKey` param on `AuthRepositoryFacade.sigUpWithData` —
  merge this SDK BEFORE that base_sdk change (implementers may carry extra
  optional named params; the interface declaring one that implementers
  lack would not compile). Direct callers without a natural stable key
  simply send no header.

## 1.6.0

* Desktop platform guards (`src/common/services/platform_support.dart`):
  social sign-in buttons (Facebook/Google) are hidden on Windows/Linux,
  where google_sign_in / flutter_facebook_auth have no implementation
  (kept on Android/iOS/web/macOS, where they do); Firebase phone-OTP
  sends fail fast with a translated snackbar on non-mobile platforms
  instead of hanging a spinner (`verifyPhoneNumber` is Android/iOS-only);
  and FCM token sync after login/register/confirm goes through a shared
  `syncFcmToken` helper that silently skips on Windows/Linux (where
  Firebase is never initialized) and swallows messaging failures instead
  of throwing `[core/no-app]` into the auth flow.

## 1.4.0

* `session_policy` fallback role (`"*"`): an `allowed_roles` entry with role
  `"*"` declares a keep-session fallback — an authenticated account whose
  role matches no other entry is ADMITTED (token persisted, session kept)
  and lands on the fallback entry's route instead of being rejected. Exact
  roles always win over `"*"`; role-less/offline sessions can only land on
  the fallback route, never on an exact-role landing. This is the driver
  composition's D1 shape (deliveryman -> `/home`, everyone else ->
  `/become-driver` with a live session so the courier request is filed as
  the signed-in user, as delivery_sdk 1.3.0 declares). Policies without a
  `"*"` entry are untouched: non-matching roles are still rejected with no
  persisted session (manager's seller-only gate behaves bit-for-bit as
  before), and `rejection_*` keys keep working for them.

## 1.3.0

* Deferred-OTP auto-routing (`PendingOtpGate`): when an offline-registered
  account's background sync completes, the app now takes the user into the
  existing OTP confirmation sheet by itself — at boot/session-restore, on
  app resume, and promptly after a sync that finishes mid-session — instead
  of leaving the `pending_otp_verification` flag unread. Installed into the
  composed app's `main()` via the new manifest `boot_hooks` entry; prompts
  only the flagged account's own session, and a dismissed sheet re-prompts
  on the next trigger (the flag is only cleared by verify success).
* `RegisterConfirmationPage.isDeferredOtp`: verify success just closes the
  sheet (the account already exists — no follow-on registration form), and
  phone codes use the backend sendOtp/verifyPhone pair even under
  `AppConstants.isPhoneFirebase`, since only `verifyPhone` lifts the
  backend's unverified-account limit.
* `DeferredOtpEmailResend`: auth_sdk-local repository capability for the
  backend's `resend_verification_email` — the email-OTP send that works for
  an account that already exists (the pre-registration `sigUp` send would
  be rejected with "already exists").

## 1.1.0

* `AuthSessionPolicy` seam: which roles may sign in and where each lands is
  now composition data (manifest `session_policy`, injected into the
  installed `auth_session_policy.dart` shell by the installer's
  `update_session_policy()`), consulted by every login variant (email,
  offline, Google, Facebook, Apple). No declared policy keeps the previous
  allow-all `isDemo ? replaceUiTypeRoute : goHome` behavior exactly.
  Rejected accounts get no persisted token.
* Login page no longer crashes at init in apps composed without an
  onboarding SDK: the `EmbeddedWidgets.I.introPage()` lookup is guarded and
  the Skip affordance is hidden when no intro exists.

## 0.0.1

* TODO: Describe initial release.
