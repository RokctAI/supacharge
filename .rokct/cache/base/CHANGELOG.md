# Changelog

## 1.69.0

* feat(base): the host names one more optional Kotlin bridge, `AppChangesBridge`,
  so a launcher shell can be told when the device's installed apps change. The
  bridge is launch_sdk's and ships in its templates; base_sdk only registers it
  reflectively and keeps it from being stripped, the same way `DefaultHomeBridge`
  is handled. A compose without launch_sdk has no such class and registers
  nothing. No Dart change.

## 1.68.0

* fix(base): sign-out no longer deletes the account's own records. `LocalStorage.logout()`
  was wiping the wallet cache, saved shops, search history, the selected address and its
  details, so a temp-local account that logged out came back to an empty app. It now ends
  the session only - demo session, stored profile, token, token expiry, refresh token and
  the onboarding board.
* feat(base): those five records are keyed per account. A record written while someone is
  signed in lives under `<key>::<owner>`, the same identity the drift tables scope by, so
  the next account to sign in on a shared device reads its own. A read falls back to the
  bare legacy key when the account has never written one, which is what carries an existing
  install's data across the upgrade.

## 1.67.0

* feat(base): the two device-global tables holding user-owned data gain an
  `owner`, and every read filters by it. `KeyValueTable` was `{box, id, data}`
  keyed on `{box, id}` and `OutboxTable` was keyed on `id` alone, in one
  `rokct_app.sqlite` behind one process-wide `AppDatabase` - so everything two
  accounts stored under the same box and key was the same row, and a user who
  signed out with ops still queued had them pushed under the next user's
  session, into the next user's account.
* Visibility scoping, NEVER deletion. The product ruling is that a sign-out
  must not delete user data: a temp local account that does real work, signs
  out and comes back has to find its own work. So rows gain an owner, reads
  filter on it, and nothing is destroyed at sign-out.
* An existing row with no owner counts as the CURRENT user's -
  `owner = '' OR owner = <me>`, not `owner = <me>`. Every row on every device
  in the field has no owner, so a strict match would hide everybody's data,
  which is the outcome the ruling forbids. Legacy rows stay as visible as they
  are today and leave the unowned set as they are next written (`putItem`
  claims the unowned row for the key it writes), with no migration guessing an
  owner for anything.
* `owner` is NOT NULL with a `''` default rather than nullable, because it
  joins the PRIMARY KEY of both tables and SQLite - unlike the SQL standard -
  permits NULLs inside an ordinary rowid table's composite primary key. A
  nullable version would compare NULL != NULL in the backing index, so
  `insertOnConflictUpdate` on an unowned row would append a second row instead
  of updating the first and the next single-row read would have two rows to
  choose from. `''` is a value, so the key stays total.
* `owner` is IN the primary key on both tables - `{box, id, owner}` and
  `{id, owner}` - so two accounts can hold the same key side by side. For the
  outbox that is not hypothetical: `enqueueOrReplace` mints the deterministic
  id `<opType>:<dedupeKey>`, so two accounts coalescing `cart.sync:<shop id>`
  on one device produce the same string, and with `id` alone the second
  replaced the first and every by-id write (`retryOp`, `deleteOp`, the status
  writes) reached across accounts.
* New `OwnerScope` resolves the owner in one place, behind a swappable
  resolver, and never appears in the table definitions. It reads
  `LocalStorage.getUser()?.id` first, and the `offline:<local user id>` token
  second - not as a convenience but because a TEMP-LOCAL account, the exact
  account the ruling is about, stores no user at all (auth_sdk's
  `OfflineAuthService.registerOffline` / `loginOffline` call `setToken` and
  nothing else), leaving that token as the only thing on the device that names
  it. It also remembers the last account it saw, so a write during sign-out
  teardown - after `LocalStorage.logout()` has already cleared both the stored
  user and the token, which is when every session-end hook runs - is
  attributed to the account on its way out instead of landing as an unowned
  row the next user would then see.
* New `AppDatabase.adoptOwner` hands one owner's rows to another, called from
  the sync engine as each temp id resolves: a temp-local account starts being
  called by its backend user id the moment it syncs, and without this it would
  come back from its first sync unable to see its own work.
* Schema version 19, claimed in `base/dart/manifest.json` - base_sdk's first
  `database.migration` - after reading every composed manifest reachable from
  this workspace: radio 18, productivity 17, auth 16, agent/replay/
  subscriptions 15, polaris 13, fav 12. The composer substitutes the
  `schemaVersion` getter from the maximum any manifest declares and only
  raises that maximum for a manifest declaring BOTH a version and a step, so a
  base-owned number written only in Dart would have been erased and a device
  already at the running maximum would have run no migration at all. The
  migration rebuilds each table the long way round (rename aside, create from
  the current definition, copy the shared columns, drop) because SQLite cannot
  alter a primary key in place; `beforeOpen` calls the same idempotent
  `ensureOwnerScopeColumns()` on every open as a floor under the numbering,
  exactly as the table floor above it already does.
* Not in this change: the other SDKs' own tables and their own KV boxes, and
  `IdMappingsTable`, whose rows are globally unique `offline:<uuid>` keys
  carrying no user-owned data.

## 1.66.10

* `FloatingNavAction` gains an optional `onLongPress` - a SECOND gesture on
  a bar control, for the shortcut a feature SDK hangs off its primary button.
  Ray, 2026-09-20: "i think productivity plus should be in the floating nav
  when you in its page. floating nav already accept modes and buttons", and
  the button moving onto the bar already carries a long press ("plus opens
  new but i think hlding it should give me option like tasks notes").
* NOTHING NEW WAS BUILT for it. `_NavActionButton` has passed an
  `onLongPress` to its `InkWell` since controls mode shipped - the reactions
  button uses it to reopen the emoji picker - so this only offers the gesture
  the bar already had to the caller who supplies the action. The bar's own
  long press still wins where it has one (`onLongPress ?? action.onLongPress`),
  which keeps the reactions button behaving exactly as before.
* Null is the default, so every existing bar in the fleet renders and
  responds identically. `locked` and a null `onTap` suppress the long press
  too: an unpressable control is unpressable by either gesture, which is the
  rule `enabled` already stated for the tap.
## 1.66.9

* fix(base): `ProfileNotifier.logOut` awaits the sign-out and then clears the
  local session. It called `_userRepository?.logoutAccount(fcm: fcm)` WITHOUT
  awaiting it and cleared nothing locally, so a profile screen's Log out
  button returned while the revoke - and users_sdk's `SessionEndHooks`, which
  each SDK hangs its own on-device user data off - were still in flight, and
  nothing on this path ended the session on the device at all. An offline /
  temp-local account's token is `offline:<local user id>`, which no backend
  ever issued, so the revoke can never succeed for one of those users and the
  sign-out was a guaranteed no-op for exactly the users who only have local
  data. Ray, 2026-09-19: "if on temp local user you logout all your tasks
  still show".
* `LocalStorage.logout()` is unconditional here, as it already is in
  launch_sdk's `LauncherAuthControl.logOut` and now in users_sdk 1.4.1's
  `UserRepository.logoutAccount`. It is idempotent, so the overlap costs
  nothing, and it is also what signs a user out in a compose that registered
  no `UserRepositoryFacade` at all - where the repository call is skipped.
* Tests: `test/profile_notifier_logout_test.dart` - the revoke has completed
  by the time `logOut` returns; the token and the persisted profile are gone
  after a successful revoke, after a rejected one, and in a compose with no
  users_sdk.
* manifest.json 1.66.7 -> 1.66.9 (1.66.8 is claimed by another open PR).
## 1.66.8

* Fixed: the launcher's entry screen said "Something went wrong with the
  server" for an unreachable backend, after #243 had already authored the
  honest line for exactly that failure. Ray, 2026-09-20: "something went
  wrong with server is stll showing in splash/ login screen". Two separate
  defects were between #243's copy and that screen, and neither was the
  wording.
* **The presenter overwrote the line.** `AppHelpers.errorHandler` returns
  student-facing copy naming the SERVER for a response-less failure, and
  repositories put that string into `ApiResult.failure(error:)`. Surfaces
  that hand `failure` straight to the snackbar - the base profile page -
  showed it. Surfaces that go through `ErrorPresenter`, which is every auth
  screen including login, did not: the unconditional technical branch
  discarded `detail` and painted the generic
  `something_went_wrong_with_the_server` fallback, whose humanized form is
  Ray's sentence verbatim. `ErrorPresenter.resolve` and
  `ErrorPresenter.showTechnical` now keep `detail` when it is already one of
  the two connection-failure lines `errorHandler` authors, recognised by the
  new `AppHelpers.isAuthoredConnectionMessage` - an exact match against the
  same values that helper can return (the translated row for either key, or
  the named `kCouldNotReachServerLine` / `kServerTookTooLongLine` literals),
  so no server or exception text can pass as student copy. The telemetry
  still fires, so the call site's event type - which fetch failed - is not
  lost; only the sentence on screen changes. An explicit `friendly:` still
  wins, a definitive 4xx still shows the server its own words, and raw
  technical detail still never reaches a screen.
* **The copy was unreachable on the only two screens it was written for.**
  `getTranslation` consulted the bundled per-locale maps by
  `LocalStorage.getLanguage()?.locale`, and `BundledTranslations.lookup`
  returns null for a null locale. Splash and login both run before any
  language has been chosen - and the login screen's own `checkLanguage`
  cannot store one while the backend it would fetch the catalogue from is
  unreachable - so those two screens humanized straight past
  `kBaseEnTranslations` and got the clipped "Could not reach server" instead
  of "We couldn't reach the server. Please try again.". That map exists
  precisely because those keys NAME a string rather than spelling it.
  `getTranslation` now falls back to the new
  `BundledTranslations.baseLocale` ('en', already the `isDefault` row of
  `fallbackLanguages` and the first of `bundledLocales`) while no language
  is stored. A chosen language behaves exactly as before, and a key with no
  bundled row - `something_went_wrong_with_the_server` among them - still
  humanizes.
* #243's copy, its `NetworkExceptions.getDioException` switch (still
  exhaustive, still with no `default`) and `getDioStatus` are all untouched:
  this change carries that copy to the screen rather than replacing it. No
  reachability probe was added before any call - it doubles round trips and
  still races, the same reason #243 rejected one.
* `error_handler_test.dart`'s "the two connection lines are the bundled
  English copy" previously pinned the clipped `'Could not reach server'` for
  a device with no language chosen, noting that `getTranslation` consults
  the bundled map by the active locale. That was the real behaviour and it
  is the gap Ray reported; the assertion now expects the bundled copy it
  asserts one line above, and a matching one was added for the timeout line.
  The test is neither skipped nor removed.
* New: `error_presenter_unreachable_line_test.dart` - 14 tests over the real
  funnel (`AppHelpers.errorHandler` on a response-less `DioException`, status
  from `NetworkExceptions.getDioStatus`), covering both fixes, the
  first-run/no-language state, the snackbar branch, and the four things that
  must NOT change.

## 1.66.7

* The same rule, second sweep: **a shared component takes its theme mode
  from the theme, never from a global static.** #247 fixed the 22 the #244
  audit had left; this pass walks the components that read a mode-resolving
  static with no `Theme.of` anywhere in their file, and separates the ones
  that are genuinely blind from the ones a parent or a notifier already
  rebuilds.
* The bug class is unchanged from #242/#244/#247. A widget is theme-blind
  when its `build` decides a colour from a mutable static that changes with
  the mode AND that same `build` registers no inherited-widget dependency a
  flip reschedules. `MediaQuery.sizeOf`, `MediaQuery.paddingOf` and
  `MediaQuery.of(...).viewInsets` are not defences: a window size, a
  status-bar inset and a keyboard inset do not move when the mode does.
* 10 components fixed, each now reading `Theme.of(context).brightness` in
  `build` - outside every inner builder - and naming its colours from
  `AppStyle`'s explicit-brightness seams: `SearchTextField`,
  `OutlinedBorderTextField`, `UnderlineDropDown`, `MoneyKeypad`,
  `SelectItem`, `SelectAddressItem`, `CustomTabBar`, `CommonAppBar`,
  `BaseWalletCard` and the `EditProfileScreen` sheet.
* NO new `AppStyle` seam was needed: `inkFor`, `cardFor`, `cardAltFor`,
  `subtleStrokeFor` and `surfaceFor` already name every role this sweep
  touches, and no colour changes in either mode. `MoneyKeypad` and
  `UnderlineDropDown` also stop leaning on the type scale's mode-resolving
  `textPrimary` DEFAULT for their digit and selected-value ink, which is the
  same defect arriving through `AppStyle.interSemi()`/`interNormal()`
  rather than through a named token.
* The reachability pass rejected five of the candidates, and rejecting them
  matters as much as fixing the rest - a widget a parent already rebuilds
  needs no change:
  * `ForgotTextButton` watches the whole `appProvider` state, which
    `AppNotifier.changeTheme` writes, so the flip rebuilds it.
  * `ProfileThemeToggle` - the control that performs the flip - watches
    `appProvider.select((s) => s.isDarkMode)`, i.e. exactly the value the
    flip changes; it is the one widget guaranteed to be rescheduled (its
    own sun/moon glyph would otherwise be stuck too).
  * `GenericProfileRoutePage` watches the same `isDarkMode` selector,
    deliberately, for its `surfaceDark` scaffold.
  * `CustomToggle` has two real mount sites inside base_sdk -
    `ProfileSwitchTile` and `ButtonItem` - and #247 gave both a
    `Theme.of(context).brightness` read; each instantiates it non-`const`
    inside that same `build`, so the flip rebuilds the toggle through its
    parent.
  * `CustomTimePicker` is not a widget at all: a static helper with no
    `build`, no element and no mount site, whose Cupertino popup picks its
    fill at the moment the user opens it.
* A re-scan of the package turned up one shape the audit list did not name,
  `ProductUIComponents.buildQuantityControl`, and the same filter rejects
  it: its only mount site is `ProductCard.build`, which #247 gave a
  `Theme.of(context).brightness` read and which calls the helper non-`const`
  from that build. The four private classes inside `generic_profile_page`
  (`_IdentityHeader`, `_AnonymousHeader`, `_TopRow`, `_PlanBackCard`) are
  rejected the same way: `_GenericProfilePageState.build` watches
  `isDarkMode` and builds all four non-`const`.
* 10 real widget tests, one per fixed component, each mounting its subject
  behind the shared `ThemeFlipHost`'s `const` child boundary a flip cannot
  cross, flipping `AppStyle.setBrightness` plus `themeMode` the way
  `AppNotifier.changeTheme` does and pumping WITHOUT remounting. All 10 were
  verified failing on the pre-change source. No component needed a
  source-level guard instead.
* Three further tests pin a CALLER's own colour against the flip - a search
  field's `bgColor`, the keypad's `AppStyle.primary` OK key and a positive
  wallet balance's `AppStyle.green` - and `theme_flip_host` grows the
  `expectPinnedOnFlip` mirror of `expectRestylesOnFlip` for them. These pass
  on both sides of the change by design: they exist so a later sweep cannot
  start resolving a colour its caller chose.

## 1.66.6

* One rule across base_sdk's shared components: **a shared component takes
  its theme mode from the theme, never from a global static.** Ray,
  2026-09-19, on the widgets the #244 audit found and left: "i might forget
  if you leave them so decide", then "the theme stuff".
* The bug class, restated from #242 and #244. A widget is theme-blind when
  its `build` decides a colour from a mutable static that changes with the
  theme mode AND that same `build` has no other inherited-widget dependency.
  `AppStyle.isDark` and the nine getters that resolve against it are not an
  inherited widget, so a theme-mode flip schedules no rebuild of such a
  widget at all: the user flips light or dark and the old colour stays until
  they leave the screen and come back. `MediaQuery.of`, `MediaQuery.sizeOf`
  and `Directionality.of` do not save a widget from this - none of them
  changes when the mode does, which `MarketItem` demonstrates: it reads
  `MediaQuery.sizeOf(context).width` for its own width and was still blind.
* 22 components fixed, each now reading `Theme.of(context).brightness` in
  `build` - outside any inner builder - and naming its colours from
  `AppStyle`'s explicit-brightness seams: `MarketItem`, `TabBarItem`,
  `SizeItem`, `ComingSoonDialog`, `LoadingGrid`, `CustomAppBar`,
  `AppBarBottomSheet`, the five elements of the standard list language
  (`_ListFilterTabChip`, `ListCountPill`, `ListRoundAction`,
  `ListScreenHeader`, `ListViewMore`), `ButtonItem`, `SocialButton`, the
  generic profile host's empty-sections placeholder, `ProfileSwitchTile`,
  `ProfileNavTile`, `ProfileSectionCard`, `_ActionTile`, `_ActionRow`,
  `MaintenancePage` and `ProductCard`.
* Four new `AppStyle` colour-role seams for the surfaces these components
  draw, each the same shape as #242's `inkFor` and #244's `secondaryInkFor`:
  `cardFor`, `cardAltFor`, `strokeFor`, `subtleStrokeFor`. No new colour
  values - each names the same two values its mode-resolving getter
  (`cardDark`, `cardDarkAlt`, `strokeDark`, `strokeDarkSubtle`) already
  resolves between, chosen by an explicit `Brightness` rather than by the
  app-wide `isDark` static. No hex literal was added to any widget.
* `ProductCard` shows that being a `ConsumerWidget` is no defence: its brand
  and shop lookups are `ref.read`s, and nothing it watches fires on a mode
  flip. `LoadingGrid` shows the sharpest shape - its fill was read inside an
  `itemBuilder`, which runs only when the grid decides to build a tile, so a
  placeholder screen could sit in the wrong mode's grey indefinitely. It now
  reads the brightness in `build` and the builder closes over it.
* The polarity-pinned values are deliberately untouched: `surfaceLightRaw`
  and `surfaceDarkRaw` exist to build the host MaterialApp's paired
  `ThemeData` and must never resolve, and the flat constants (`white`,
  `primary`, `red`, `transparent`, `bottomNavigationBarColor`) are identical
  in both modes. A caller's OWN colour is also left alone throughout - an
  active list tab keeps its tab colour, a `ProfileActionItem.accent` keeps
  its accent - and both are pinned by tests.
* Every one of the 22 got a real widget test that flips the theme mode and
  pumps WITHOUT remounting, each mounting its subject behind the `const`
  child boundary a flip cannot cross - which is how these are mounted in the
  product, none of them having a mount site inside base_sdk at all. No
  component needed a source-level guard instead.

## 1.66.5

* A floor under migration numbering, in `AppDatabase.beforeOpen`. Ray,
  2026-09-19: "migration numbering do it".
* The hazard: every composed SDK manifest declares
  `database.migration.version` into ONE shared namespace, and the composer
  takes the MAXIMUM across all manifests as the app's `schemaVersion` while
  concatenating each SDK's migration `step` into the single `onUpgrade` it
  injects into the cached copy of `app_database.dart`. Two SDKs that pick the
  same number - or tables registered with no matching step - leave an
  upgrading device whose stored `user_version` ALREADY equals that maximum,
  so drift runs no migration at all: not `onCreate`, because the file exists,
  and not `onUpgrade`, because the versions match. A table that is in the
  schema is never created and the first query against it throws. Fresh
  installs are fine throughout, because `onCreate` calls `createAll`, which
  is what makes this so easy to ship: the crash only reaches devices that
  upgraded.
* `beforeOpen` now walks `allTables` and creates any table missing from the
  file, rather than naming `outbox_table` and `id_mappings_table` one by one
  as it did before - so whatever the composer injects between the
  `@sdk-database-tables` markers is covered on the same terms as base's own
  tables. Drift's `createTable` emits `CREATE TABLE IF NOT EXISTS` (verified
  against the pinned drift 2.28.2), so it neither drops nor rewrites an
  existing table and leaves its rows alone.
* It runs on EVERY open, not only after an upgrade. The collision case is
  precisely the one where `versionBefore == versionNow`, so drift reports
  `hadUpgrade == false` and a gate on an upgrade would skip the very failure
  the net exists for. Cost is held down instead: one `sqlite_master` read
  per open tells the loop which tables are already there, so the steady
  state issues no DDL at all.
* This is a floor, NOT a substitute for correct numbering. The `onUpgrade`
  path, the base-owned `from < 2` step and all four composer injection
  markers are untouched, and nothing is renumbered. A duplicate migration
  number is still a bug to fix at the manifest; it just no longer takes a
  table down with it.
* New `test/database_migration_floor_test.dart`: a file at the current
  schema version with a registered table absent - the numbering slip in
  miniature, driven with base's own `key_value_table`, which no `onUpgrade`
  step recreates - comes up with that table queryable, covers every table in
  `allTables` rather than a hand-listed few, leaves existing rows in place
  across repeated opens, and still brings a fresh file up through `onCreate`.

## 1.66.4

* The fleet audit #242 asked for. Ray, 2026-09-19: "might be worth checking
  in all sdks if this is there not just in glance" - every Dart package in
  core and in the SDKs the launcher composes, hunting the same shape: a
  widget that names a colour from a static that changes with theme mode
  while resolving nothing from its `BuildContext`, so nothing reschedules it
  when the mode flips.
* `ActiveOrderGlanceCard`: the severe-weather notice #242 deliberately left
  alone. The shell honours a row that names its own colour, and this row
  named `AppStyle.textDarkSecondary` - the app-wide static - from inside two
  `ValueListenableBuilder`s, which rebuild only when their notifier fires.
  A mode change reached neither, so the notice kept the previous mode's
  muted ink until an order refresh or an ETA tick happened along. The card
  now reads `Theme.of(context).brightness` in its own `build`, outside both
  builders, and names the notice's ink for that mode.
* `ProfileMetaRow`: the profile footer's app-name/version/status line
  resolved nothing from the context either, and it is mounted `const` by
  `BaseProfileFooter`, so the flip provably could not reach it through a
  parent rebuild - the same const-child boundary the glance card sat behind,
  on the very page the theme toggle lives on. It now reads the inherited
  theme and names its ink from `AppStyle.inkFor`.
* New `AppStyle.secondaryInkFor(Brightness)`, `AppStyle.faintFor(Brightness)`
  and `AppStyle.surfaceFor(Brightness)`: `textDarkSecondary`'s,
  `textDarkFaint`'s and `surfaceDark`'s two values resolved against an
  explicit brightness, the counterparts of #242's `inkFor` for those three
  colour roles. No new colour values. `faintFor` and `surfaceFor` have no
  caller in this repository yet: they are the seam the audit's remaining
  cases need, exposed here so a later fix does not have to bump base_sdk
  again just to reach it. `surfaceFor` is a mode-RESOLVING seam and is not
  to be confused with the polarity-pinned `surfaceDarkRaw`/`surfaceLightRaw`
  pair, which exists for building the host's paired `ThemeData`.
* New `test/theme_mode_statics_test.dart`: a mode change with each widget
  mounted behind a boundary the flip does not cross on its own account.
* Audit result, for the record: 48 build methods across core read a
  mode-resolving `AppStyle` static with no inherited-theme dependency of
  their own, and 22 of those are not reached by any parent rebuild that the
  flip does schedule. The two above are the cases where staleness is
  provable from the code in this repository. The remaining 20 are shared
  kernel components with no mount site inside core, so whether anything
  reschedules them is the host's business, not theirs - they are reported
  rather than changed here.

## 1.66.3

* An unreachable backend now says the server could not be reached instead of
  telling the reader to check a connection that is working. Ray, 2026-09-19,
  correcting the wording he was shown: "not check your connection but check
  your network connection", and then naming the cause himself: "im thinking it
  could be that the backend is unreachable rather than the phone being
  offline". He was right on both counts, and this is a SECOND defect, distinct
  from the radio-whitelist fix in 1.66.1: that one was about the guard toast
  ("No internet connection") firing BEFORE any request; this one is about the
  toast that fires AFTER a request was attempted and got no answer.
* `NetworkExceptions.getDioException` had a `switch` in which every single arm
  was a bare `break`, so control always fell through to one
  `noInternetConnection()` return. A refused connection, a dead host, a
  rejected certificate, a cancelled request, a timeout and every HTTP status
  from 400 to 503 all came back as "the reader has no internet"; fourteen of
  the union's variants were unreachable. Each arm now returns the variant it
  names, `badResponse` is classified by its status, and the response-bearing
  case no longer reaches `error.response!` on a null response. Only a
  transport that never got an answer still answers `noInternetConnection`.
* `AppHelpers.errorHandler`'s connection-failure line is now chosen from the
  failure, not fixed. The argument that decides the default: this code runs
  ONLY for a request that was attempted, and every network path in the fleet
  sits behind an `AppConnectivity.connectivity()` guard that shows its own
  offline snackbar and returns without calling anything. Past that guard the
  device had a network moments ago, so a response-less failure is the server
  not answering. Two lines, because they carry different instructions: a
  server that never answered (`connectionError`, `badCertificate`, a DNS
  failure arriving as `unknown`, a cancelled request) reads
  `TrKeys.couldNotReachServer`; a server that answered too slowly
  (`connectionTimeout`, `sendTimeout`, `receiveTimeout`, `transformTimeout`)
  reads `TrKeys.serverTookTooLong`. No new freezed union member, so nothing is
  code-generated.
* `_isConnectionFailure` now also admits `RequestCancelled`. A cancelled
  request has no response either, so leaving it out sent it down the
  extraction chain, which has nothing to extract and ends at `e.toString()` -
  raw "DioException [request cancelled]" text on a student's screen. A
  judgement call, and the alternative is worse.
* Added: `TrKeys.couldNotReachServer` / `could_not_reach_server` and
  `TrKeys.serverTookTooLong` / `server_took_too_long`, with English copy in
  `bundled_en_translations.dart` and Afrikaans in
  `bundled_af_translations.dart`. Both keys NAME a string rather than spelling
  it, which is exactly what the bundled English map exists for; humanizing
  them would give the clipped "Could not reach server". `TranslationSeeder`
  offers the backend these same English values, so app and backend agree. The
  wording is a stated default and a one-line change.
* Unchanged on purpose: `AppHelpers.showNoConnectionSnackBar`'s literal "No
  internet connection", which belongs to the pre-request guard and is the
  right thing to say when the radio really does report none;
  `NetworkExceptions.getDioStatus`, so every `ApiResult.statusCode` and every
  `ErrorPresenter.isDefinitiveRejection` decision reads exactly as before; and
  the `badResponse` extraction path, so a server-authored message still
  arrives verbatim.
* Tests: `test/error_handler_test.dart` splits its old
  one-line-for-everything expectation into an unreachable case and a timeout
  case, asserts the bundled English copy, and asserts that a response-bearing
  failure is classified by its status rather than as "no internet"; new
  `test/profile_server_unreachable_toast_test.dart` drives the real
  `GenericProfilePage` with an online radio and a facade that maps its
  exception through `AppHelpers.errorHandler` the way every repository does,
  and asserts the toast names the server, is not the check-your-network line,
  and is not the guard's "No internet connection" either.
* Follow-up, not in this change: `showNoConnectionSnackBar` hard-codes its
  English literal while `TrKeys.noInternetConnection` and an Afrikaans value
  for it both exist, so that toast is the one offline surface that never
  translates.

## 1.66.2

* The shared glance card restyles itself the moment the theme mode changes.
  Ray, 2026-09-19: "glance doesnt change test immediately untill you come back
  if you switched theme mode" - on the launcher home, where the glance kept the
  previous mode's text until the page was built again from scratch.
* `GlanceCard.build` resolved nothing from its `BuildContext`: its chrome came
  from `AppStyle`'s statics and its rows' ink was left to whatever ambient
  `DefaultTextStyle` a host happened to provide. Neither is a dependency, so a
  theme-mode change (an `AppStyle.setBrightness` flip plus a new `themeMode` on
  the host `MaterialApp`) scheduled no rebuild of the card's own element - it
  restyled only when something else rebuilt it, i.e. on the way back into the
  launcher.
* It now reads `Theme.of(context).brightness` and names its rows' and title's
  ink from `AppStyle.inkFor` for that mode, so the mode change itself rebuilds
  the card wherever it is mounted. A row that names its own colour (the
  active-order card's muted weather line) still keeps it.
* New `AppStyle.inkFor(Brightness)`: `textPrimary`'s two values, resolved
  against an explicit brightness instead of the app-wide `isDark` static, for
  widgets that take their mode from the inherited theme. Same spirit as the
  polarity-pinned `surfaceLightRaw`/`surfaceDarkRaw` pair.
* New `test/glance_card_theme_mode_test.dart`: a mode change with the card's
  page still mounted, in a subtree the flip does not rebuild on its own
  account, and the caller-named-colour case.

## 1.66.1

* The radio check no longer calls an online phone offline. Ray, 2026-09-19:
  "going  to profile i get offline toast" - on the launcher build that had just
  grown a Profile item, on a phone with a working network.
* `AppConnectivity.connectivity()` admitted exactly three `connectivity_plus`
  answers as online - mobile, ethernet, wifi - and called everything else
  offline. The plugin reports `ConnectivityResult.none` EXACTLY when the active
  network carries no `NET_CAPABILITY_INTERNET`, so every other answer is a
  network the OS believes can carry traffic: `vpn` (the active network on a
  phone with a VPN up, which is what Android's `getActiveNetwork()` hands the
  plugin), `other` (the Windows/Linux catch-all for an internet-capable
  transport with no name, and tethering), `bluetooth`. All three were read as
  "no internet".
* That is the whole path to Ray's toast. `ProfileNotifier.fetchUser` gates the
  profile fetch on this check and, on false, shows
  `AppHelpers.showNoConnectionSnackBar` ("No internet connection") without
  attempting anything - so opening the profile on such a device produced the
  offline toast and no profile, while the rest of the app carried on.
* The definition now lives in one place, `AppConnectivity.isOnline(results)`:
  online is "the plugin did not say none" (an empty answer is still offline).
  `connectivity()`, `connectivityWithDialog` and `connectivityAndShowDialog`
  read it, `ConnectivityService._isOnline` delegates to it instead of keeping
  its own copy, and the splash's own copy
  (`splash_page.dart`'s `_checkConnectivity`) goes the same way - a boot that
  silently took the offline path on a VPN-connected phone now takes the online
  one. Three copies of one predicate is how they came to disagree.
* New `test/profile_offline_toast_test.dart`: the online definition across
  every result the plugin can report, and the page itself - a signed-in phone
  whose radio says `vpn` opens the generic profile, fetches, and shows no
  offline toast; a radio that really says `none` still shows it and still does
  not fetch.

## 1.66.0

* The composed app's `main()` now installs two uncaught-error handlers before
  it does anything else (`templates/main.dart`), so a crash leaves a readable
  record in the platform log instead of a process that simply went away. Ray,
  2026-09-18: "it crashes when you go back to the launcher" - the phone had
  nothing to show for it.
* `FlutterError.onError` logs the exception and its stack through `debugPrint`
  and then calls `FlutterError.presentError`, which is the default handler, so
  debug still gets the red screen and release still gets the console dump -
  the logging is added in front of the existing behaviour, not instead of it.
* `platformDispatcher.onError` covers everything the framework never sees: a
  throw from a platform message handler, a failed unawaited Future in a boot
  hook, anything raised on the root zone. It logs and returns `true`.
* No `runZonedGuarded`, and no new dependency. The platform-dispatcher hook is
  already the whole-app net, and a zone around `runApp` would be wrong here:
  the bindings are initialized at the top of `main()` in the root zone, and
  running `runApp` in a different zone is the "Zone mismatch" assertion.

## 1.65.3

* New `UserAvatar` (`src/presentation/components/user_avatar.dart`), the one
  avatar every screen draws a person with, and it never draws a "?" (Ray,
  2026-09-18: "profile image is ? no image or letters why"). Three states in
  order: the stored picture through `CustomNetworkImage` when `ProfileData.img`
  is set, else the person's initials on the brand colour, else
  `Icons.person_outline` - a neutral person glyph.
* The question mark was real and reachable. The generic profile header's
  private `_Avatar` ended on `source.isEmpty ? '?' : source[0].toUpperCase()`,
  so a signed-in session whose cached `ProfileData` carried no picture AND no
  name or email - what a restored session looks like before the profile fetch
  lands - drew a literal "?". launch_sdk's account control carried its own copy
  of the same fall-through. Both now render `UserAvatar`, so there is one
  ladder and the two cannot disagree again.
* Initials are the first letter of each of the first two words of the name,
  falling back to the email's local part when there is no name at all. "Letter"
  is a whole user-perceived character - the leading code point plus its
  combining marks - so an accent survives and an astral-plane code point is not
  sliced into a lone surrogate. Casing is `String.toUpperCase`, Unicode's
  locale-independent default mapping, so caseless scripts pass through
  unchanged rather than being mangled.
* Sizing stays with the caller (`size`, optional `fontSize`/`glyphSize`): base's
  own pages pass screenutil values, launch_sdk - which does not depend on
  flutter_screenutil - passes logical pixels. Both call sites keep the exact
  metrics they had, so nothing moves on screen.
* New `RoutePresence` (`src/navigation/route_presence.dart`): asks the host's
  own generated auto_route router whether a route NAME is registered, so an SDK
  can offer an optional destination and offer nothing at all where the compose
  has none. `AppRoutes`' host implementation throws out of `noSuchMethod` for a
  method no installed SDK declared, which is right for a navigation the app
  cannot do without and wrong for "and here is your profile". Carries
  `genericProfileRouteName` - `GenericProfileRoute`, the name this manifest
  already mounts `/generic-profile` under, not marketplace_sdk's `ProfileRoute`.
* New `test/user_avatar_test.dart` (10 tests): the picture state, the initials
  state including two words, one word, the email fallback and the Unicode
  cases, the glyph state for an empty profile and for no profile at all, and
  that no state anywhere renders a "?". New `test/route_presence_test.dart` (4
  tests): no router, a router carrying the route, a router carrying other
  routes, and the route name pinned against this manifest's own `routes` and
  `app_routes` entries.

## 1.65.2

* Fixed: `templates/android/.../MainActivity.kt` now registers optional
  platform bridges, so a package SDK that ships Kotlin glue is no longer a
  no-op in the composed app. `configureFlutterEngine` keeps its two direct
  registrations and adds `registerOptionalBridges`, which for each simple
  class name in `OPTIONAL_BRIDGES` resolves `<this activity's package>.<name>`
  reflectively and invokes `register(BinaryMessenger, Activity)`. A missing
  class (`ClassNotFoundException`) is the expected case for an app composed
  without that SDK and is ignored, so this template still compiles and runs
  in every app that does not have the SDK. First entry is launch_sdk's
  `DefaultHomeBridge` (channel `rokct.launch_sdk/default_home`), whose Dart
  half - `DefaultHomeService`/`DefaultHomePrompt`, the once-per-install ask to
  become the device's home app - could never fire because nothing called it.
* Reflection reads the package from the activity's own class instead of a
  literal `com.app.demo.*`: the release lane rewrites every Kotlin source's
  `package` declaration to the customer application package before it
  compiles, so a hard-coded name would resolve to nothing in a shipped build.
  Both shapes of a Kotlin `object` are accepted (`@JvmStatic` static method or
  the `INSTANCE` singleton), so no SDK has to change its bridge to be picked
  up.
* `templates/android/app/proguard-rules.pro` keeps `**.DefaultHomeBridge`
  (name intact, bodies still optimizable). A reflectively-resolved class has
  no reference for R8 to follow, so the release build - `minifyEnabled true`,
  `shrinkResources true` - would otherwise shrink it away and the ask would
  work in debug and silently do nothing in the shipped app.

## 1.65.1

* Fixed: the splash no longer spends a dio timeout on a backend it already
  knows is unreachable. The 1.64.2 fix skipped the translations fetch when
  the `api_status` probe answered "down", but `SplashNotifier.getToken` was
  still gated on `AppConnectivity.connectivity()` alone — radio-only, which
  a Wi-Fi network with no route to the tenant backend false-passes — so it
  awaited `getGlobalSettings()` BEFORE reaching any routing decision and the
  person sat on the splash artwork for the full timeout anyway. `getToken`
  now takes `backendUp` the same way `getTranslations` does: with the backend
  known down it routes straight off the stored token (`Main` when there is
  one, `LoginPage` when there is not) and touches no network at all. The
  radio-off branch still hands control to `goNoInternet`.
* Fixed: `manifest.json` said `1.64.1` while `pubspec.yaml` and this file
  said `1.64.2`; all three now agree.

## 1.65.0

* Removed: `AppConstants.isDemo` (`--dart-define=IS_DEMO=true`) and
  `DemoSession.isDemoOverride`. The compile-time demo flag is dead (Ray:
  "AppConstants.isDemo is dead") - no shipped build passed the define, and
  a seam that read the constant instead of the switch served a
  server-marked demo account the real repositories, silently.
  `DemoSession.demoActive` is now the only demo switch in the fleet:
  `static bool get demoActive => AppConstants.isTour || instance.active;` -
  the guided-tour build (`--dart-define=TOUR_MODE=true`, the one build that
  runs with no backend and no sign-in to assert a marker with) keeps its
  in-app fixtures through `AppConstants.isTour`, and everything else is the
  runtime session auth_sdk activates from the server-asserted
  demo-account marker. `AppConstants.isTour` is untouched.
* Removed: the two parallel test seams that existed only because a
  compile-time constant cannot be flipped by a test -
  `DemoCurrency.isDemoOverride` and `ProfileMetaRow.isDemoOverride`. Both
  read `DemoSession.demoActive` directly now, and their tests drive the
  real runtime API (`DemoSession.instance.activate()` / `clear()` over
  `SharedPreferences.setMockInitialValues`) instead of a stand-in.
* `test/demo_switch_contract_test.dart` is inverted rather than dropped: the
  source contract is now that NO Dart source under any `<sdk>/dart/lib` or
  `<sdk>/dart/templates` reads `AppConstants.isDemo`, that
  `app_constants.dart` no longer declares it (while it still declares
  `TOUR_MODE`), and that `demoActive` is the tour build OR the session and
  carries no test-only override.
* MERGE ORDER: this must land AFTER the three agent-repo PRs that re-point
  the remaining `AppConstants.isDemo` readers in their own SDKs
  (RokctAI/agent: lms #314, plus the radio and subscriptions PRs). Their
  SDKs still read the constant until then, so removing it here first breaks
  their compilation.

## 1.64.2

* Fixed: startup no longer blocks or surfaces error UI when device has internet but backend is unavailable.
  `SplashPage._initializeApp` now allows startup to proceed when backend is unreachable, falling back to local
  translations and stored credentials to reach `LoginPage` (or `Main` for authenticated users). Removed unwanted
  `AppConnectivity.connectivityWithDialog` calls during startup flow so modal error dialogs do not interrupt splash screen.

## 1.64.1

* Fixed: a tablet profile no longer leaves the third plane empty (Ray,
  2026-09-07: "on a tablet the generic profile host must not leave the
  third plane empty"). `GenericProfileRoutePage` only ever filled the last
  plane by SEEDING a detail into it, and a detail is only seeded when the
  registry carries a `ProfileSectionRegistry.defaultSectionId` - which no
  composed SDK sets, so every real tablet profile rendered profile |
  profile | bare. The host's profile page now declares
  `PlanePage.allowNeighbors` false: with no detail beside it the profile is
  the whole flow, so `PlaneHost` clamps the visible planes to the two the
  claim holds and those two share the full width. The universal cap is
  untouched - still two planes and two columns, never a stretched phone
  layout - and the flag is read only for the ACTIVE step, so it does
  nothing at all once a card (or the seeded default) opens a detail: the
  profile yields the last plane and spreads over the two before it exactly
  as before. Two-plane windows and phones are unchanged.
* `test/generic_profile_route_page_test.dart` now asserts the landing state
  at 1066 dp fills the window in two columns instead of stopping short of a
  bare third plane.

## 1.64.0

* Added: a dotted app name folds to its stem on the splash. When the
  display name (server 'title' setting, else the composed app's
  `AppConstants.appTitle`) contains a dot with something in front of it,
  the wide-window boot wordmark and the boot-fallback screen show the full
  name first, then after 1.5 s the dot and everything after it slide into
  the stem (the suffix's clipped box collapses toward the stem with the
  floating bar's `easeOutCubic` / `AppConstants.animationDuration`; one
  step when the platform disables animations). A name with no dot renders
  exactly as before. New `AppHelpers.appNameStem`, `appNameFolds`,
  `appNameSuffix` and `getAppNameStem` decide on the value alone - no
  brand is named anywhere; new
  `src/presentation/pages/initial/splash/folding_brand_name.dart`
  (`FoldingBrandName`) carries the motion. The profile footer keeps the
  full name.

## 1.63.1

* Fixed: Tour builds hide the system bars on large screens so the launcher
  taskbar stays out of tablet stills; shipped builds unchanged.
  `SplashPage._removeSplash` now restores the post-splash system UI mode
  through `postSplashSystemUiMode` (new
  `src/presentation/adaptive/tour_system_ui.dart`): immersive-sticky only
  when `AppConstants.isTour` (`--dart-define=TOUR_MODE=true`) AND the
  window's shortest side is at least `AppBreakpoints.medium`, edge-to-edge
  everywhere else - exactly what it was before.

## 1.63.0

* Fixed (security): a credential carried as a query parameter no longer
  reaches a log. Dio's `LogInterceptor` prints the full request URI on
  every request and on every failure, and a debug console is copied
  verbatim into CI job logs - so any secret travelling in a query string
  was written down in clear text every time the call failed. New
  `src/handlers/log_redaction.dart` is the one place that decides what a
  log line may say: `redactUri`, `redactLogText`, `redactHeaders` and the
  `kSensitiveQueryParameters` / `kSensitiveHeaders` name lists. Redaction
  is by parameter NAME, never by matching the secret itself, so nothing
  has to know a key in order to hide it and a rotated key is covered the
  moment it rotates. Everything else in the URI - host, path, the other
  parameters, their order and encoding - is left exactly as it was, so a
  redacted line is still worth reading.
* Changed: every `LogInterceptor` this kernel builds now prints through
  `logRedactedLine` (`HttpService.client`, both the ordinary and the
  routing client). The credential names cover the ones in use across the
  fleet - `api_key`, `apikey`, `api-key`, `key`, `token`, `access_token`,
  `refresh_token`, `secret`, `signature` and friends as parameters;
  `Authorization`, `Cookie`, `X-Api-Key`, `X-Goog-Api-Key` and
  `X-RapidAPI-Key` as headers, since `requestHeader: true` prints those
  verbatim too and moving a secret into a header is no fix if the header
  is logged.
* Changed: the network error funnel redacts before it reports.
  `AppHelpers.errorHandler`'s connection-failure path sent
  `requestOptions.uri` to telemetry, which debugPrints its whole payload
  in a debug build and stores it after that; it now sends the redacted
  URI and a redacted `message`. Same one-line treatment for the other
  places that print a raw network exception: `TelemetryClient` (both
  lanes, payload and delivery failure), `TokenRefreshService`,
  `TranslationSeeder` and `RemoteConfigService`.
* Added: `RoutingCredentialInterceptor`, on the routing client only. The
  routing provider authenticates by an `Authorization` header as well as
  by an `api_key` query parameter - an unauthenticated
  GET answers 401 "Authorization field missing", and the header is
  equivalent thereafter - so the interceptor strips every
  credential-named parameter off a routing request and promotes its value
  to the header. Call sites may keep passing `api_key` and none of them
  can reintroduce the leak; the header also keeps the secret out of every
  proxy and provider access log between the device and the API, which no
  redaction on this side could ever reach. `AppConstants.routingKey` and
  its `ROUTING_KEY` define are untouched.
* Tests: `test/log_redaction_test.dart` - a failing request carrying a
  credential parameter is driven through the real Dio logging path and
  the emitted string is asserted to hold the path, the coordinates and
  the 403 but not the credential; header lines redacted while a header
  NAME quoted inside a response body is left alone; the routing
  interceptor moving the key off the wire URL and onto the header, from
  the query map and from a path-appended query alike; and a wiring
  contract that no `LogInterceptor` built here prints raw.

## 1.62.0

* Changed: base_sdk's own two demo reads follow the RUNTIME demo switch
  (phase 2 of "demo login in production", Ray 2026-09-08; phase 1 was
  1.61.0's `DemoSession`). `DemoCurrency` and `ProfileMetaRow` now ask
  `DemoSession.demoActive` (a demo BUILD or a demo SESSION) where they
  read the compile-time `AppConstants.isDemo` alone. The constant itself,
  and `DemoSession.demoActive`'s own read of it, are untouched, so the
  guided tour, render strip and screenshots build exactly as before.
* Added: `DemoCurrency.followDemoSession()` - `seed()`s now and again on
  every flip of `DemoSession.instance`, one listener per process. The
  kernel DI (`BaseSdkDependencies.register`) calls it in place of the bare
  `seed()`, so a demo account that signs in after boot still prints every
  amount in rand. `seed()` keeps its contract - only where nothing is
  selected, never a delete - so a session ending writes nothing and a
  real account's currency stays exactly as it was. Test-only
  `stopFollowingDemoSession()`.
* Changed: the profile footer's Online/Offline dot (`ProfileMetaRow`)
  reads as connected in a demo session as it does in a demo build, and
  rebuilds on the session flip (`ListenableBuilder` on
  `DemoSession.instance`): the profile is the screen a sign-out happens
  on, so the dot re-asks the real probe the moment the session ends
  instead of keeping the session's answer. Nothing new on screen.
* `DemoCurrency.isDemoOverride` / `ProfileMetaRow.isDemoOverride` now
  stand in for `DemoSession.demoActive` (null asks the session), same
  seam as before for tests.
* Tests: `test/demo_currency_test.dart` (seeded on flip, untouched on
  clear, a selected currency survives a flip, one listener per process),
  `test/base_profile_footer_demo_test.dart` (Online per session, back to
  the probe on clear), and `test/demo_switch_contract_test.dart` - a
  source contract that no `AppConstants.isDemo` read remains in any
  `*/dart/lib` of this repo outside `app_constants.dart` (the definition)
  and `demo_session.dart` (the OR), so a new seam cannot quietly bypass
  the runtime switch.

## 1.61.1

* Added: the profile's edit form as a DETAIL PANE at plane widths (Ray
  2026-09-08, the sheet fork ruling: "sheet = PHONE, plane widths get a
  pane" — on the driver tablet the END-anchored Profile settings sheet
  left an empty band at 385 dp and was cut in the store crop). A detail
  WITHOUT a hub card: `ProfileSectionRegistry.editProfileDetailBuilder`
  (nullable `WidgetBuilder`; the form rendered embedded — no sheet chrome,
  app bar or back of its own) under the fixed step id
  `ProfileSectionRegistry.editProfileDetailId`, plus
  `ProfileSection.detailOnly(id:, detailBuilder:)` for such a section.
  `ProfileSectionNavigator` gains `openDetail(context, id:, detailBuilder:)`
  (an ad-hoc detail in the host's last plane), `openEditProfile(context)`
  (the registry's edit detail), `canOpenEditProfile(context)` and
  `close(context)` (an embedded detail's own way back to the landing state
  — the default section's detail on three planes, the bare stage on two —
  without popping the route), behind a new optional `onClose` on the seam
  that `GenericProfileRoutePage` provides. The identity-card pencil now
  tries `openEditProfile` first and runs `onEditProfile` only when the
  host cannot open a detail, so an SDK keeps its sheet as the phone flow
  by construction; the pencil also draws with a detail alone (planes
  only — a phone with no `onEditProfile` draws no dead pencil). The corner
  pill pops this detail back to the default before it pops the route,
  exactly as for a card's detail. Every existing call site is
  source-compatible; a registry with no `editProfileDetailBuilder` renders
  byte-identical to 1.60.10.

## 1.61.0

* Added: the RUNTIME half of the demo switch, for "demo login in
  production" (Ray 2026-09-08: keep the build-time tour flag AND let real
  accounts on the production backend - one per role: deliveryman, seller,
  admin - flip the app into the in-app fixtures once the real backend has
  accepted them; nothing on screen says demo; session-scoped; sign-out
  clears it; demo actions never reach real shops, drivers or payments).
  `AppConstants.isDemo` (`--dart-define=IS_DEMO=true`) is untouched, so
  the guided tour, render strip and screenshots build exactly as before.
  New `DemoSession` (`lib/src/services/demo_session.dart`, exported): a
  `ChangeNotifier` singleton (`DemoSession.instance`) whose `active` is
  persisted in `LocalStorage` under `demo_session_active`, with
  `activate()` / `clear()` (each notifies once per real flip, never on a
  no-op) and `static bool get demoActive => isDemo ||
  DemoSession.instance.active` - the one question every demo seam should
  ask from now on. `LocalStorage.logout()` calls `clear()`, so every
  sign-out path in the fleet (users_sdk logout / delete-account, the 401
  auto-logout) ends the demo session with the session. New
  `LocalStorage.setDemoSessionActive` / `getDemoSessionActive` /
  `deleteDemoSessionActive` and `StorageKeys.keyDemoSessionActive`.
* Added: the server-asserted demo marker on the user models. `UserModel`
  (the login payload's `user`) and `ProfileData` (the profile endpoint,
  the stored session) both parse an optional `is_demo_account` (a Frappe
  Check's 0/1 or a JSON bool; absent, null or anything else is false) into
  `bool get isDemoAccount`, carry it through `copyWith` / `toJson`, and
  the shared `parseDemoAccountMarker` decodes it. auth_sdk 1.11.0 flips
  `DemoSession` on this field alone, strictly after the real
  `AuthRepository` has signed the account in - never on an address or a
  password, and `MockAuthRepository` stays compile-time gated.
* Phase 2 (SDK data wiring) follows: the per-SDK DI ternaries that read
  `AppConstants.isDemo` at registration (auth, users, delivery, orders,
  products, merchants, revenue, zones, comms, plus the delivery launcher /
  location / profile gates and this kernel's `DemoCurrency.seed` and
  `ProfileMetaRow`) move to `DemoSession.demoActive` and re-register on
  `DemoSession.instance.addListener`. Until then `activate()` changes
  nothing a user can see beyond the flag itself: with only this release
  merged a demo account signs in and is served exactly like any other.
  Tests: `test/demo_session_test.dart` (activate / clear / persist round
  trip, listener notifications, sign-out via `LocalStorage.logout`,
  `demoActive` under the `isDemoOverride` seam), and
  `test/demo_account_marker_test.dart` (the marker on both models).

## 1.60.10

* Added: the generic profile host's DETAIL PLANE (Ray 2026-09-07, "on a
  tablet the generic profile host must not leave the third plane empty").
  `ProfileSection` gains an optional `detailBuilder` (the section's detail
  surface, rendered embedded — content only, no app bar or back of its
  own) and `ProfileSectionRegistry` a `defaultSectionId` (plus `section(id)`
  and `defaultSection` lookups). `GenericProfileRoutePage` (the routed
  `/generic-profile` page) now owns a plane stack instead of a constant
  one-entry host: on a THREE-plane screen the default section's detail is
  pushed on top of the profile from the first frame with the default
  one-plane claim, so it fills the third plane while the profile keeps its
  two (the universal cap; the `PlaneHost` yield rule does the rest); on two
  planes nothing is seeded. New `ProfileSectionNavigator` seam: a section
  card calls `ProfileSectionNavigator.open(context, id)` from its tap and
  keeps its ordinary push as the fallback — on planes the host opens the
  detail in its last plane (replacing the default; the corner Back returns
  to the default before it pops the route), while a phone route, a host
  without the seam, or a section without a detail answers false so the
  card pushes exactly as before. Phone behaviour and every other plane
  flow are untouched; a registry with no `defaultSectionId` renders the
  route page byte-identical to 1.60.9.

## 1.60.9

* Fixed: the floating Back pill's chevron and label were under the WCAG
  floor on every light page. The pill's housing (`_Housing`, shared by the
  tab pill, the bare Back pill, `FloatingBackPill` and the tablet rail)
  filled itself with a 30% wash of the polarity-PINNED
  `AppStyle.bottomNavigationBarColor` (`0xFF191919`) under pinned-white
  ink. The housing is deliberately the same dark pill in both themes - but
  at 30% it took 70% of whatever page it floated over, so on a light page
  it measured `#ACACAE`-`#B2B3B5` and its white contents sat at 2.1-2.3:1.
  The fill is now 70%: the smallest round alpha that keeps white ink at
  or above 4.5:1 over ANY page (6.48:1 on pure white; 60% is the exact
  floor with no margin). Size, radius, blur, icon, label and placement
  (the bottom-END corner from 1.60.5) are untouched.

  Measured from real renders of the courier profile (`paas_driver`
  `test/render/`, the composed `ProfilePage` route with its bare Back pill)
  and the courier Orders list, phone frame, WCAG sRGB ratios inside the
  pill's own rects:

  | frame | ink on pill, before | after | pill vs page, before | after |
  |-------|---------------------|-------|----------------------|-------|
  | profile, dark  | `#FFFFFF` on `#131313` - 18.58:1 | `#FFFFFF` on `#161616` - 18.10:1 | 1.02:1 | 1.05:1 |
  | profile, light | `#FFFFFF` on `#ACACAE` - **2.27:1** | `#FFFFFF` on `#585859` - **7.11:1** | 1.92:1 | 6.03:1 |
  | orders, dark   | `#FFFFFF` on `#B2B3B5` - **2.10:1** | `#FFFFFF` on `#5B5B5C` - **6.78:1** | 1.92:1 | 6.22:1 |
  | orders, light  | `#FFFFFF` on `#B2B3B5` - **2.10:1** | `#FFFFFF` on `#5B5B5C` - **6.78:1** | 1.92:1 | 6.22:1 |

  The dark-page look is unchanged to the eye (`#131313` -> `#161616`
  over `surfaceDark`). The Orders row is the same in both modes because that
  page still grounds itself on the pinned `bgGrey` on current main; zones
  #106 (delivery_sdk 1.21.1) moves it to `surfaceDark`, after which its dark
  row reads like the profile's. No public API changed; no call site changes.

## 1.60.8

* Fixed: `CustomAppBar` was invisible in dark mode - every label on it
  vanished. The bar grounded itself on the polarity-PINNED `AppStyle.white`
  (`0xFFFFFFFF`), a surface that never flips, while all ten of its call
  sites put DEFAULT ink on it (`AppStyle.interSemi`/`interRegular` with no
  `color:`, which resolve through `AppStyle.textPrimary` and go `#FFFFFF`
  in dark mode). White ink on a white bar. `CommonAppBar`, the sibling in
  the same folder, already grounds itself on the mode-resolving
  `AppStyle.cardDark`; this bar was the outlier, and now matches it.

  Measured from a real render of the Manager create-order screen
  (`paas_manager` `test/render/`, `OrderPage`), element
  `orders.create.appbar_title` (shop title, `interSemi` 18):

  | mode  | before                     | after                      |
  |-------|----------------------------|----------------------------|
  | dark  | `#FFFFFF` on `#FFFFFF` - **1.00:1** | `#FFFFFF` on `#1C1C1C` - **17.04:1** |
  | light | `#1B1B20` on `#FFFFFF` - 17.15:1 | `#1B1B20` on `#F9F9FB` - 16.31:1 |

  The dark "before" number is not a near-miss, it is the whole story: the
  title's box measured **100.0% a single colour**, i.e. not one glyph pixel
  was distinguishable from the bar. After the fix the same box is 71.7%
  ground / 28.3% ink - pixel-for-pixel the same glyph coverage the light
  frame has always had.

  In light mode the bar moves from pure `#FFFFFF` to the light palette's
  card surface `#F9F9FB` - the value `AppStyle.cardDark` resolves to in
  light mode, and the ground `CommonAppBar` has always drawn. Contrast
  stays far above the 4.5:1 WCAG floor.

* Fixed: the backend-maintenance page had an invisible title in dark mode.
  `MaintenancePage` pinned `Scaffold(backgroundColor: AppStyle.white)` under
  a title styled `AppStyle.interSemi(size: 20.sp)` - resolving ink, pinned
  ground, the same collision as the bar above. It now uses
  `AppStyle.surfaceDark`, the mode-resolving page ground
  `generic_profile_page` already uses. Measured on the same harness,
  element `base.maintenance.title`:

  | mode  | before                     | after                      |
  |-------|----------------------------|----------------------------|
  | dark  | `#FFFFFF` on `#FFFFFF` - **1.00:1** | `#FFFFFF` on `#101010` - **19.03:1** |
  | light | `#1B1B20` on `#FFFFFF` - 17.15:1 | `#1B1B20` on `#ECECEF` - 14.55:1 |

  The palette is untouched: `AppStyle.white` keeps its value and its other
  light-only call sites. No public API changed, and no call site needed a
  change - all ten `CustomAppBar` call sites across `orders_sdk`,
  `delivery_sdk` and `revenue_sdk` put only resolving ink on the bar, so
  every one of them is strictly improved by the flip.

## 1.60.7

* Fixed: "Forgot password" was unreadable on the dark sign-in sheet.
  `ForgotTextButton` styled its label with the polarity-PINNED
  `AppStyle.black` (`0xFF232B2F`) - ink that never flips - so on the dark
  sheet it measured **1.32:1** against the sheet's `0xFF101010` ground, far
  under the 4.5:1 WCAG floor for body text, while the sheet title beside it
  (which already resolves through `AppStyle.textPrimary`) sat at 19.03:1.
  Measured from a real render of the Manager sign-in sheet
  (`paas_manager` `test/render/render_screen_test.dart`), element
  `auth.login.forgot_password`:

  | mode  | before                     | after                      |
  |-------|----------------------------|----------------------------|
  | dark  | `#232B2F` on `#101010` - **1.32:1** | `#FFFFFF` on `#101010` - **19.03:1** |
  | light | `#232B2F` on `#ECECEF` - 12.22:1 | `#1B1B20` on `#ECECEF` - 14.55:1 |

  The label now takes `fontColor ?? AppStyle.textPrimary`. Two details
  worth naming: the `fontColor` parameter was declared but never read by
  `build` (the label was hard-coded), so it is now honoured; and its const
  `AppStyle.black` default became `null`, because `AppStyle.textPrimary`
  is a mode-resolving getter and cannot appear in a `const` expression -
  the same reason the whole `AppStyle.inter*` type scale takes a nullable
  `color`. Nothing in the fleet passes `fontColor`, so no call site changes
  appearance in light mode beyond the ink token's own `#232B2F` ->
  `#1B1B20`.

## 1.60.6

* Fixed: the routed `/generic-profile` page stretched its phone list
  across a tablet window. base_sdk's route shell mounted a bare
  `GenericProfilePage`, and the page spreads only under a `PlaneHost`
  (`Planes.maybeOf` was null), so on the launcher's tablet leg the
  profile rendered as one stretched column with no back. New
  `GenericProfileRoutePage` (exported) is what the shell mounts now: at
  plane widths it hosts `GenericProfilePage` in a two-plane `PlaneHost`
  (the approved profile cap, frames 1c/1f: two planes at most, the
  leftover plane a bare stage at the END on the page surface) and, the
  routed profile being a pushed page, parks the one Back — a
  `FloatingBackPill` — at the bottom-END corner where `PlaneHost` parks
  its own (frame 1d, "back button should always be at a corner"), only
  while the route can pop. On a phone the page is `GenericProfilePage`
  exactly as before. The same fleet pattern zones' driver profile host
  uses, now in base so no shell needs a wrapper of its own.

## 1.60.5

* Fixed: the bare Back pill sat in the wrong place in a tablet-mode window.
  `FloatingBottomNav` treated a back-only `FloatingNavTabsMode` (empty
  `tabs`, no `trailing`, a `back`) as a tab bar, so it followed the
  app's `tabletNavPlacement`: bottom-centre on every fleet default app
  (the driver's pushed pages, the wallet history, the comms settings and
  notification pages), and a one-button rail at mid-height on the START
  edge on the manager (`railStart`). The approved two-state nav rule
  (design strip section 12, frame 12d, Ray 2026-08-29 12:36Z: "the nav
  sits at bottom center unless i tell you to snap it on the right. but
  back with no other buttons sit at the corner") puts a back with no other
  buttons at the bottom-END corner. `FloatingBottomNav.build` now parks
  that pill at the bottom-END corner in a tablet-mode window - a
  `FloatingBackPill` 16 logical in from both edges inside the SafeArea,
  directional so it flips in RTL - the same placement `PlaneHost` already
  gives a pushed plane, whatever the app's or page's tablet placement
  says. A back that rides with tabs or trailing actions still follows
  placement; phone windows still draw the bottom-centre pill; controls
  mode is untouched. `test/floating_nav_back_test.dart` covers the corner
  at the fleet default, under `railStart` and `hidden`, and the unchanged
  phone pill.

## 1.60.4

* Fixed: the maintenance page rendered its translation keys. On a tenant
  whose Translation doctype had no `en` rows, `MaintenancePage` showed
  "Maintenance title" / "Maintenance brief": base_sdk bundled no `en` map
  at all (English was meant to survive through
  `AppHelpers.humanizeTrKey`), which holds for keys named after their copy
  and fails for keys that NAME a string. New
  `lib/src/services/bundled_en_translations.dart` (`kBaseEnTranslations`,
  exported from the barrel) bundles "Under maintenance" and "We are doing
  some maintenance. Please try again shortly." for `maintenance_title` /
  `maintenance_brief`, and `BundledTranslations` seeds `en` alongside `af`
  so `AppHelpers.getTranslation` reaches the copy before humanizing.
  `bundledLocales` now lists `en`; `fallbackLanguages()` still lists
  English once. A served row always wins, as before.
* Fixed: `TranslationSeeder` offered the humanized key as a key's English
  value even when an SDK had registered real `en` copy for it
  (auth_sdk's `reset_password_text` boot hook, now the kernel's own map),
  so an unseeded backend was planted with "Reset password text" /
  "Maintenance title" as the tenant's English. The `en` candidate row now
  takes the bundled `en` entry when one is registered and humanizes only
  the rest; what the seeder offers is exactly what the UI renders.
  `test/translation_seeder_test.dart` covers both paths, the
  registry-level fallback, and the maintenance copy resolving through
  `getTranslation` on an unseeded `en` tenant.
* Added `DemoImages.avatar`: the demo account's initials avatar as an
  inline `data:` SVG on the same amber gradient as `DemoImages.shopMark`.
  auth_sdk's `MockAuthRepository` and users_sdk's `MockUserRepository`
  each carried their own copy of the literal because the kernel had no
  avatar entry and ADR-005 forbids one importing the other; both now read
  this constant. Covered by the `DemoImages` group in
  `test/inline_image_test.dart`.
* Added `TrKeys.resetPasswordPhoneText` (`reset_password_phone_text`) and
  `TrKeys.resetPasswordEitherText` (`reset_password_either_text`), so the
  reset-password sheet can pick copy that matches the app's sign-up type
  (auth_sdk 1.10.3 renders and bundles them).

## 1.60.3

* Fixed: demo builds print every amount in rand. The guided tour's wallet
  history read "42.50USD" / "1,500.00USD": `AppHelpers.numberFormat` takes
  its symbol and position from `LocalStorage.getSelectedCurrency()`, which
  a real build fills from the backend's currency list
  (`CurrencyNotifier.fetchCurrency`) and which nothing in a demo build ever
  sets - so intl fell through to its locale default, the ISO code as a
  suffix - while every seed fixture in the fleet trades in rand (the demo
  account is in Sandton, the wallet ledger cashes out to a South African
  bank, the seeded shops and orders carry ZAR). New
  `lib/src/constants/demo_currency.dart` (`DemoCurrency`, exported from the
  barrel) owns the one copy of that currency for the kernel - id `ZAR`,
  symbol `R`, rate 1, position `before`, field for field the currency the
  seller-side demo fixtures already carry - and
  `BaseSdkDependencies.register` seeds it into `LocalStorage` in a demo
  build where nothing is selected (the seller-side SDKs each did this from
  their own DI; now every composed shell gets it from the kernel). As a
  second seam, `numberFormat` falls back to `DemoCurrency.fallback` while
  the store is empty, so a demo build cannot print the ISO-code suffix even
  if the store is cleared under it. Both seams are inert in a real build:
  the seed is `AppConstants.isDemo`-gated and never overwrites a selected
  currency, and a real build with nothing selected keeps intl's own default
  until the backend's list is stored. `DemoCurrency.isDemoOverride`
  (`@visibleForTesting`) lets a test stand in a demo build. New
  `test/demo_currency_test.dart` guards the fixture, the seed (stores once,
  never overwrites, no-op outside demo) and the rendered strings
  ("R1,500.00", "R42.50").

## 1.60.2

* Fixed: demo builds no longer show the red Offline pill in the profile
  footer (the demo build has no backend, so the connectivity signal was
  always false). `ProfileMetaRow`'s Online/Offline dot read
  `AppConnectivity.backendAvailability()`, a real `api_status` probe of
  the tenant backend, which under `--dart-define=IS_DEMO=true` can only
  ever fail - so every demo build, and the guided tour's profile still,
  drew Offline. The dot now resolves as connected when
  `AppConstants.isDemo` is true, without probing; real builds are
  unchanged. The probe itself is untouched, since the splash boot and
  `ConnectivityService` read it to gate the outbox drain and the
  translation fetch and must keep seeing the backend as it is.
  `ProfileMetaRow.isDemoOverride` (`@visibleForTesting`) lets a test stand
  in a demo build, since the constant is fixed at compile time.

## 1.60.1

* Removed: `base_no_connection` and `base_maintenance` steps from the base
  tour fragment (no-connection and maintenance pages are not part of the
  guide).

## 1.60.0

* **The UI-type picker is gone.** `UiTypePage` - the four-tile grid at
  `/ui-type` that let a user tap a home style - is deleted, along with its
  `UiTypeRoute` host shell in `templates/routes/route_pages.dart`, its
  manifest `routes` entry, and the `replaceUiTypeRoute` seam (removed both
  from the `AppRoutes` interface and from the manifest's `app_routes`). The
  `base_ui_type` step is dropped from the tour fragment, since the screen it
  captured no longer exists.
* The UI type itself is untouched, and every reader still works:
  `AppHelpers.getType()`, `title.dart`, `shop_request.dart`.
* What changes is where the value comes from. `getType()` used to read a
  per-device pick out of `LocalStorage` on demo builds, and that pick had
  exactly one writer - the picker. With the picker gone it would have been a
  stale choice with no way to change it, so `getType()` no longer consults
  stored state at all. Resolution is now **backend, then `AppConstants`**:
  the tenant's `ui_type` design setting wins, and `AppConstants.uiType`
  (new; `--dart-define=UI_TYPE`, or a home-SDK manifest `constants`
  override) is the compose-time default. It defaults to 0, the same value
  the old code fell back to, so an app that overrides nothing is unchanged.
* **Consumers must drop every call to `AppRoutes.I.replaceUiTypeRoute`
  before taking this version.** auth_sdk 1.10.0 does; take it first.
* Everything that existed only for the picker goes with it: the four
  tile images `assets/images/ui0.png`..`ui3.png` (and their `app_assets`
  manifest entries, the explicit `templates/pubspec.yaml` asset line and
  the `Assets.imagesUi0`..`imagesUi3` / `assetsImagesUi3` constants),
  `LocalStorage.setUiType` / `getUiType` with `StorageKeys.keyUiType` (the
  picker was the key's only writer and `getType()` its only reader), the
  `TrKeys.uiType` (`ui_type`) translation key and its bundled Afrikaans
  string. The backend 'ui_type' design setting is untouched: it travels in
  the global settings list (`keyGlobalSettings`), not in the deleted key.

## 1.59.0

* Generic JSON key API on `LocalStorage`: `setJson(key, Map?)` /
  `getJson(key)` / `deleteJson(key)`. Every caller key is stored as
  `StorageKeys.keyHostRecordPrefix` (`hostRecord.`) + key, so a host-owned
  record can never land on one of the typed keys (`keyToken`, `keyUser`,
  `keyUiType`...). Null on `setJson` removes the key; `getJson` returns null
  for an absent, empty, corrupt or non-object value and never throws, the
  same read contract as `getShopJson`. The caller owns the schema and its
  versioning; nothing here is cleared by `logout()`.
  * The gap that motivated it: design 46e drew base_sdk's `LocalStorage` as
    the home of first-run setup progress (the store `getUser` / `getToken`
    / `setUiType` share), but the class exposed typed accessors only, so
    onboarding_sdk 1.1.0 opened its own SharedPreferences key
    (`onboarding.run`) instead. This is the API that lets that record move
    across.
* Typed convenience pair on top of it, in the file's per-feature style:
  `setOnboardingRun(Map?)` / `getOnboardingRun()` / `deleteOnboardingRun()`
  under `StorageKeys.keyOnboardingRun` (stored as
  `hostRecord.onboardingRun`). Untyped on purpose: the record's shape
  (`OnboardingRunRecord.toJson`) stays onboarding_sdk's, exactly as
  `setShopJson` leaves the shop's shape to the persona SDKs.
* New `StorageKeys.keyHostRecordPrefix` and `StorageKeys.keyOnboardingRun`.
  No new exports: `LocalStorage` and `StorageKeys` were already in the
  barrel.

## 1.58.0

* The generic profile host degrades to an ANONYMOUS MODE instead of
  throwing when the composing shell registers none of the account facades.
  `profileProvider` resolved `UserRepositoryFacade`, `ShopsRepositoryFacade`
  and `GalleryRepositoryFacade` through `getIt.get`, so a shell without
  users_sdk / merchants_sdk / products_sdk — radio composes radio_sdk,
  base_sdk, comms_sdk, telemetry_sdk, desktop_sdk and hms_sdk — threw
  `Bad state: GetIt: Object/factory with type UserRepositoryFacade is not
  registered` out of the page's first build.
  * `ProfileNotifier.fromLocator()` (now behind `profileProvider`) resolves
    each facade only where `GetIt.isRegistered`; the notifier's account,
    shop and gallery calls are no-ops for an absent facade. The positional
    constructor still exists and now accepts null for each facade.
  * `ProfileHostCapabilities { hasAccount, hasShops, hasGallery }` (new,
    exported) says what the shell registered; `ProfileNotifier.capabilities`
    carries it and the host reads it once at mount. `ProfileHostScope` (new,
    exported `InheritedWidget`) hands it to everything the page builds —
    read it from the widget's own build context.
  * With `hasAccount` false the host renders the anonymous surface: the
    brand ground, the top row (title, SDK actions, theme toggle) WITHOUT
    its sign-out, the shell's plan slot alone in the header card (no card
    while unclaimed; the planBack flip works as before), the registered
    sections, and the footer WITHOUT its usage badge — `AppUsageService`
    answers all zeros with no token, so the badge was permanently dead in
    a tokenless shell. No identity header, avatar, edit pencil, badge,
    stats or corner. Nothing on screen says why.
  * `ProfileSection.requires` and `ProfileHeaderSlotContent.requires` (new,
    default empty; `registerHeaderSlot` takes `requires:`) let an SDK
    declare the facades a contribution needs; the host omits it — before
    its `visible` gate runs — wherever one is missing. With only shops or
    gallery absent, that is the whole difference.
  * One `profile_host_anonymous_mode` event per process goes out over
    `TelemetryClient.logError` with `missing_facades` (the interface names)
    when the host first mounts anonymously.
  * Strictly additive: a shell that registers all three facades renders
    exactly as before — same widgets, same slot order, same footer;
    consumer apps need no re-check. `generic_profile_page_anonymous_test`
    covers the empty locator (no throw, anonymous layout, footer present,
    no badge, no sign-out), the account-only locator (identity header
    present, contributions requiring shops/gallery omitted, their gates
    never run), the full locator, and the once-per-process event.
  * Supersedes 1.57.0's thunk deferral: `profileProvider` now builds
    `ProfileNotifier.fromLocator()`, which guards every use site instead
    of throwing at first use in a token-without-facade compose; the
    `_lookUp*` thunks are gone and `ProfileNotifier.deferred()` stays as a
    forwarder to `fromLocator()` (resolved once, not lazily per call) so
    nothing compiled against 1.57.0 breaks. Keeps the radio-shaped
    empty-locator compose test from #153
    (`generic_profile_unbacked_compose_test`), which passes unchanged.

## 1.57.0

* `profileProvider` no longer resolves `UserRepositoryFacade`,
  `ShopsRepositoryFacade` and `GalleryRepositoryFacade` out of `get_it`
  when it BUILDS the notifier. `ProfileNotifier` now holds those three as
  thunks and a new `ProfileNotifier.deferred()` constructor - the one the
  provider uses - looks each one up at first USE instead.
  * The failure that motivated it: `GenericProfilePage` watches
    `profileProvider` on its first build, so in a compose that installs no
    SDK registering those facades - only users_sdk registers
    `UserRepositoryFacade`, only merchants_sdk `ShopsRepositoryFacade`, only
    products_sdk `GalleryRepositoryFacade` - the generic profile host threw
    `Bad state: GetIt: Object/factory with type UserRepositoryFacade is not
    registered inside GetIt` out of `build()` and the whole profile route
    came up as a full-screen debug `RenderErrorBox`. RokctAI/radio's guided
    tour published that flat `#440000` frame as its profile screenshot
    (run 33628026749, step 05) on both the phone and the tablet leg, and
    the exception failed the integration test that drives the tour.
    `launcher_auth_control.dart` already documented the same hazard and
    routed around this provider because of it; the host itself is
    advertised as knowing about no feature SDK (ADR-005), so it has to
    mount without them.
  * Nothing changes for a compose that DOES register them: the same lookup
    happens, one frame later, at the first call that needs a repository.
    The explicit `ProfileNotifier(user, shops, gallery)` constructor is
    untouched, so hosts and tests that hand their own implementations in
    are unaffected.
## 1.56.0

* Inline (`data:`) image support in `CustomNetworkImage` and `CommonImage`,
  plus the `AppHelpers.isInlineImage` / `isInlineSvg` / `inlineImagePayload`
  / `inlineImageBytes` helpers behind it. A URL that starts with
  `data:image/` is now rendered from its own payload - SVG markup through
  `SvgPicture.string`, raster bytes through `Image.memory` - instead of
  being handed to `CachedNetworkImage`, which can only fetch it over the
  network and therefore fell straight through to its broken-image error
  state.
  * The failure that motivated it: every mock repository in the commerce
    SDKs seeded its imagery from a public placeholder host, so in a demo
    build (`--dart-define=IS_DEMO=true`) - which talks to no backend, and in
    CI runs on an emulator with no dependable route to that host - each
    seeded shop, product, category, brand and banner rendered as the
    broken-image glyph. The guided tour captured that verbatim into
    published store screenshots.
* New `DemoImages` (`src/constants/demo_images.dart`): the shared inline
  artwork the demo seed data points at - a shop cover, a shop/brand mark, a
  product tile, a category tile and a promo banner, all deliberately
  abstract so a screenshot never implies a real merchant. Nothing outside
  demo builds reads them.

## 1.55.0

* `AppHelpers`' four top-snackbar helpers — `showCheckTopSnackBar`,
  `showCheckTopSnackBarInfo`, `showCheckTopSnackBarDone`,
  `showCheckTopSnackBarInfoCustom`, and so the `errorSnackBar` alias —
  resolve their overlay with `Overlay.maybeOf` and return without showing
  anything when the calling context has no `Overlay` ancestor. They used
  `Overlay.of`, which ASSERTS in that case and throws straight through the
  caller: a toast, which is decoration, could take down whatever asked for
  it. Behaviour is unchanged wherever an `Overlay` is in scope, and the
  signatures are untouched.
  * The failure that motivated it: the guided tour hands the helpers a
    context taken from `find.byType(Navigator).first`, whose `Overlay` is a
    DESCENDANT rather than an ancestor. The assert fired inside the sign-in
    step's rejection path and killed the whole integration-test run: every
    step after sign-in went unexecuted, 4 of 19 screenshots were captured,
    and the failure surfaced as a stack trace inside an SDK toast helper
    rather than as the sign-in outcome it actually was.
  * `top_snack_bar_overlay_test.dart` covers all four helpers plus the
    alias against an overlay-less context, and asserts a toast still
    renders when an `Overlay` IS in scope.

## 1.53.0

* `PlaneSpan` grows a fourth claim, `twoIfSpare`: **one plane, and a
  second one only if it would otherwise sit empty**. Every existing
  claim demands a plane count up front — `one`, `two`, `all` — so a page
  wanting a second plane had to take it from the flow beneath. This one
  asks for one plane like any default page and is then GRANTED a
  leftover by `PlaneHost`, out of what would have been the empty stage.
  A page beneath is never displaced to arrange it.
  * `PlaneSpan.claimFor` returns 1 for the new claim — it is the claim
    the page MAKES. The new `PlaneSpan.growthCapFor` returns the most it
    can ever hold (two), and is identical to `claimFor` for every claim
    that does not grow, so nothing about `one` / `two` / `all` changes.
  * `PlaneHost` allocates the active page's claim, serves the earlier
    pages by their own claims exactly as before, and only then lets a
    growing claim absorb what is still unallocated, capped at two. On a
    three-plane screen with one page beneath, that is `earlier | active
    active`; on a two-plane screen, `earlier | active` — the earlier
    page keeps its plane either way.
  * `allowNeighbors: false` now clamps the visible planes to the growth
    cap rather than the bare claim, and a page that refuses neighbours
    is given none (previously the clamp made the two identical, so this
    is only reachable through a growing claim).
  * The motivating adopter is lms_sdk's lesson session (frame 52): the
    board and the attendees panel are two halves of one page, and the
    schedule beneath must keep its plane at two planes while the third
    plane, at three, becomes the attendees half instead of empty space.
  * 6 new tests in `planes_test.dart` cover the claim at one, two and
    three planes, a full flow beneath leaving nothing spare, the page
    alone (grows to two, never to all), and the no-neighbours clamp.
    Package suite: 206 passing, 0 failing (200 before), verified against
    Flutter 3.47.2 / Dart 3.13.2.

## 1.51.0

* REGRESSION FIX: `main` did not compile after 1.49.0 (core#137), which
  took 7 test files down with it. 1.49.0's tests were written but never
  executed — no Dart/Flutter toolchain was available when it was authored
  — so two compile errors shipped. This release only repairs them; no
  memory-pressure or paging behaviour changes. Version note: 1.49.0 is
  on `main` and core#138 declares 1.50.0, so this takes the next free
  number above both.
  * `services/memory_pressure_service.dart` did not import
    `package:flutter/services.dart`. Its import comment asserted that
    `package:flutter/widgets.dart` "re-exports painting.dart and
    services.dart in full"; widgets.dart exports `src/widgets/*` only,
    so `MethodChannel` and `MissingPluginException` were both undefined
    and the library failed to compile:
    `Error: Type 'MethodChannel' not found.` Because `base_sdk.dart`
    exports the service, every test importing the barrel went down with
    it — `app_usage_badge`, `base_wallet_card`, `floating_nav_back`,
    `money_keypad` and `theme_mode_sync` — plus `memory_budget`, which
    imports the file directly. The import is added and the comment
    corrected to say what widgets.dart actually exports.
  * `test/sync_engine_paging_test.dart` imported `package:drift/drift.dart`
    unfiltered alongside `flutter_test`. drift exports `isNull` and
    `isNotNull` as SQL expression builders, which collide with matcher's
    identically-named ones that `expect` needs:
    `Error: 'isNotNull' is imported from both ...`. The test was wrong,
    not the paging code — it asserts real behaviour and now runs. drift's
    two names are hidden at the import; neither is used in the file.
  * Both new suites from 1.49.0 now actually execute: 9 `budgetFor` tier
    tests and 12 outbox paging tests. The package suite is 194 passing,
    0 failing, verified against Flutter 3.38.5 / Dart 3.10.4.

## 1.50.0

* `SavedCardModel` DROPS its `token` field. `Saved Card.token` is the
  gateway reuse credential — presenting it to the gateway charges that
  card again — and pay made it a Frappe `Password` field, so
  `get_saved_cards` and `tokenize_card` stopped returning it. The field
  was therefore always-empty from the moment that landed, and an
  always-empty credential field is how a caller silently sends nothing
  and gets a refused charge. Removing it makes the compiler catch that
  instead: every consumer of `card.token` in the fleet now fails to
  build until it is pointed at `card.id`.
  * REQUIRES pay's saved-card confinement (pay#46) on the backend. The
    charge endpoints key on the Saved Card docname; a client that still
    sends a credential is refused WITHOUT being charged, so the failure
    mode is a saved-card payment that stops working, never a wrong
    charge.
  * `fromJson` now reads the docname from `name` as well as `id`
    (`json['id'] ?? json['name']`). `get_saved_cards` and `tokenize_card`
    name it `name`; without the fallback `id` came back empty and every
    charge keyed on it was refused. Callers that already normalise to
    `id` are unaffected — `id` still wins.
  * `toJson`, `copyWith` and `toString` lose `token` with it. `toString`
    used to interpolate the credential, so a card printed into a log
    carried it there too.
  * `PaymentsRepositoryFacade.processTokenPayment` and
    `WalletRepositoryFacade.walletTopUp` keep their parameter names for
    source compatibility with the shipped implementations, but both are
    documented for what they now carry: the Saved Card docname, i.e.
    `SavedCardModel.id`. No signature changed, so no implementation
    needs touching for this.

* comms (whatsapp): the card checkout no longer reads
  `Saved Card.token`. The button payload already encoded the docname as
  `card_<name>`, so the lookup that turned it back into a credential was
  overhead before the change and returns a mask after it. The docname is
  passed straight to `process_token_payment(saved_card=...)` and the
  lookup is deleted. Fail-closed is preserved and moves server-side: an
  unknown card, or another user's card, refuses before any gateway call
  rather than being reported as paid.
  * New standalone suite
    `comms/frappe/tests/test_whatsapp_saved_card_charge.py` (6 tests;
    3 fail against the pre-change checkout). Needs Python 3.12+ —
    checkout.py contains a PEP 701 multi-line f-string.

## 1.49.0

* ANDROID PLAY QUALITY + RESTORE CREDENTIALS (the 2026-08-26 Play quality
  requirements). Nothing in the fleet reacted to memory pressure, three
  code paths read whole tables into memory, and there was no Restore
  Credentials plumbing. Version note: 1.47.0 landed on `main` with
  core#135 and 1.48.0 with core#136, so this work takes the next free
  number above both.
  * New `services/memory_pressure_service.dart` (exported):
    `MemoryPressureService` sizes Flutter's image cache from the device's
    actual RAM (32MB/200 images below 3GB, 48MB/300 to 4.5GB, 72MB/400 to
    7GB, 96MB/500 above; an unreadable figure falls back to the 4GB tier)
    over a small `DeviceMemoryBridge` method channel, and acts as the one
    registry other SDKs add handlers to — `MemoryEvent.pressure`,
    `.background`, `.resume` — instead of each wiring its own lifecycle
    observer. It evicts the image cache (including `clearLiveImages()`)
    on pressure and on backgrounding, and releases the retained preload
    `WebViewController` on background, re-warming it on the next
    foreground; a controller a `WebViewPage` has adopted is never
    touched. Started from `BaseSdkDependencies.register` and
    exception-guarded end to end: a memory optimisation must never be
    what stops an app booting. Every tier sits at or under Flutter's
    fixed 100MB default, so this can only lower the ceiling.
  * BOUNDED READS. `SyncEngine`'s outbox drain and its temp-id rewrite
    pass, and `AppDatabase.getAll`, no longer materialise whole tables.
    Keyset paging on the immutable `(createdAt, id)` key rather than
    `OFFSET`, because rows change status and are deleted mid-pass. The
    dependency check looks up only the ids the current page declares,
    selecting the id column alone. Bounding each page to rows created at
    or before the pass start reproduces the old single-SELECT snapshot
    boundary. Oldest-first ordering, `dependsOn` gating and the
    `enqueueOrReplace` idempotency contract are unchanged; `getPage`,
    `getAllPaged` and `countBox` are additive and `getAll` keeps its
    contract. One honest difference: the temp-id rewrite now reaches ops
    later in the same pass instead of waiting for the next `kick()`.
  * New `AppDatabase.releaseMemory()` — `PRAGMA shrink_memory`, wired
    into the same background/pressure path. The drift connection is
    deliberately NOT closed on background: `AppDatabase` is a
    process-wide singleton other SDKs hold directly, and `kick()` has no
    awaitable quiesce, so a half-closed database would be worse than an
    open one.
  * New `services/restore_credential_service.dart` (exported) — the
    client half of Restore Credentials over channel
    `rokct.base_sdk/restore_credentials`: `isSupported`, `create`,
    `retrieve`, `clear`, `consumeRestoreSignal`, plus
    `createRestoreKey`/`getRestoreKey`/`clearRestoreKey` carrying
    auth_sdk's `RestoreCredentialPlatform` signatures. Safe on every
    platform — non-Android, Android below 9 and a shell that has not
    registered the channel all return `unsupported` rather than throwing.
    `requestJson` is passed through untouched. Nothing is wired into
    login, register or logout; that is auth_sdk's side.
  * Android template (new shells only — the installer never overwrites an
    existing host file): `targetSdkVersion` 35 to 36; the release build
    switches to `proguard-android-optimize.txt` and the broad keeps gain
    `allowoptimization`, which preserves every kept name while letting R8
    optimize method bodies; new `res/xml/data_extraction_rules.xml` and
    `res/xml/backup_rules.xml` exclude the sqlite database and its
    WAL/SHM/journal siblings, the Flutter SharedPreferences file and the
    `flutter_secure_storage` prefs and key-storage files from BOTH cloud
    backup and device transfer, closing a live credential-exposure path;
    `androidx.credentials` 1.5.0 declared explicitly; new
    `RestoreCredentialBridge.kt` (with the native `E2eeUnavailable`
    retry) and `RokctBackupAgent.kt`, whose `android:backupAgent` is
    paired with `android:fullBackupOnly="true"` — they must stay
    together, or the app falls back to key-value backup and both XML rule
    files are ignored.
  * Tests: `sync_engine_paging_test.dart`, `kv_store_paging_test.dart`,
    `memory_budget_test.dart` — drain ordering across pages, `dependsOn`
    gating within and across pages, the backoff window, retryable
    handling, the temp-id rewrite beyond the first page, the dedupe
    contract, the key/value paging primitives and the cache tier
    boundaries.

## 1.48.0

* THE SPLASH CAN NO LONGER BE A DEAD END. Every consumer app boots through
  `SplashPage`, and every route it hands the screen to is a method some
  installed SDK has to declare — a composition that declares none threw a
  `StateError` out of the host's `_HostAppRoutes.noSuchMethod`, from inside
  an un-awaited `getToken` call where nothing caught it. The app removed
  the native splash and then sat on the splash artwork with no error, no
  telemetry and no way forward. Behaviour is unchanged for every app whose
  routes do resolve; what changes is what happens when one does not.
  * `getToken` is now AWAITED: a navigation failure reaches the existing
    catch instead of vanishing into an orphan future.
  * New `_leaveSplash` wraps every hand-off. On failure the cause goes to
    the one telemetry door (`TelemetryClient.logError`, gateway cmd
    `tenant.api.log_frontend_error`) as `splash_navigation_failed` with the
    destination, the verbatim error and whether a `BASE_URL` was compiled
    in at all, and the boot falls back to the no-connection page, then to
    an in-place stand-in (app name, one friendly translated line, Try
    again). Per the standing error-surface rule the screen gets the
    friendly line only — never the diagnostic detail.
  * A backend the `api_status` probe already reported DOWN no longer gets
    asked for translations. That request could not succeed and cost up to
    two 30s dio timeouts (the repository retries under the control-role
    cmd), so an app with no backend behind it sat on the splash for up to a
    minute before starting from exactly the local data it already had. The
    skip is reported as `splash_backend_unreachable`.
  * `SplashNotifier.getToken` gained the missing `else`: when
    `connectivityWithDialog` says no, it now calls the caller's
    `goNoInternet` callback. A dialog is not a destination — without this,
    a device that dropped its network between the splash's own check and
    this one invoked no callback at all and the splash stayed up. Callers
    that pass no `goNoInternet` behave exactly as before.
  * Test: `splash_boot_test.dart` — an unreachable backend reaching a real
    screen, the skipped translations fetch, the telemetry/screen split, the
    two missing-route fallbacks, and the notifier's radio-off branch.

## 1.47.0

* Dark-mode fix — `GenericProfilePage`'s sign-out confirmation had an
  INVISIBLE Cancel button on every dark host. `_confirmLogout` raises a
  plain Material `AlertDialog` with no explicit background, so in a dark
  app it renders on the theme's dark dialog surface (#2B2930 under
  `ThemeData(brightness: Brightness.dark)`) — against which the button's
  pinned `AppStyle.black` (#232B2F) label AND outline measure 1.00:1.
  Not "hard to read": the whole control was absent, leaving a sign-out
  confirmation whose only visible button was the one that signs you out.
  Both now ride `AppStyle.textPrimary`, so the outlined Cancel reads in
  both polarities (14.36:1 dark, 17.15:1 light). Affects the manager hub
  and every other dark host of the page.
* Test: `profile_logout_dialog_contrast_test.dart` — opens the real
  confirmation from the page's sign-out button, MEASURES the rendered
  dialog surface rather than assuming it, and holds the Cancel label and
  outline to the WCAG 1.4.3 4.5:1 floor in both polarities. Fails on the
  pre-fix tree at 1 passed / 2 failed.
* `TitleAndIcon`'s pinned `titleColor` default is deliberately unchanged.
  Flipping that shared default to a resolving token would trade this bug
  for its mirror: `ModalWrap` sheets paint `AppStyle.white.withOpacity(0.9)`
  and roughly 90 fleet call sites render `TitleAndIcon` on them, which
  would go white-on-white in dark mode. A dark-surfaced host passes the
  resolving token itself; the fix belongs at the call sites.

## 1.46.0

* THE STANDARD LIST LANGUAGE (approved design strip section 38, Ray
  2026-08-30 12:23Z: "33 list language = STANDARD for all lists"). Frames
  38a-38d draw the approved section-33 list mode on three shipped,
  undesigned manager list screens (order history, notifications, sync
  issues); approving them approves the LANGUAGE, not just those screens.
  Its consumers sit in three feature SDKs across two repos and a feature
  SDK may only import `base_sdk` (ADR-005), so the language lives here.
  * New `presentation/components/lists/list_language.dart` (exported):
    `ListFilterTabBar` + `ListFilterTab` + `ListTabCountPill` — the
    colour-coded tab row with per-tab count pills and the tinted-fill
    active treatment (chips 362/363, the 33b treatment expressed over an
    SDK-neutral tab model); `ListCountPill` — the list-header count pill,
    the standard slot on every list (chip 700); `ListRoundAction` — the
    33a header utility disc; `ListScreenHeader` — title + count pill +
    round utilities, with the optional needs-attention hint line (chip
    711); `ListViewMore` — the "View more · +N" paging foot (chip 356).
  * New `presentation/components/lists/list_plane_flow.dart` (exported):
    `ListPlaneFlow` / `ListDetailFlow<T>` — the section-38 plane shape.
    The list DECLARES TWO planes; a tapped row's detail is a pushed page
    with the DEFAULT one-plane claim, so it lands in the LAST plane (the
    12:02Z SHEET FORK — at plane widths the shipped bottom sheet becomes
    a pane) and the nav folds to the corner back pill at the bottom-END
    (chip 347, the 12:36Z two-state nav rule); alone at a three-plane
    width the leftover plane TRAILS BARE (Ray 10:47Z) instead of the list
    stretching. `ListPlaneColumns` lays a list body out in exactly its
    granted planes' worth of columns, collapsing to one on a phone (38d).
  * Test: `list_language_test.dart` — the tab bar's counts/active
    treatment/tap reporting, View-more's appear-and-page rule, the
    two-plane declaration, the last-plane detail claim, the corner pill's
    pop-and-restore, and the plane-aligned columns in both folds.

## 1.45.0

* The shared edit-own-details sheet (approved frame 4d, 2026-08-30 —
  chips 725-734): marketplace_sdk's shipped customer `EditProfileScreen`
  (edit_profile_page.dart, 381 lines, base_sdk imports only) is PROMOTED
  here as `src/presentation/pages/profile/edit_profile_sheet.dart`, so
  every host of `GenericProfilePage` can wire the user-card edit pencil
  (chip 109, `ProfileSectionRegistry.I.onEditProfile`) to the one
  shipped flow — the immediate consumer is merchants_sdk's manager hub,
  whose user card had NO edit-own-details path (the PR #80 chip-243 move
  exposed the gap Ray reported). Field list is the shipped screen's,
  verbatim: drag handle, "Profile settings" title, avatar with the
  photo-change pencil, EMAIL (read-only once valid), FIRSTNAME |
  SURNAME, PHONE NUMBER (read-only, phone-verify flow), DATE OF BIRTH
  picker, GENDER dropdown, Save. The save path was already base_sdk's
  own (`editProfileProvider` -> `UserRepositoryFacade.editProfile` ->
  the self-scoped `update_user_profile` endpoint) — NO backend change.
  Promotion adaptations only: the light-only bgGrey@96% chrome resolves
  the dark surface via `AppStyle.isDark` (the 4d dark render), and the
  photo-pencil glyph moves to base_sdk's `remixicon`
  (`Remix.pencil_line`, unchanged glyph) with explicit ink so it reads
  on its white disc in both modes.
* Test: `edit_profile_sheet_test.dart` — the sheet renders the shipped
  field set from `profileProvider`'s user, and Save drives
  `EditProfileNotifier` end to end into `UserRepositoryFacade
  .editProfile` (recording fake repository; stubbed connectivity).

## 1.44.0

* THE KEY PAD (design chip 390) as a SHARED component — approved on
  frame 11u (tablet checkout, 2026-08-29 15:41Z) and frame 11y (phone
  fold, 2026-08-30 11:27Z); Ray's standing direction makes it the
  standard money-entry surface fleet-wide, so it lives here in the
  package every app composes (the TelemetryClient precedent).
  * New `MoneyKeypad` (`presentation/components/keypad/money_keypad.dart`,
    exported): the 11u/11y pad — 1–9 / 00 / 0 / ⌫ digits grid (the `00`
    money key carried from the paas_pos tender pad) plus the optional
    `.` | OK confirm row. A pure input surface: emits key events, owns
    no text, focuses nothing — the OS keyboard can never appear behind
    it. `MoneyEntry` carries the shared append/backspace/decimal money
    string rules so every adopter edits identically.
  * New `KeySound` service (`services/key_sound.dart`, exported): the
    paas_pos tender-pad sound recipe — `tap()` on EVERY keypress plays
    `assets/audio/tap.wav` (Ray's own paas_pos asset, copied verbatim)
    through a round-robin pool of 5 audioplayers `AudioPlayer`s (rapid
    keying never truncates a click) with `HapticFeedback.lightImpact`
    as the mobile complement; `error()` plays `wrong.wav` (paas_pos's
    insufficient-tender buzz) with a medium haptic. Both behind ONE
    persisted on/off gate, DEFAULT ON
    (`LocalStorage.get/setKeypadSound`, `StorageKeys.keyKeypadSound` —
    paas_pos `AppConstants.sound` parity). Fails open everywhere: no
    asset, no plugin, test binding — silence, never an exception.
  * Assets: `templates/assets/audio/tap.wav` + `wrong.wav` registered
    in `app_assets` and the host pubspec template's asset dirs gains
    `assets/audio/`; new direct dependency `audioplayers: ^6.5.1` (the
    templates/comms constraint rail).

## 1.43.0

* The approved 4c ruling ("will just let profile take two plane max.
  back be on the right"):
  * `GenericProfilePage` self-spread caps at TWO planes, UNIVERSALLY:
    the cap lives in the page itself, so every host of the generic
    profile (customer, merchant, lms, ...) is bound by it — no
    `PlanePage` declaration can spread the profile to three columns.
    Declare the profile's page as `PlaneSpan.two` (never `all`) so at a
    three-plane width the third plane follows the normal plane rules —
    a bare stage or a flow neighbor. Two-plane and phone layouts
    unchanged.
  * The plane layout's back pill moves from the bottom-START corner to
    the BOTTOM-END corner — the right corner in LTR, still directional
    (leads left in RTL), same 16-logical inset inside the SafeArea.
    Pop semantics unchanged: the pill pops the flow's newest step.

## 1.42.0

* The plane mechanism (the approved plane proposal, frame 1c, plus the
  approved yield/back interaction ruling). New
  `presentation/adaptive/planes.dart`:
  * `PlaneHost` divides a wide window into 1 / 2 / 3 EQUAL-WIDTH planes
    by real logical width on the shared `AppBreakpoints` thresholds
    (< 600 one, 600..839 two, >= 840 three) and windows the user flow
    (`stack`, root first, last entry active) onto them — the deepest
    step always in the LAST plane.
  * `PlanePage` declares its claim in planes (`PlaneSpan.one` — the
    default — `two`, or `all`) and whether earlier pages may sit beside
    it (`allowNeighbors`; false presents the claim alone). Claims are
    never demoted while planes exist; a claim >= the screen's count is
    the full screen; a one-plane screen is the phone layout by
    construction.
  * Importance is dynamic: the ACTIVE page's claim wins, and earlier
    pages YIELD BY COMPRESSING — the page under the active step keeps
    the remaining planes up to its own claim and re-spreads onto them,
    the next outward after that, the rest slide off. BACK pops the
    newest step and the planes return (back restores).
  * `Planes.of(context)` — inherited `.count`/`.index`/`.span` (plus
    `planeWidth`/`gap`/`isLast`) so any page can subscribe and re-flow
    on allocation changes, no polling.
  * The plane layout's back control: `PlaneHost.back` parks the new
    `FloatingBackPill` (the approved `FloatingNavBack` segment in the
    pill's own housing, placement-free) at the BOTTOM-START CORNER —
    directional, so it trails right in RTL; 16 logical in from both
    edges — whenever the flow is deeper than its root (the approved
    ruling: "back button should always be at a corner"). Tapping it
    pops the NEWEST step of the flow — the last plane's content —
    never a spread earlier page. One back per screen: apps whose
    floating nav bar already carries the back segment pass null.
* `GenericProfilePage` self-spread (approved frames 1c and 1f): granted
  planes by a `PlaneHost` above, the page spreads its content across
  them — the registry's ordered sections in balanced contiguous columns
  (three at three planes, two at two), the identity header leading the
  first, the top controls row spanning the full grant, one scroll
  position. Without a `PlaneHost` (or on one plane) the phone list
  renders untouched. Sheets and dialogs never take planes — they
  overlay, exactly as on the phone.
* `AppUsageBadge`'s label now ellipsizes instead of overflowing when
  its surface is narrow (a plane-spread profile column).

## 1.41.0

* Sync drain is now gated on BACKEND availability, not just device
  connectivity. Both automatic `SyncEngine.kick()` triggers — the splash
  boot path and the `ConnectivityService` regain listener — previously
  fired on radio state alone, so a Wi-Fi network without internet (or a
  reachable internet with the tenant backend down) drained the outbox
  into guaranteed failures, burning retry attempts toward the dead cap.
  The splash path reuses the `api_status` probe it already runs
  (`AppConnectivity.backendStatus`) and only kicks when the backend
  answered `up`; the regain listener now confirms
  `AppConnectivity.backendAvailability()` (on-demand check, never
  polled) before kicking. Manual/enqueue-path kicks are unchanged.
  `ConnectivityService` gains test seams (`backendProbe`,
  `onBackendRegained`, `handleConnectivityChange`) and unit coverage
  for the gate.

## 1.40.0

* First application of the approved floating-nav back pattern (design
  strip section 12 "APPROVED", shipped as `FloatingNavBack` in 1.39.0 /
  core#125) to base_sdk's own screens: `UiTypePage` now renders the
  floating nav's back segment as its ONE back affordance when pushed —
  the standalone `PopButton` is gone and the AppBar no longer implies a
  leading arrow, ending that screen's double back. Back-only pill (empty
  tab list): the page belongs to the initial flow and carries no root
  tab set.
* `FloatingBottomNav`: a back-only pill or rail (back passed, tabs and
  trailing both empty — the no-tab-set apps' pushed routes) no longer
  draws the back/tabs hairline; there is nothing to split from. Pills
  with tabs render exactly as before.

## 1.39.0

* Floating nav: tabs mode gains an optional leading BACK segment (the
  approved floating-nav back proposal — design strip section 12, "no
  double back buttons"). New `FloatingNavBack` value on
  `FloatingNavTabsMode.back`: caller-supplied icon + already-translated
  label (base_sdk stays icon-set- and copy-agnostic), `onTap` defaulting
  to `Navigator.maybePop` when null. `FloatingBottomNav` renders it as a
  leading segment — PopButton's exact visual DNA (chevron + 12sp label +
  the 4x24 brand-primary dash) moved inside the pill housing, split from
  the tabs by a hairline, on the tabs' own 45.h row rhythm — and, in a
  tablet-mode side rail, stacked at the rail's start the way the rail's
  tabs are. This is the bar's ONE deliberate navigation exception:
  `trailing` stays "never navigation", and the back segment never takes
  the active indicator. A page that passes `back:` renders no back
  affordance of its own (no floating PopButton, no AppBar leading), so
  exactly one back exists per screen. `back` null — the default — renders
  every existing host exactly as before.

## 1.38.0

* Real dark-mode wiring for the composed app shell ("all sdks should have
  darkmode"). The installed `app_widget.dart` template now builds a genuine
  `darkTheme:` from the AppStyle dark palette (new polarity-pinned
  `AppStyle.surfaceDarkRaw`/`surfaceLightRaw` getters, which track
  `injectBrandColors` but never flip with the current mode), making the
  existing `themeMode:` line live instead of inert. `AppNotifier` now calls
  `AppStyle.setBrightness` when it reads the persisted preference at startup
  and on every `changeTheme`, so the AppStyle-driven surfaces and the
  Material tree agree from the first frame (previously `AppStyle.isDark`
  stayed at its dark-first default on cold start regardless of the stored
  preference). New `AppTheme.defaultDarkMode` static seam (kernel default:
  light) — consulted by `LocalStorage.getAppThemeMode()` only when no
  preference is stored, so dark-first apps (driver, manager) set it `true`
  in app glue before `runApp` to keep their current look; the user's
  explicit choice always wins thereafter.
* All `AppStyle` font helpers (`interBold`/`interSemi`/`interNoSemi`/
  `interNormal`/`interRegular`, `logoFont*`, `logoMotto*`) now default
  `color:` to the mode-resolving `AppStyle.textPrimary` instead of the fixed
  `AppStyle.black` — the ~929 fleet call sites that omit `color:` were
  near-invisible on dark surfaces. Call sites that pass a color explicitly
  are untouched (the parameter is now nullable; a passed value always wins).

