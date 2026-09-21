## 1.2.1

* Fixed: every step of first-run setup now follows a theme-mode flip while it
  stays on screen, instead of keeping the previous mode's colours until
  something else happens to rebuild it. The whole page tree decided its page
  surface, its cards, its hairlines and its ink from `AppStyle.surfaceDark` /
  `AppStyle.cardDark` / `AppStyle.cardDarkAlt` / `AppStyle.strokeDark` /
  `AppStyle.textDarkSecondary` / `AppStyle.textPrimary` — mode-resolving
  statics that answer from the app-wide `AppStyle.isDark` flag, which is not an
  inherited widget, so a mode change scheduled no rebuild of any element in
  here. Nothing on the path registered a dependency the flip reschedules
  either: the scaffold's only other `BuildContext` read was
  `MediaQuery.sizeOf` (through base_sdk's `windowSizeOf`), which answers to the
  WINDOW and not the mode, and the `introProvider` notifier `IntroPage` watches
  is a feature notifier a theme-mode change never notifies. Nor could a parent
  deliver it: the composer's embedded-widget slot hands auth_sdk's `LoginPage`
  `const OnboardingIntroRouteView()` and the login page paints the one captured
  `_slots.introPage!` instance it was given, so `Element.updateChild` is handed
  an identical widget and never rebuilds it.
* Thirteen builds are fixed, all of them the same way: each reads
  `Theme.of(context).brightness` ONCE, in `build` and outside every inner
  builder, and names its colours through base_sdk 1.66.6's brightness-taking
  `AppStyle` role helpers — `inkFor`, `secondaryInkFor`, `surfaceFor`,
  `cardFor`, `cardAltFor` and `strokeFor`. The subjects are the shared frame
  (`_OnboardingScaffold`, `_OnboardingCard`), the steps (`_WelcomeCard`,
  `_WelcomeCarousel`, `_RoleChoice`, `_RoleCard`, `_StepFooter`, `_Done`), the
  position rail (`_RailHeader`, `_CompactRail`, `_FullRail`, `_RailRow`) and
  the standalone `WelcomeText` banner. The rail's `_fillFor` helper takes the
  brightness its caller looked up rather than reading a static of its own.
  No colour value changed in either mode, and no helper was added to base_sdk.
* Untouched on purpose, so nobody "fixes" them later: the polarity-pinned
  members these files also read — `AppStyle.primary` (the brand glow, the Skip
  pill, role and step icons, the current-step segment and row wash),
  `AppStyle.white`, `AppStyle.black`, `AppStyle.blackColor` and
  `AppStyle.green` (the done tick and each passed step's outcome). Those name
  one colour each and take no mode at all.
* `intro_page_theme_mode_test.dart` is a real widget test per subject, twelve
  of the thirteen: it mounts the real `IntroPage` behind a captured-instance
  boundary, walks the run to the step under test, flips `AppStyle
  .setBrightness` plus the Material `themeMode` the way `AppNotifier
  .changeTheme` does, and pumps without remounting.
  `welcome_text_theme_mode_test.dart` does the same for `WelcomeText`, standing
  a one-pixel bundle in for the host artwork no SDK package ships.
  `theme_flip_host.dart` carries the host shape, mirroring core's
  `base/dart/test/theme_flip_host.dart` (which lives in base_sdk's own `test/`
  directory and so cannot be imported from here).
  `onboarding_theme_mode_guard_test.dart` covers `_WelcomeCarousel` on the
  source instead, and says why: it is gated behind `const bool
  kShowWelcomeCarousel = false`, a compile-time constant with no seam to
  override, so no test in any package can mount it. The same file carries a
  regression net over the whole package.
* pubspec 1.0.2 → 1.0.3.

## 1.2.0

* The run record moves into base_sdk's `LocalStorage` — the home design 46e
  drew for it, the same store `getUser`/`getToken`/`setUiType` use. 1.1.0
  left this as debt because `LocalStorage` had no generic key API; base_sdk
  1.59.0 adds `setJson`/`getJson`/`deleteJson` (host records under the
  `hostRecord.` prefix) and the thin `setOnboardingRun`/`getOnboardingRun`/
  `deleteOnboardingRun` wrappers on top, and this SDK now requires it
  (manifest `_comment_requires`). The record shape stays here
  (`OnboardingRunRecord.toJson`); base keeps it untyped and never clears it
  on logout — setup progress is per install, not per session.
  * `SharedPreferencesOnboardingProgressStore` (own key `onboarding.run`) is
    replaced by `LocalStorageOnboardingProgressStore`, the new
    `IntroDeps.store` default. Same three calls, same fallbacks: absent,
    empty, corrupt or foreign records start fresh; finishing the run clears
    the record.
  * **One-time move** (46h, ruling three): the first `read()` that finds
    nothing under the base key carries a 1.1.0 record across — read the old
    key, write the same JSON to the base key, delete the old key, in that
    order, and the old key is dropped only once the copy reads back. An
    install that closed mid-setup on 1.1.0 resumes at the same step after
    the upgrade; a corrupt legacy record starts fresh and is dropped.
  * `InMemoryOnboardingProgressStore` and `IntroDeps.store` are unchanged;
    hosts that never passed a store need nothing.
  * Tests read and seed the record through base_sdk's key
    (`hostRecord.onboardingRun`) after `LocalStorage.init()`, and cover the
    move (intact, precedence of a base-key record, corrupt legacy).
  * pubspec 1.0.1 → 1.0.2.

## 1.1.0

* First-run setup as a guided run — design section 46, frames 46d (tablet)
  and 46h (phone), approved 2026-08-30. What the runner adds to the shipped
  flow, none of which it had:
  * **Back** (chip 855): `IntroNotifier.previousHostSlide()` /
    `OnboardingSlideScope.previous`. The first host slide has no Back and
    the flow never traps; a step passed by Back keeps its tick.
  * **A drawn position** (chips 852/865): `OnboardingRunRail`, built from
    `IntroNotifier.runSteps`, counts every step this role will see —
    welcome, the role choice, each visible host slide, the closing step
    (a parent's run is three steps, not five, chip 864). Full rail with
    per-step ticks and outcomes on the START side of a wide window (46d);
    compact segments plus the current/next card above the card on a phone
    (46h). `OnboardingSlide.title` names a step on the rail (falls back to
    `data['title']`, then "Step N").
  * **Required blocks, optional skips** (chip 862): `OnboardingSlide
    .required` (default false). An optional step shows the shipped Skip
    pill with an "Optional step" label beside it and
    `IntroNotifier.skipHostSlide()` passes it unticked; a required step has
    no Skip and the shell Continue stays disabled — "Finish this step to
    continue" — until the slide reports done via
    `OnboardingSlideScope.setDone(true)`. Calling `scope.next()` is itself
    the completion report. Resolves the collision with auth's
    "must never trap a freshly registered user" doctrine as
    required-blocks / optional-skips.
  * **Survival across a cold relaunch** (46h, ruling three): every change
    writes an `OnboardingRunRecord` — `{stepIndex, done[], lastTouched,
    values}` plus the role — through an `OnboardingProgressStore`;
    `introProvider` restores it before the page draws, so closing the app
    mid-setup returns to the same step with the earlier steps still ticked.
    `OnboardingSlideScope.setValue/values` park a host slide's typed value
    in the same record ("Ridge" still typed). Finishing the run clears it;
    a corrupt record starts fresh; a restored position is clamped to what
    the role can see. Default store: `SharedPreferencesOnboardingProgress
    Store`, one key `onboarding.run` (base_sdk's `LocalStorage` was the
    drawn home but exposes no generic key API; swap the store via
    `IntroDeps.store`). `InMemoryOnboardingProgressStore` for tests/hosts.
  * `OnboardingSlide.shellActions` (default false) lets the shell draw the
    card's Continue beside Back; slides that already draw their own
    Continue (the lms school/grade cards) are unchanged and get Back only.
  * New tests: `test/guided_run_test.dart` (notifier: back, required,
    rail data, persistence round-trips in memory and through
    SharedPreferences) and `test/intro_page_run_test.dart` (the page on
    46h's phone and 46d's tablet, including the relaunch resume).
  * `shared_preferences` added as a direct dependency (already pinned by
    base_sdk).
