## 1.4.1

* fix(users): the local session is cleared on sign-out whether or not the
  server revoke succeeds. `UserRepository.logoutAccount` ran
  `LocalStorage.logout()` INSIDE the `try`, after
  `api.user.logout` - so a revoke that threw (no network, a 401 on a token
  the backend never issued, a backend that is down) returned failure and
  left the token, the persisted profile and every SDK's session-scoped
  on-device data exactly where they were. The clear moves into a
  `finally`; the returned `ApiResult` still reports what the revoke did, it
  just no longer decides whether the device forgets the session.
  `deleteAccount` moves with it, for the same reason and one more:
  `SessionEndHooks.run()` has already torn the session-scoped state down by
  that point, so a live local session behind a failed delete is strictly
  worse than being signed out and asked to try again.
* The case that made this certain rather than unlucky: an offline /
  temp-local account's token is `offline:<local user id>` (auth_sdk's
  `OfflineAuthService`), which no backend ever issued, so `api.user.logout`
  can NEVER succeed for one of those users. Sign-out was a guaranteed
  no-op for exactly the users who only have local data - Ray, 2026-09-19:
  "if on temp local user you logout all your tasks still show".
* Tests: `test/user_repository_logout_test.dart` - the revoke succeeding
  clears the session; the revoke failing clears it too and still returns
  the failure; the session-end hooks fire on the failing path; a failed
  `deleteAccount` clears it as well. The gateway is exercised end to end
  through a stubbed `HttpService`, so the failure is a real
  `DioException` out of `PlatformGateway`.
* manifest.json 1.4.0 -> 1.4.1; no new base_sdk requirement.

## 1.4.0

* Demo login in production, phase 2: the demo repositories follow the
  runtime demo session. `UsersSdkDependencies.register` no longer picks
  `MockUserRepository` / `MockAddressRepository` on the compile-time
  `AppConstants.isDemo` alone: it reads `DemoSession.demoActive`
  (base_sdk 1.61.0: a demo BUILD, or the runtime demo SESSION auth_sdk
  flips after the real backend accepted a marked account) at
  registration, and subscribes once to `DemoSession.instance` - the same
  static listener is removed before it is added, so a hot restart or a
  hand-wired host calling the hook twice never stacks subscriptions. On
  every flip the listener unregisters this SDK's two facades (only those,
  and only when present, so a container reset or a flip before boot
  finished registering never throws) and registers the twins the switch
  now selects: the in-app fixtures the moment a marked account signs in
  (after the backend accepted it, before routing), the HTTP repositories
  the moment the session clears (sign-out, or a sign-in the backend
  answered without the marker). A demo session's profile edits and
  addresses never reach a real account, and a real session never reads
  the fixtures. Callers resolve the facades per call through get_it, so
  the next fetch already lands on the new twin; a host that captured a
  repository instance at construction keeps it until it rebuilds.
  Demo builds behave exactly as before (`demoActive` includes the build
  flag), so the tour fragment needs no change and no screen changes.
* Tests: `test/users_di_demo_session_test.dart` - a real session registers
  the real repositories; `activate()` swaps in the twins and `clear()`
  swaps the real ones back; a session restored at boot registers the
  twins directly; a demo build registers them whatever the session;
  registering twice keeps the instances and one subscription; a flip
  against an emptied container never throws; the DI reads
  `DemoSession.demoActive`, not `AppConstants.isDemo`.
* manifest.json 1.3.8 -> 1.4.0; requires base_sdk 1.61.0.

## 1.3.8

* feat(users): per-user `is_demo_account` marker in the login and profile
  payloads (backend half of demo sign-in). Demo login is a runtime
  feature keyed on a marker the server asserts: base_sdk 1.61.0 parses
  `is_demo_account` off the user payload and auth_sdk 1.11.0 switches
  the apps to demo data when it reads 1. This release gives the Frappe
  side of users_sdk that marker.
  * `users/frappe/fixtures/custom_field_user_is_demo_account.json`
    declares a hidden Check custom field `is_demo_account` on User
    (default 0, after `enabled`, description "Marks a demo showcase
    account; the apps switch to demo data when this user signs in"),
    exported through `users/frappe/manifest.json` `hooks.fixtures` next
    to `temporary_user_expires_on`. Nothing seeds an account: an
    operator ticks the box on the User form of the account they choose.
  * `user.py` gains `is_demo_account(user_doc)` (`cint` of the column,
    so a tenant without the fixture reads 0) and every payload that
    carries a user emits it: `login`, `login_with_google`, `get_profile`,
    `get_user_profile`, `verify_phone_code` and `verify_email_code`.
    auth's `restore._issue_session`, shaped like `login`, emits it too.
  * Server-asserted only: `update_user_profile`'s allow-list does not
    carry the field (and says why), and `update_profile` has no such
    parameter. `tests/test_api_demo_account_marker.py` drives the real
    endpoint bodies against a stubbed User row and pins 0 for an
    unmarked account, 1 for a marked one, 0 for a missing column, and
    that the profile update endpoints cannot flip it;
    `tests/test_user_custom_field_declarations.py` pins the fixture and
    its manifest export.
  * The tenant-wide `Permission Settings.is_demo` Check in core is a
    different switch and is deliberately not reused.
* manifest.json 1.3.7 -> 1.3.8. Pairs with core #184 and Users #94; the
  backend carries no ordering dependency on either.

## 1.3.7

* fix(tour): two highlight phrases in `templates/tour/users.tour.yaml`
  were too long for the wide reel's caption column. The assembler wraps
  the 1920x1080 reel's captions at 800 px (DejaVu Sans Bold 64 px, 84 px
  row pitch) and measures a `*highlight*` phrase as one unbreakable token
  with 40 px of chip padding, so a phrase wider than 760 px runs past the
  wrap width into the margin (a warning, never a failure). The paas_driver
  guided tour (run 34061972563) reported `caption for step 'users_profile'
  in the wide reel: row 3 runs 130px past the 800px wrap width into the
  caption margin: the highlight phrase 'your details in one place' does
  not fit one row and a highlight never splits across rows`; the second
  phrase, `name, phone and email` in `users_profile_settings`, measures
  86 px past the same wrap and only escaped the warning because the reel
  caps its beats. Both phrases now fit one reel row with margin (chip
  widths 579 px and 754 px), the captions keep their meaning, and each
  still wraps to three phone rows on the portrait canvas (936 px, 7-row
  box). Before and after:

  ```text
  Your {app_name} account keeps *your details in one place*.
  Your {app_name} account keeps *all your details* in one place.
  Update your *name, phone and email* any time they change.
  Update your *name, phone, email* any time they change.
  ```

  No screen changes. Shells pick the fragment up on their next tour run:
  the composer refreshes the cache copy and captions only reach
  `tour.resolved.json`, never a committed shell file.
* manifest.json 1.3.6 -> 1.3.7 so version-aware cache reconciliation
  re-merges the fragment into every shell.

## 1.3.6

* `MockUserRepository` reads the demo avatar from base_sdk's
  `DemoImages.avatar` (new in base_sdk 1.60.4) instead of carrying its
  own copy of the inline SVG literal. auth_sdk's `MockAuthRepository` had
  the same literal for the same reason (ADR-005 forbids one importing the
  other, and the kernel had no avatar entry); both now read the one
  constant, so the header can never swap faces between the login user and
  the fetched profile. Requires base_sdk >= 1.60.4 (declared in
  `manifest.json` `_comment_requires`). `test/mock_user_repository_test.dart`
  pins the avatar to the kernel constant.

## 1.3.5

* The demo profile carries a rand wallet. Every demo amount now prints in
  South African rand - base_sdk 1.60.3 seeds its `DemoCurrency` (id `ZAR`,
  symbol `R`, position `before`) at boot after the guided tour's wallet
  history read "42.50USD" / "1,500.00USD" - and the account
  `MockUserRepository` serves is the one surface that still described no
  currency at all. Its `ProfileData` now carries `Wallet(uuid: 'wallet-1',
  price: 793.00, currency: DemoCurrency.rand)`: the balance is the net of
  wallet_sdk's demo ledger (a top-up, two purchases, a partial refund and
  a cash-out on that wallet), so the profile's wallet card ("R793.00") and
  the history page agree. Requires base_sdk >= 1.60.3 (declared in
  `manifest.json` `_comment_requires`). `test/mock_user_repository_test.dart`
  guards the currency, the wallet id and the balance.

## 1.3.4

* Demo builds get a `MockUserRepository`, selected by the same
  `AppConstants.isDemo` ternary in `UsersSdkDependencies.register` that
  already picks `MockAddressRepository`. `UserRepositoryFacade` was the
  HTTP `UserRepository` unconditionally, so in a demo build - no backend -
  every `profileProvider.fetchUser` failed, `LocalStorage.getUser()`
  stayed null (auth_sdk never persists the login user; production relies
  on this fetch) and base_sdk's `GenericProfilePage` fell back to
  "Profile" for the name and an orange "?" avatar, under the failure
  snackbar, in every shell's account still. The mock serves the account
  auth_sdk's `MockAuthRepository` signs in (Thandi Mokoena, `+27 82 456
  7890`, "42 Marula Avenue, Sandton", inline-SVG initials avatar), takes
  email and role from the persisted session when there is one and never
  invents a role otherwise (the sign-in address decides it; merchants'
  `SignedInRoleToast` and orders board read `LocalStorage.getUser()?.role`),
  keeps profile edits and avatar changes in memory for the session, and
  ends the session on logout / delete-account the way the HTTP repository
  does (`SessionEndHooks.run` then `LocalStorage.logout`). auth_sdk's
  post-login `syncFcmToken` now also lands on the mock instead of a
  failing request.
* `MockAddressRepository` no longer seeds "123 Demo St" (San Francisco)
  and "456 Office Blvd": the address book is the same "42 Marula Avenue,
  Sandton" home the profile shows, plus "15 Alice Lane, Sandton" for work.
  `test/mock_user_repository_test.dart` pins the wording and the
  profile/address-book agreement.

## 1.3.3

* `UserRepository.updateProfileImage` now sends `{'image': ...}` — the
  server's `update_profile_image(image)` kwarg — instead of `image_url`,
  which frappe dropped silently before raising a TypeError on the missing
  positional. `updatePassword` now sends `password_confirmation` alongside
  `password`: `update_password(password, password_confirmation)` needs both
  and compares them server-side, so the confirmation the facade already
  received is forwarded verbatim rather than left out. Both are Dart-side
  fixes to match the existing server signatures (Dart SDK audit
  2026-09-02, U1/U2); the `api.user.*` aliases and `ProfileResponse`
  mapping are unchanged. New `test/user_repository_payload_test.dart`
  drives the real `PlatformGateway` through a recording
  `HttpClientAdapter` and asserts the `{cmd, payload}` envelope for both
  calls (`dio` added as a dev dependency for it).

## 1.3.2

* Version-only bump so composed shells re-extract users_sdk. `SessionEndHooks`
  (`lib/src/common/services/session_end_hooks.dart`), its `users_sdk.dart`
  barrel export and the two `SessionEndHooks.run()` calls in
  `user_repository.dart` all landed in the Restore Credentials change without
  a manifest version bump, so no shell ever refetched them — every consumer
  stayed on the cached 1.3.1 tree, which has none of those files. auth_sdk's
  `auth_restore_credential_gate` boot hook, which composes
  `SessionEndHooks.register('restore_credentials', RestoreCredentialGate.clear)`
  into every host `main.dart`, then referenced a class that was not in the
  composed sources: `Error: Undefined name 'SessionEndHooks'` broke the
  paas_driver and paas_manager Android builds. The bump also restores the
  logout/delete-account half of the feature — without the refetched
  `user_repository.dart` nothing ever fires the registered hooks. No source
  change.

## 1.3.0

* New guided-tour fragment `templates/tour/users.tour.yaml` (fragment name
  `users`, per the fleet naming registry): a three-step account chapter —
  the signed-in account surface at `/profile` (tolerant `onFailure`
  navigation for compositions that keep the account surface elsewhere),
  the edit-profile sheet opened via the `TrKeys.profileSettings` tile
  (finder-guarded), and an action-only cleanup step that closes the sheet.
  Brand-neutral: finders go through `AppHelpers.getTranslation(TrKeys.*)`
  and captions use `{app_name}` placeholders, mirroring auth_sdk's
  `auth.tour.yaml`. Additive only — no installs, routes, or lib changes.

## 1.2.1

* Freezed 3 follow-through for the installed profile template (the fleet
  migration covered `lib/src` only): `profile_notifier.dart` now imports
  `package:base_sdk/src/handlers/api_result.dart` directly so its
  `ApiResult.when` call sites resolve against freezed-3 base_sdk
  (`ProfileState` was already `abstract`). No behavior change.

## 1.1.1

* API path fix: every call string in `user_repository.dart` (profile,
  addresses, logout, wallet history, device token, delete-account,
  profile image, password, search) and `address_repository.dart`
  (list/create/delete address) now uses the composed backend's registered
  alias form `paas.api.user.<fn>` (the keys in
  `users/frappe/manifest.json` `hooks.whitelisted_methods`) instead of
  the one-segment-longer `paas.api.user.user.<fn>`, which is not a
  registered name and made every one of these calls a silent 404 on
  composed backends. Client-side only — no alias or backend changes.
* `get_referral_details` and `set_active_address` have no backend
  endpoint at all yet; their paths are normalized to the same convention
  but the calls remain unimplemented server-side until a backend lands.

## 0.0.1

* TODO: Describe initial release.
