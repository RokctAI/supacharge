## 1.7.0

* feat(productivity_sdk): OWNER SCOPING FOR THIS SDK'S OWN TABLES. Every
  table this SDK registers - `tasks_table`, `notes_table` and the six
  recovery tables - gains an `owner` column IN ITS PRIMARY KEY, and every
  read, update and delete in this package filters on it. Two accounts on one
  device no longer see, overwrite or delete each other's tasks, notes, urge
  logs, rituals or streaks. The follow-up to core PR #254, which did the same
  for base_sdk's device-global `KeyValueTable` and `OutboxTable`.
* VISIBILITY SCOPING, NEVER DELETION - Ray's ruling, unchanged and now
  actually enforced. 1.6.9 stopped the sign-out hook deleting rows and said
  in as many words what was still open: "one device shared by two accounts
  still shows each the other's rows once the tables are read again". This is
  that fix. Nothing is destroyed at sign-out, no column is dropped, and no
  migration guesses an owner for an existing row.
* AN EXISTING ROW WITH NO OWNER COUNTS AS THE CURRENT ACCOUNT'S -
  `owner = '' OR owner = <me>`, base_sdk's `ownerVisible`. Every row on every
  device in the field today has no owner, so a strict match would hide all of
  them. Legacy rows stay exactly as visible as they are now, and are CLAIMED
  by the account that next writes that id rather than being left as an
  unowned twin beside the row just written.
* Writes stamp `OwnerScope.instance.current` (base_sdk), which resolves the
  signed-in account, a temp-local `offline:<id>` account, or - during a
  sign-out teardown, when the identity is already gone - the account on its
  way out, so a teardown write cannot land unowned and leak forward.
* MIGRATION VERSION 20, declared in `manifest.json` (the shared fleetwide
  namespace; 20 is above base_sdk's 19 and radio_sdk's 18). The step rebuilds
  each table the long way round - rename aside, create, copy the shared
  columns, drop - because SQLite cannot alter a primary key in place;
  carried-over rows take the `''` default and come out unowned.
  `notes_table`'s create moved into the same guard so no device sits between
  the two numbers and misses it.
* `ProductivityOwnerScope.ready()` is a floor under that numbering, awaited
  by every read and write this SDK makes: a device whose stored
  `user_version` already equals the composed maximum runs no migration at
  all, and base_sdk's own `beforeOpen` floor can only reach base's tables.
* KNOWN, PRE-EXISTING, NOT FIXED HERE: radio_sdk (RokctAI/agent radio/dart)
  declares migration version 17, the number this manifest used to hold - a
  live collision on one number, flagged rather than silently worked around.

## 1.6.9

* fix(productivity_sdk): SIGN-OUT DELETES NOTHING. 1.6.8's session-end hook
  wiped the tasks rows, the notes rows, this SDK's still-pending outbox rows
  and the pull cursor on every logout. Ray's ruling: user data does not get
  wiped on logout - a local temp account that does real work and signs out
  must not come back to an empty list, and the same holds for a seller.
  Deletion is irreversible; the symptom that needed fixing never was.
* WHAT THE SYMPTOM ACTUALLY WAS. Ray, 2026-09-19: "if on temp local user you
  logout all your tasks still show" - the rows were still PAINTED, not merely
  still on disk. `tasksStateProvider` is a plain `StateNotifierProvider`,
  root-scoped and not `autoDispose`, so the notifier and the tasks it holds
  outlive the `replaceMainRoute` a sign-out ends with: the page is rebuilt and
  RE-READS the same surviving notifier. That is the half that
  `TasksNotifier.clearLive` fixed, and it is the half that is kept.
* `ProductivitySessionEnd.clear` is therefore now
  `ProductivitySessionEnd.clearLiveView`, named for what it does. It makes two
  in-memory writes and no others: `TasksNotifier.clearLive()`, and
  `TaskPullService.lastFailure = null` - a transient "sync failed" notice that
  belonged to the session that just ended, not user data. No store write, no
  network call, no `AppDatabase` at all; the hook no longer takes a database.
* THE PENDING OUTBOX ROWS ARE THE SHARPEST CASE. They are work the user did
  that has not reached the server yet. 1.6.8 deleted them to stop a queued
  push draining under the next session's token; that is a real concern, but
  destroying the work outright is not the answer to it, and a queue that
  drains under the wrong token is a sync-ownership question to settle in the
  queue rather than by throwing the rows away.
* `hookId` is UNCHANGED at `productivity_local_data`. It is only an
  idempotency key inside users_sdk's `SessionEndHooks` registry: nothing
  persists it, no other package reads it, and a rename would break any host
  still composing the old wiring block for nothing in return. Checked by grep
  over `.dart`, `.json`, `.yaml` and `.md` before deciding - the only other
  mentions are this package's own tests and this file.
* The manifest moves with it: the `boot_hooks` body now names
  `clearLiveView`, and `_comment_boot_hooks` - which stated plainly that the
  hook "deletes the tasks and notes rows, this SDK's still-pending outbox rows
  and the pull cursor" - now describes the real behaviour and says outright
  that it deletes nothing.
* WHAT IS STILL OPEN, named rather than left unsaid. This clears the session,
  not the ownership. One device shared by two accounts still shows each the
  other's rows once the tables are read again, because `TasksTable.createdBy`
  is written and never filtered on (`TodoRepositoryImpl.loadTodos` has no
  WHERE clause) and `NotesTable` has no user column at all. The fix is owner
  scoping - a predicate at the repository layer and a migration for notes -
  not a wipe at sign-out. Scoped separately; no code for it here.
* TESTS. `session_end_clears_local_data_test.dart` is now
  `session_end_keeps_local_data_test.dart`, and its first test is the whole
  point of this change: seed a session, run the hook, and every task row,
  note row, outbox row and the cursor are still there while the notifier is
  empty - plus a test that a fresh container (the page after signing back in)
  loads the two tasks straight back. The older trap is kept and adapted: it
  deletes the tasks rows BY HAND now, since the hook no longer will, and
  still asserts the root-scoped notifier is holding both tasks afterwards -
  proof that a store clear never addressed the reported symptom. The manifest
  wiring test gains one that neither the hook body nor its comment may claim
  a delete.

## 1.6.8

* fix(productivity_sdk): two rules the /tasks plus broke when it moved onto
  the floating nav in 1.6.7, both of them base_sdk's own and both written
  down in `adaptive_bar.md`. Follow-up to that change; nothing about the plus
  itself is reconsidered.
* THE LABEL IS TRANSLATED. `adaptive_bar.md` §8 is absolute - "No hardcoded
  user-facing strings, INCLUDING ACCESSIBILITY LABELS" - and §7 item 6 wants
  every string routed through `TrKeys` + `AppHelpers.getTranslation`.
  `FloatingNavAction.label` is not a label the bar merely stores: base_sdk
  feeds it to `Semantics(label:)` and to the long-press `Tooltip(message:)`,
  so it IS painted and read out. It was `newItemSheetLabelFor(list)`, which
  returns the bare literals 'New task' / 'New note'. It is now
  `AppHelpers.getTranslation` of `new_task` / `new_note`.
* PLAIN KEY LITERALS, the shape launch_sdk's `LauncherAppItem` already uses
  for `use_as_phone`: this SDK's own lib cannot read the `TrKeys.<name>` the
  composer injects (its tests run on a bare checkout), so it asks for the key
  by value. Both keys are published from this manifest's `tr_keys` alongside
  the section-47 ones, so a backend row can be seeded for any locale.
* AND ENGLISH DOES NOT MOVE. With no row served, `getTranslation` falls
  through `AppHelpers.humanizeTrKey`, which renders those two keys as exactly
  "New task" and "New note" - the new-item sheet's own words - so the button
  and the sheet it opens still cannot drift apart. Pinned as a test rather
  than asserted here. The sheet's own rows and `newItemSheetLabelFor` are
  untouched: they are not on the bar, and widening this to them would be a
  different change.
* THE BAR IS STACKED OVER THE PAGE BODY, not parked in the Scaffold slot.
  base_sdk states the host contract plainly - "Hosts place it in a Stack over
  the page body and hand it a `FloatingNavMode`" - and `adaptive_bar.md` §3
  names the slot a host owes it: "a full-size Stack slot
  (`Positioned.fill`, or the usual full-size `Align`)". The list plane used
  `bottomNavigationBar:`, alone in the fleet; every other host stacks it.
* THREE MECHANICAL CONSEQUENCES, which is why this is not a style note.
  `Scaffold.bottomNavigationBar` reserves the pill's height as body inset, so
  the bar was docked in a strip of its own while the housing is specified to
  float "with a margin above the bottom edge, never docked flush"; the
  frosted `BlurWrap` therefore had a flat background colour behind it instead
  of the list it exists to sit over, which is the housing's whole purpose;
  and the keyboard inset was counted TWICE - Scaffold lifts the slot above
  `viewInsets` while the bar adds `MediaQuery.viewInsets.bottom` itself, so a
  focused field on the list plane cost the body the pill height plus 18 plus
  the safe area ON TOP OF the keyboard. Inside the body the bar reads that
  inset as zero, because Scaffold has already removed it from the body it
  shrank.
* THE PILL DOES NOT MOVE, and nothing needed repadding. The bar brings its
  own `SafeArea` plus `18.h`; nested inside the plane's existing `SafeArea`
  the inner one contributes zero, so the pill still rests at the safe-area
  inset plus `18.h` above the screen edge - where the bottom slot rested it.
  Both list views already clear `88.h` below their last row and the housing
  is `60.r` under that `18.h`, so the clearance sized for the old FAB covers
  the pill with room over.
* The two test expectations that described the old mount now pin the new one:
  the harness mounts the bar the way the page does (and the way base_sdk's
  own tests do), and the template assertion pins
  `Positioned.fill` / `Align(bottomCenter)` / `ProductivityPlusNav` as one
  nesting AND asserts `bottomNavigationBar:` is absent, so a move back to the
  Scaffold slot fails on a test rather than on a screenshot. Nothing was
  skipped, deleted or weakened; the file goes from 8 tests to 10.
* The guided-tour fragment needed no change: it finds the plus by
  `ProductivityPlusNav.navKey` and its glyph, never by the slot it sits in.

## 1.6.7

* Ray, 2026-09-20: "i think productivity plus should be in the floating nav
  when you in its page. floating nav already accept modes and buttons". The
  /tasks workspace's plus is now ONE CONTROL ON THE BAR rather than a
  `FloatingActionButton` of the page's own.
* NOTHING NEW WAS DRAWN, and the mechanism is the one Ray points at.
  `ProductivityPlusNav` is base_sdk's `FloatingBottomNav` in
  `FloatingNavControlsMode` with no `input` - the mode's documented "pill of
  round buttons" shape - and the plus is one `FloatingNavAction` in
  `leadingActions`, the slot whose own doc names this exact case: "any other
  SDK's primary action - a tasks app's 'new task'".
* ONE PLUS PER SCREEN, the same rule the bar's back segment already keeps
  for back. The FAB is GONE from the list plane rather than duplicated
  beside the bar, and the page keeps no decision about the control: the
  widget owns the mode, the slot and the look.
* THE LONG PRESS CAME WITH IT. "plus opens new but i think hlding it should
  give me option like tasks notes" (Ray) rides
  `FloatingNavAction.onLongPress` (base_sdk 1.66.10), so the tasks/notes
  sheet is still a hold away. The FAB was wrapped in a `GestureDetector`
  only because a FAB has no long press; the bar's controls always had one.
* THE PLUS WEARS THE BAR'S RESTING CONTROL LOOK, not a brand fill: a
  `FloatingNavAction` with `active: false`, which is what the reference
  composer's leading "+" is. `active` is the mode's "this thing is ON"
  language (mic live, camera on) and a new-item button is not a toggle. No
  colour is named in this package for it at all - the bar paints its own
  controls.
* Its accessible label and tooltip are the sheet's own words for the list
  (`newItemSheetLabelFor`: 'New task' / 'New note'), so the button and the
  sheet it opens cannot drift apart. The bar prints no text under its
  controls, which is why the label is not new copy on screen.
* The guided-tour fragment's compose tap follows the control to the bar
  (`ProductivityPlusNav.navKey` + its plus glyph) instead of the removed
  `'tasks-compose'` key, so the /tasks stills are the screens the plus
  actually opens.

## 1.6.6

* fix(productivity): a sign-out takes the tasks with it. Ray, 2026-09-19:
  "if on temp local user you logout all your tasks still show" - and they
  did, because NO SDK cleared its own on-device user data at sign-out.
  users_sdk's `SessionEndHooks` has published that moment since it shipped
  and had exactly one subscriber (auth_sdk's restore-key revoke, registered
  from `auth/dart/manifest.json` - a grep for `SessionEndHooks` over `.dart`
  files finds nothing, which is how that stayed easy to miss).
* New `ProductivitySessionEnd.clear`, registered under
  `productivity_local_data` from this manifest's new `productivity_session_end`
  boot hook. It deletes the tasks and notes rows, this SDK's still-pending
  outbox rows and the incremental pull cursor
  (`AppDatabase.clearBox`, which had no production caller until now), and
  clears the stale `TaskPullService.lastFailure` notice. Deleting the queued
  pushes matters on its own: a task queued under the signed-out user's
  session would otherwise drain later, under whatever token came next, and
  land in someone else's account. Every call is local - nothing here reaches
  the network, which is the point, since the users who need it most have
  never had a backend.
* AND THE ONE WITHOUT WHICH NONE OF THAT IS VISIBLE: `TasksNotifier` now
  keeps a registry of the notifiers a process is holding, and
  `TasksNotifier.clearLive()` empties them. `tasksStateProvider` is a plain
  `StateNotifierProvider`, not `autoDispose`, so it lives in the root scope
  for the whole process: a sign-out ends with `replaceMainRoute`, which
  rebuilds the page and RE-READS the same surviving notifier, so emptying the
  tables on its own changed nothing a user could see until the app restarted.
  A registry rather than `ref.invalidate` because a session-end hook is a
  plain callback with no `WidgetRef` and no `ProviderContainer` in reach.
  Entries are removed in `dispose`, and `clearLive` checks `mounted`.
* DELIBERATELY NOT CLEARED: the recovery tables (avoided habits, urge logs,
  rituals, procrastination logs). Session-scoped in exactly the same way and
  a leak of exactly the same shape, but irreversible in a way a task list is
  not - held for Ray's word rather than decided here. Named in the code and
  in the manifest comment rather than left unsaid.
* Tests: `test/session_end_clears_local_data_test.dart` - the tasks, notes,
  outbox rows and cursor are gone, and the surface reads back empty; a
  store-only clear leaves the root-scoped notifier still holding the tasks
  (Ray's symptom, pinned, so the day someone decides the store clear was
  enough the suite says so); the sync-failure notice is cleared; `dispose`
  unregisters and a clear with nothing live is safe; running twice is
  harmless. `test/manifest_wiring_test.dart` gains the boot hook: it
  registers against `SessionEndHooks`, names the clear off the class so the
  manifest cannot drift from the Dart, the clear is exported from the barrel
  the host reaches it through, and it declares no `imports` (every composed
  `main.dart` already has them).
* This is one third of the fix. The other two are users_sdk 1.4.1 (the local
  session was cleared only when the server revoke succeeded - and a
  temp-local account's `offline:<local user id>` token can never be revoked,
  so sign-out was a guaranteed no-op for exactly those users) and base_sdk
  1.66.9 (`ProfileNotifier.logOut` did not await the sign-out and cleared
  nothing locally).
* manifest.json 1.6.5 -> 1.6.6; no new base_sdk requirement (`clearBox` has
  shipped since the key-value store did).

## 1.6.5

* The theme-blind widget sweep, finished: every `build` in this package's
  `lib` and `templates` trees audited against the defect 1.6.3 fixed in
  four pages and one strip (Ray, 2026-09-19: "glance doesnt change test
  immediately untill you come back if you switched theme mode"). A widget
  is theme-blind when its `build` decides a colour from one of `AppStyle`'s
  mode-resolving statics and that same `build` registers no
  inherited-widget dependency a mode flip reschedules — a static is not an
  inherited widget, so the flip schedules no rebuild and the old mode's
  colours stay until something else happens to rebuild the element.
* 41 classes read such a static. THE REACHABILITY PASS DECIDED ALMOST ALL
  OF THEM: a widget with no rescheduling read of its own, instantiated
  NON-`const` from a build that has one, is rebuilt by that parent and its
  statics resolve afresh. With 1.6.3's four pages now depending on the
  inherited theme, 37 of the 41 sit on such a chain — the list, compose,
  note, picker and run panes all reach `PlaneHost`, which mounts each pane
  as `Builder(builder: page.builder)`, non-`const`. They were REJECTED, not
  changed: no colour role was respelled to fit the pattern.
* `WeeklyCheckInStrip`: the two reads left on statics in 1.6.3 because no
  `Brightness`-taking seam existed for either role now go through
  `AppStyle.cardAltFor` and `AppStyle.subtleStrokeFor`, so the card fill
  and the hairline name the mode the strip's own `Theme.of` reports rather
  than the app-wide flag. Same two values per mode as before.
* `_NewItemSheet` (the /tasks add button's long press): FIXED. Its route
  builds it `const`, and a `const` instantiation is a boundary the flip
  cannot cross, so a mode change made while the sheet was open left every
  row on the previous mode's ink, fill and stroke. The heading and the rows
  now resolve against `Theme.of(context).brightness`, read once in `build`
  and handed to the row helper.
* The snooze sheet was AUDITED AND REJECTED for the opposite reason, and
  the difference is exactly the `const` rule: `showSnoozeSheet` builds
  `_SnoozeSheet(...)` non-`const`, and Flutter's own `_ModalBottomSheet`
  reads the inherited theme for its defaults, so the flip marks that
  element dirty and the route's builder runs again with a fresh widget.
  The flip already reaches it.
* `PausedRunLineView` (chip 859, the run badge on the host's Tasks row):
  FIXED. Its only parent here, `PausedRunLine`, watches a store provider
  and asks nothing inherited for the mode, and the row it is composed into
  lives in the host — so no rebuild can be shown to reach the line at all,
  the same position base_sdk's glance card was in behind its `const`
  boundary. Its hairline and subline now name `AppStyle.subtleStrokeFor`
  and `AppStyle.faintFor` for the mode the theme reports.
* NO COLOUR VALUE CHANGED IN EITHER MODE, no hex literal was added to a
  widget, and nothing was added to base_sdk: every seam used here shipped
  in base_sdk 1.66.6.
* Two reads are deliberately untouched and are NOT the defect: the
  `backgroundColor:` each of `showNewItemSheet` and `showSnoozeSheet`
  passes to `showModalBottomSheet`. Neither sits in a `build`, so neither
  can register a dependency and neither can be made to reschedule
  anything; both are evaluated when the sheet opens, when the flag is
  current.
* Tests: `sheet_theme_mode_test.dart` pumps both sheets, flips
  `AppStyle.setBrightness` and `themeMode` the way `AppNotifier.changeTheme`
  does and pumps again WITHOUT remounting — one test for the new-item sheet
  as the fix, one pinning the snooze sheet's non-`const` builder as the
  reason it was rejected. `weekly_check_in_strip_theme_mode_test.dart`
  gains the case that tells a static read from a theme read apart: the flag
  and the strip's subtree theme are set to disagree, which is the only
  arrangement in which they can. `paused_run_line_theme_mode_test.dart`
  reads the widget as source, because `paused_run.dart` pulls the
  drift-backed repository whose generated sources this package does not
  build — the same reason the shipped paused_run_line_test.dart is one of
  this package's standing load failures.

## 1.6.4

* The launcher's Build (Smart) run stopped at the Dart front end in both the
  Android and the Windows job with three errors, at identical positions in
  each, none of them in a file any of 1.6.1-1.6.3 touched:
  * `.rokct/cache/productivity/lib/src/common/application/tasks/tasks_state.dart:18:14`
    and `:29:10` - Type 'TaskModel' not found.
  * `.rokct/cache/productivity/lib/src/common/application/tasks/tasks_notifier.dart:63:42`
    - Type 'ProcessingState' not found.
  Both composer jobs reported success and pub pinned this SDK happily; the
  break was purely at compile time.
  THE CAUSE IS AN ISLAND THAT JOINED THE MAINLAND. Since the src/ reshuffle,
  `application/tasks/{tasks_provider,tasks_notifier,tasks_state}.dart` had
  named `TaskModel` and `ProcessingState` without importing either -
  `tasks_state.dart` imported only `flutter_riverpod`, which it did not even
  use, and `tasks_notifier.dart` reached for this package's own barrel, which
  does not re-export base_sdk and so never put `ProcessingState` in scope.
  Nothing reachable from `lib/productivity_sdk.dart` imported any of the
  three, so the front end never walked into them and the missing imports cost
  nothing. 1.6.2's `NeedsAttentionGlance` then imported the island - it
  watches `tasksStateProvider` for the tasks half of the glance - the barrel
  exports the glance, and the very next host build had to compile all three
  files for the first time.
  The fix is the imports those files always needed: `TaskModel` from this
  package's `models/data/task_data.dart` in `tasks_state.dart` (replacing the
  unused `flutter_riverpod` import), and `ProcessingState` from
  `package:base_sdk/base_sdk.dart` in `tasks_notifier.dart`, whose two
  members of this package (`TaskService`, `TaskModel`) now come from their own
  libraries rather than back out through the barrel that exports the glance
  that imports this file. No public API changed, in this SDK or any other: the
  three types keep their declarations, their libraries and their exports.
  WHY THE REPO'S OWN SUITE DID NOT CATCH IT, AND WHAT NOW DOES.
  `dart analyze` here does name the three errors, but as 3 of ~100, because
  the composed AppDatabase's drift code (`TaskEntity`, `tasksTable`,
  `TasksTableCompanion`) exists only after composition, and every test in
  this suite that imports the barrel - the only tests that would compile the
  public surface - is already a load failure on those same composed-only
  symbols. So no local signal distinguished a fatal error from the standing
  noise.
  `test/public_surface_reachability_test.dart` closes that gap from the other
  side. It walks the same graph the front end walks - every library
  transitively reachable from `lib/productivity_sdk.dart` through `import`
  and `export` - and asserts that each one can see every type it names,
  resolving this package's own libraries from source and base_sdk's through
  `.dart_tool/package_config.json`. It models Dart's actual rule (an import
  gives you the target's declarations and the target's `export` closure, and
  nothing the target merely imports), it needs no generated code, and it
  fails with exactly the two libraries and two type names the launcher build
  failed on. An island that joins the public surface is audited from the
  moment it joins.

## 1.6.3

* Ray, 2026-09-19: "glance doesnt change test immediately untill you come
  back if you switched theme mode". The same defect, in this SDK's own
  widgets: a `build` that decided a colour from one of `AppStyle`'s
  mode-resolving statics and asked nothing inherited for the mode. A static
  is not an inherited widget, so a theme-mode flip scheduled no rebuild of
  those elements at all and they kept the previous mode's colours until the
  reader left the screen and came back. Fixed where the staleness is
  PROVABLE, i.e. where no parent rebuild can reach the widget either:
  * `WeeklyCheckInStrip` (the personal-mastery weekly check-in), mounted
    `const` by `templates/pages/vision/personal_mastery_page.dart` — the
    same `const` child boundary base_sdk's glance card sat behind. Its two
    facts now name their ink through `AppStyle.inkFor` and
    `AppStyle.secondaryInkFor` for the mode `Theme.of(context).brightness`
    reports, and the card and stroke ride the same rebuild.
  * The four pushed route pages that painted their ground from
    `AppStyle.surfaceDark`: the tasks workspace, the task-run push, personal
    mastery and plan-on-a-page. A pushed `ModalRoute` caches the page it
    built, so an ancestor rebuild provably never reaches it. Each now reads
    the mode once in its own `build`, outside the `LayoutBuilder` and the
    plane builders, and names its ground through `AppStyle.surfaceFor`; the
    tasks workspace hands the resolved colour DOWN to its five panes (list,
    compose, note editor, run, objective picker) so the whole page is
    painted for one mode. The run push's absent-task line takes
    `AppStyle.faintFor` the same way.
  No new colour value anywhere: `inkFor`, `secondaryInkFor`, `surfaceFor`
  and `faintFor` are base_sdk's existing mode seams, each returning the same
  two values as the static it replaces. The ~41 remaining static reads in
  this package sit inside builds that a parent already reschedules and are a
  separate decision.
  Tests: `test/weekly_check_in_strip_theme_mode_test.dart` flips the mode
  with the strip mounted behind a `const` boundary and never remounts it;
  `test/template_page_theme_mode_test.dart` pins the four pages' mechanism
  in source, because none of them can be compiled by this package (they
  import `auto_route`, `comms_sdk` and the generated-code barrel, none of
  which is a dependency here) — the same reason the shipped suite pumps
  components and frames rather than installed pages.

## Unreleased

* Build fix: `TaskPullService` read `AppConstants.isDemo`, which base_sdk
  removed with the `--dart-define=IS_DEMO=true` define, so every composed
  app failed to compile (`The getter 'isDemo' isn't defined for the type
  'AppConstants'`). The pull gate now reads `DemoSession.demoActive`, the
  one question every demo seam asks (the guided-tour build OR the runtime
  session auth_sdk activates from the server-asserted demo-account marker).
  Same boolean meaning, and it now also holds the pull back for a demo
  session served from the in-app fixtures, matching auth_sdk's
  `DemoHoldSyncHandler` on the push half. The `isDemoOverride` test seam is
  unchanged.

## 1.6.2

* Ray, 2026-09-19: "in home the glance has 3 items, task, plan on a page,
  personal mastery. all these are  productivity. having a productivity button
  in floating nav is better and the glance show what need attention". The
  three permanent doors this SDK injected into the launcher glance are gone.
  The doors are now ONE Productivity entry on the launcher's floating nav
  (launch_sdk 1.7.5, which also carries the widened glance seam); what this
  SDK puts in the glance is what actually wants the reader.
* New `ProductivityAttention` (`src/common/application/glance/`) is that rule,
  PURE and over rows already in hand. It reads ONLY fields these models
  already carry, because these doctypes are skeletal and no signal was
  invented:
  * TASKS - `TaskModel.dueDate` is today or past and `TaskModel.status` is
    neither `completed` nor `cancelled`. Compared by DAY, so a task due at
    09:00 still wants the reader at 17:00.
  * PLAN ON A PAGE - the plan carries no dates at all (`vision_data.dart`: "no
    objective status or dates"), so the only thing it can honestly ask for is
    an objective that NOTHING MEASURES: a `PlanBoard.objectives` entry with no
    `Kpi` linked, and only when `PlanBoard.kpisRead` says the KPIs were
    actually read - an unreadable count is not zero, exactly as the board
    itself already refuses to draw "0 KPIs" over a failed read.
  * PERSONAL MASTERY - the goal has no status field either, so the child rows
    speak: a `MasteryTodo` whose `date` is today or past and whose `status` is
    neither Closed nor Cancelled, under a goal whose rows were actually sent
    (`MasteryGoal.todos` non-null).
* At most three lines from any one surface, soonest first. A glance is a
  glance, and the whole list lives behind the Productivity entry.
* New `NeedsAttentionGlance` (`src/common/presentation/glance/`) is the reader
  and the dress: tasks from `tasksStateProvider`, the plan and the goals from
  this SDK's own `VisionRepositoryFacade`. A failed read draws no lines rather
  than an error on somebody's home screen - the plan and mastery pages already
  print the backend's own message. Navigation is still by ROUTE PATH through
  the host's `onOpen`, so this SDK still never imports launch_sdk (ADR-005),
  the same contract `PausedRunLine` uses.
* NOTHING needing attention renders NOTHING, and no line was written for it:
  base_sdk's `GlanceCard` already collapses to `SizedBox.shrink()` on an empty
  item list.
* `manifest.json` now claims TWO markers on the launcher home instead of one,
  exactly like the tasks-row pair: `// @launcher-glance-imports` takes
  `import 'package:productivity_sdk/productivity_sdk.dart';` (the widget is
  this SDK's own and the launcher home does not import it otherwise) and the
  12-space-indented `// @launcher-glance` takes the widget. Both are skipped in
  a host without launch_sdk, as before. No route, no tr_key and no database
  version changed.
* Icons are material (`Icons.task_alt` / `flag_outlined` / `star_outline`)
  rather than the Remix set the injected doors used: the widget lives in this
  package's `lib` and this package declares no icon-set dependency, which its
  own pubspec comments forbid leaning on transitively.
* 12 new tests in `test/productivity_attention_test.dart` pin every rule above
  and the quiet case, and check the manifest injects one widget rather than
  three doors. 294 tests pass (the 6 pre-existing drift-codegen load failures
  are unchanged).

## 1.6.1

* Launcher Tasks page, Ray 2026-09-19 — four reports off today's build, one
  pass.
  * **"notes seem like cant save".** The notes table was never created on any
    device that had the previous launcher installed. THE MIGRATION VERSION IN
    A MANIFEST IS SHARED WITH EVERY OTHER SDK IN THE COMPOSED APP: the
    composer sets the composed `AppDatabase.schemaVersion` to the MAXIMUM
    version any manifest declares while each SDK writes its own
    `if (from < N)` guards, so the numbers are one namespace with no
    allocator. `auth_sdk` already declared 16 for its own table, which means
    the launcher was ALREADY at schemaVersion 16 while this manifest said 15
    — and 1.6.0's bump 15 -> 16 therefore raised nothing at all. Drift calls
    `onUpgrade` only when `schemaVersion` exceeds the stored `user_version`,
    so on an upgrading phone no migration ran, `notes_table` did not exist,
    and every insert failed on `no such table`. Notes are now created at
    **17**, above anything else composed. The manifest says the rule out loud
    and `manifest_wiring_test.dart` enforces it: the declared version must be
    past 16, no guard may sit above it, and the newest table must be created
    AT it.
  * **The same report, second half: the failure was invisible.**
    `NoteRepositoryImpl.saveNote` caught the failed insert, wrote one
    `debugPrint` and returned the note as though it had been stored, so the
    editor closed over a note that was never written — a save that looked
    like a save. A refused write now rethrows, and the editor keeps the pane
    open with the reader's words still in it and says one line. A failed
    READ still degrades to an empty list: a list that cannot be read has
    nothing to keep open.
  * **"tasks saved cant be edited".** On a wide window the card's tap opens
    the task form in the detail plane; on the phone fold that same tap is
    spoken for — frame 44d expands the card in place, which IS the fold — so
    no gesture reached the form and a saved task could not be changed on a
    phone at all. The expanded card now carries an **Edit** pill
    (`TaskCard.onEdit` / `TaskCard.editKey`), in the run pill's shape and the
    card's quiet stroke, and opening the form collapses the card behind it.
    A done task offers it too: being finished is a field like any other and a
    wrong one has to be fixable. Nothing changes on a wide window, which
    passes no callback.
  * **"plus opens new but i think hlding it should give me option like tasks
    notes".** A TAP IS UNCHANGED and deliberately so — the add button still
    opens a new item of whichever list the plane is drawing, a task on Tasks
    and a note on Notes, because that is the one gesture that must never ask
    a question. A LONG PRESS now opens `showNewItemSheet`, the snooze sheet's
    control, naming both lists; choosing one switches the segment first and
    then opens that list's form, so a note started from the tasks list is
    never saved behind a list the reader is looking at.
  * **"when thereis completed task switch from all to pending".** The status
    tabs open on Pending when the list already holds finished work, and on
    All when it does not, exactly as before. `InitialStatusFilter` is the
    whole rule and it is PURE: derived from the list that just loaded, never
    persisted, and it never picks Completed. It chooses an INITIAL value
    only — once the reader touches the tabs the page stops choosing, so a
    sync, a snooze or a save cannot move the filter under their hand.

## 1.6.0

* Launcher Tasks page, Ray 2026-09-18 — two reports, one pass.
  * **"long term task is selected not automatically detected from end
    date".** The long-term band (section 47m) shipped with a hand switch on
    the compose form, and the frame said so: "set by hand ... nothing
    derives it". It is derived now. `LongTermRule` holds the whole rule and
    its one named cut-off, `LongTermRule.horizonDays` (30): a task whose
    end date is more than that many days past its start — its `startDate`
    when it has one, else the date it was created — is long term, and a
    task with NO end date is not. The switch is gone from the form and one
    derived line stands where it was, reading back what the deadline just
    decided. The stored `isLongTerm` field is untouched and still the one
    thing the card badge, the band split and the synced `is_long_term`
    column read; what changed is who writes it. It is written in two
    places on purpose — the page, so the band is right the moment you save,
    and `TodoRepositoryImpl.saveTodos`, which is the choke point every
    other local writer passes through (the recurrence roll-over, a
    restored backup, a pulled task whose deadline the server moved).
  * **"i cant do notes its only tasks and no seperate notes if need to
    be".** The /tasks workspace now carries a second list. A Tasks / Notes
    segment sits at the head of the list plane — chip 827's control, not a
    TabBar, because this page's navigation is PlaneHost's — and the notes
    half draws its own cards with none of the task furniture: no done
    state, no priority tint, no deadline, no steps. A note is a title, a
    plain-text body and the moment it last changed; create, edit and
    delete land in the same last plane the task form uses, and switching
    lists closes whatever that plane was carrying. New `NotesTable`
    (migration 16), `NoteRepositoryImpl`, `NoteViewModel`, `NoteCard` and
    `WorkspaceListSegment`.
  * **NOTES ARE LOCAL ONLY, AND DELIBERATELY.** Tasks sync because a Task
    doctype exists to sync to; no backend this app composes has a note
    doctype, so there is no note outbox, no note pull, and no sync columns
    invented on the table for a server that would not know what to do with
    them. Give notes a doctype later and the table gains them in a
    migration, exactly as tasks did.

## 1.5.4

* Guided tour, tablet audit 2026-09-07: the `productivity_maintenance_readings`
  still showed the device keyboard over the lower fifth to quarter of the
  frame on every shell (supacharge 25%, paas_manager 21%, minilauncher 11%).
  The step typed the four readings with `tester.enterText`, which opens the
  real keyboard on device, and nothing closed it before the frame was held.
  * **Fix, fragment only.** After the readings are entered the step drops
    focus (`FocusManager.instance.primaryFocus?.unfocus()`), asks the
    platform to hide the keyboard (`SystemChannels.textInput` →
    `TextInput.hide`, so the fragment now imports `flutter/services.dart`),
    pumps, and waits 750 ms for the sheet to re-lay out before returning.
    The photo step, which also types (the permeate re-test) before tapping
    Continue, does the same once the photo slot is on screen. flutter_test's
    `tester.testTextInput.hide()` is deliberately not used: the integration
    binding does not register the fake `TestTextInput`
    (`registerTestTextInput => false`), so that call would assert on device.
    Navigation, seeded rows, captions and the same-route rule are unchanged;
    the shells' generated `tour_steps.g.dart` are regenerated by the runner
    and are not touched.

## 1.5.3

* Guided tour: the `productivity_maintenance_readings` and
  `productivity_maintenance_photo` stills came out byte-identical (paas_manager
  run 34125787148, minilauncher run 34125847285: "duplicate screenshots ...
  productivity_maintenance_readings == productivity_maintenance_photo" at
  Assemble Feature Guide), and both were the compose lane the step before
  had opened — not the run at all.
  * **Root cause.** The readings step seeded the softener run and then
    `router.replaceNamed('/tasks')` while `/tasks` was already the route
    on top. auto_route keys a route's page by its name
    (`AutoRoutePage.canUpdate` compares `routeKey`), so replacing `/tasks`
    with `/tasks` is a same-key update to the Navigator: the existing
    `TasksPage` and its state stay — the compose lane still open, the list
    still the four tasks it loaded before the seed — and
    `task-card-tour-softener-sft-02` was never built. Its run pill, the
    resume button and the reading fields were all absent, every guarded
    tap fell through, and the photo step (a reading and a Continue on that
    same absent card) changed nothing either. The run logs bear it out:
    no `TOUR_ACTION_ERROR`, and the capture timestamps show none of the
    waits that follow a found pill.
  * **Fix, fragment only.** The readings step now goes to
    `/tasks/run?task=tour-softener-sft-02` — the route the run pill itself
    pushes at one plane (46f) and which, since 1.5.2, hands a wide window
    to the workspace with that run open in the detail plane (47a). Same
    still as the pill would have opened, on both folds, reachable from
    whatever screen the tour is on. Both steps wait for the widget the
    next tap needs (resume card, first reading field, Continue, then the
    photo step's own slot) with a bounded poll instead of a fixed pause,
    so the photo still is the photo card and never the readings card
    again. The rule — re-routing to the route already on top reloads
    nothing — is written at the head of the fragment for the next step
    that seeds rows. Captions and the seeded rows are unchanged; the
    shells' generated `tour_steps.g.dart` are regenerated by the runner
    and are not touched.

## 1.5.2

* Tablet design audit 2026-09-07, defect 4: `/tasks` never showed frame
  44a's composition on a wide window, and the standalone run page claimed
  two planes where frame 47a rules "46's mechanism, unchanged — no new
  plane". Fixed at the pages and in the tour fragment; the phone is
  unchanged.
  * **The list is one plane wide beside its pane.** 44a draws the
    workspace as list | detail, each one plane; the list used to declare
    `PlaneSpan.two` and stretched a single column of cards across two
    planes whenever a detail, the compose lane or a run opened beside it
    on a three-plane window. The claims now live in `TasksPlaneClaims`
    (new, exported): the list is `twoIfSpare` — one plane beside a pane,
    a second only while the stage would otherwise stand empty, so the
    list at rest fills the window exactly as before — and every pane
    makes the default one-plane claim. Three planes with a pane open are
    list | pane | bare, two are list | pane, and the objective picker
    (44c) slides list + detail towards the start as drawn. The plane 44a
    gives the HUB is not this SDK's to draw: the manager hub is
    merchants' `RestaurantHubPlaneFlow`, a one-step host whose rows push
    real routes, so until it hosts `/tasks` inside its own flow (the
    commerce half of 44a, not built here) the plane it would keep trails
    bare at the end, the ruled place for a leftover.
  * **The fold test reads the plane COUNT.** `_isSinglePlane` compared
    the list's granted span, which is one beside a pane on a tablet too,
    so the list would have fallen into the phone fold (cards expanding in
    place, runs pushed as a route) the moment the claim changed; and from
    the page's own context — above its host — it always read one, so the
    run pill pushed the standalone route on every window. It now reads
    `Planes.count`, falling back to the window width by PlaneHost's own
    thresholds, exactly as `TaskRunView` derives it.
  * **Canonical 347 at the root of a wide window.** PlaneHost floats its
    pill only while the flow is deeper than its root, so `/tasks` with
    nothing open had no way back to the hub on a tablet. The page floats
    the same `FloatingBackPill` in the same bottom-END corner PlaneHost
    and calc's `CalculatorView` use, popping the route; the moment a pane
    opens PlaneHost's pill takes over, so there is one back per screen.
    One-plane windows keep their shipped navigation.
  * **`/tasks/run` yields a wide window to the workspace.** The route
    used to host `TaskRunView` on a `PlaneSpan.two` PlaneHost of its own,
    with no list beside it. On any window of two planes or more it now
    builds `TasksWorkspace(initialRunId: …)` — the `/tasks` page's body,
    split out of `TasksPage` so the route class keeps its argument-free
    const constructor (`const TasksRoute()` is what the hub pushes) — and
    the run opens in 44a's detail plane with the list beside it, the
    corner pill popping the pane and then the route. At one plane the
    page is what it was (46f), its claim now `PlaneSpan.one`, which is
    what it always received there. The workspace drops a run id the
    store does not hold. `TaskCard`s carry `ValueKey('task-card-<id>')`.
  * **Tour: the stills open what they show from the list.** The
    `productivity_tasks` step routed to `/tasks` with an empty store, so
    every wide still was "Nothing here yet." over two planes and a bare
    third. It now seeds four of a Limpopo water business's tasks through
    the page's own repository — deliveries, brine salt, an invoice, a
    long-term borehole (47m's band) — routes to `/tasks` and taps the
    first card: 44a's list | detail on a wide window, 44d's expanded card
    on the phone. The readings step now opens the softener run from its
    card's run pill instead of routing to `/tasks/run`: 47a's list | run
    on a wide window, the pushed page on the phone, then the same resume
    and readings as before. Captions are unchanged; nothing rendered
    names a demo.
* Tests: `test/tasks_planes_test.dart` pumps the workspace's stack on a
  real `PlaneHost` at 1066 and 800 logical and pins the allocation frame
  by frame — list | detail | bare and list | detail | picker at three
  planes, list | detail at two, the list grown to two planes at rest, the
  full step rail (not the fold's segments) inside a one-plane detail at
  three planes, and the standalone run's one-plane claim. The installed
  pages themselves are templates (analysis excludes them, and they import
  the composed app's comms_sdk), so the claims they declare are the
  thing under test.

## 1.5.1

* Two layout defects from the minilauncher Guided Tour (run 34040758271,
  stills 10 and 11, phone and tablet), fixed at the screens themselves;
  the tour fragment is unchanged.
  * **The compose lane clears the corner Back pill.** `PlaneHost` floats
    the pill (canonical 347) over the last plane's foot, and the new-task
    form scrolled under it — the Long term switch on the phone, Save task
    on the tablet. The form's list now sits inside a band reserved
    OUTSIDE the scroll, `PlaneBackClearance` (new, exported), sized by
    the pill's own figures — `planeBackClearance()` = the 60.r housing +
    PlaneHost's 16 bottom inset + the frames' 12.h gap, the same rule the
    merchants shell's `managerNavClearance` and zones'
    `driverRootNavClearance` follow — so no control can sit under the
    pill at ANY scroll offset. Padding inside the list (the previous
    88.h) only ever cleared it at the end of the scroll; the still is
    taken at the top. The pill itself is neither moved nor hidden.
  * **The readings step keeps its gate in sight while typing.** With the
    numeric keyboard raised the amber block (856, "Out of spec … Re-test,
    or record why") and the actions row scrolled off under it, so a
    locked Continue had no visible reason. While a reading or note field
    holds the focus, `TaskRunView` lifts the gate notice, the actions and
    Skip for now out of the step card and pins them at its foot, above
    the keyboard (`TaskRunView.pinnedFooterKey`); the moment focus leaves
    they return to the card and the layout is exactly what it was, at
    every width. Nothing is removed — Finish stays present and locked,
    never hidden (47h). The field being typed in is scrolled into view
    on focus (`Scrollable.ensureVisible`, both edges), and again once the
    pinned layout has laid out. The pin is read from focus, not from
    `MediaQuery.viewInsets`: a resizing Scaffold strips the bottom inset
    from its body. The pinned foot pads by the inset for a host that
    does not resize, and on a wide window by the Back pill's clearance,
    since /tasks floats the pill over the run pane.
* Tests: `test/compose_back_clearance_test.dart` pumps the compose frame
  inside a real `PlaneHost` with a real `FloatingBackPill` at 390x844 and
  1280x800 and sweeps every scroll offset for a control under the pill;
  `test/task_run_keyboard_test.dart` seeds the tour's own softener run
  (nine stages done, 175 / 212 / 8.4 / 1.9) under a 300-logical keyboard
  inset and pins the block, the actions and the focused field above it,
  then the foot's return to the card. All fail on the previous layout.

## 1.5.0

* Design strip **section 47 — the RO plant's service runs as ORDINARY
  TASKS** (frames 47a, 47b, 47c, 47d, 47h, 47i; approved by Ray
  2026-08-31: "maintenance is just a normal multi step task with
  reminder, no privilege"). Built on the section-46 runner as it stands:
  no maintenance screen, no dashboard, no hub row, no doctype, no plane
  of its own — a service run is a task made from a template, run in
  44a's detail plane (or the pushed `/tasks/run` page at one plane),
  and reminded of by the task's own reminder and recurrence. The water
  dashboard, tanks, efficiency and energy cards stay out (the
  2026-08-30 scope note).
  * **Step kinds on the runner** (`task_run.dart`): a step is `plain`
    (section 46's confirmation, with or without a clock), `reading` or
    `photo`, and may be `optional`. A reading step carries a list of
    `ReadingSpec`s — label, unit, min, max, or a calendar date — each
    with its recorded value; a photo step carries a path and a note. A
    new gate, `StepGate.incomplete`, is the block by DATA beside the
    block by TIME: a reading step cannot finish while a value is empty
    or out of spec, DERIVED from min / max on every read and never a
    flag. Skip on an optional step completes it as `skipped`; a required
    step has no Skip. `freshCopy` and Start over strip what was recorded
    and keep the spec. A plain step's map is byte-for-byte section 46's:
    the new keys are written only when they say something.
  * **47h — the readings step, REQUIRED** (`task_run_view.dart`): the
    values as fields with their spec beside them ("≤ 400", "6.0–10.0"),
    green in spec and amber out of it; while one is missing or out of
    spec the amber block (856) names the value in the frame's words —
    "TDS — permeate 212 ppm is outside ≤ 50 ppm" — and the route out
    (858) is the frame's too: "Re-test, or record why it is out of spec,
    to continue." A note explaining the value unlocks Finish; Finish
    stays present and locked until then, never hidden. What is typed is
    handed back through `onChanged` as it is typed, so a kill mid-entry
    loses nothing recorded.
  * **47i — the photo step, OPTIONAL**: the photo slot ("Add a photo —
    of the vessel head or the meter"), the note ("Anything worth
    remembering next time…"), and Skip (862) live beside a working
    Finish. The photo is a PATH STRING picked through base_sdk's
    `ImgService` (camera or gallery, the user's choice, base already
    carries `image_picker`); a host or test hands in its own picker via
    `TaskRunView.pickPhoto`. No preview is drawn and no file is read.
    The rail says "skipped", "recorded", "photo kept" beside such steps.
  * **47a — the templates** (`maintenance_templates.dart`): the softener
    regeneration (nine stages) and the megaChar backwash (seven, the
    first four shared), PORTED NOT INVENTED — paas_pos's `MaintenanceStage`
    order, its `AppConstants` durations in ONE map
    (`kMaintenanceStageSeconds`, 0 = confirm-only) and its operator
    instructions verbatim — then Readings (required) and Photo & notes
    (optional) as steps 10 and 11. The 11-value stage enum is not
    carried: a stage is a step title an owner can edit. A run is built
    as a task map: `stepsAreSequential`, Weekly recurrence (the 47a
    card's "every 7 days"), reminder on, due today. The 47a list's three
    replacement reminders (pre-filter 30 days, RO filter 180, membranes
    365) are ordinary tasks with a due date from the plant record and NO
    step list, because no source gives one.
  * **47b — the timed brine rinse** is a clock-gated step exactly as
    section 46 already gates one: 30 minutes, Continue locked with the
    remaining time named, no way past but time. **47c — coming back the
    next morning:** verified rather than built — remaining time was
    already derived from the persisted `startedAt`, so a stage started at
    22:00 reads as run out at 07:00 with no timer alive in between;
    pinned by test across a simulated overnight.
  * **47d — first-run plant setup on the same runner**
    (`maintenance_plant.dart`): "the plant has to be described before it
    can be serviced". The setup is itself a template — Vessels, Filters,
    RO membranes (required reading steps: counts with `min: 1`, install
    dates) and Water spec (optional, pre-filled with 47h's thresholds).
    A finished setup run is read back into a `PlantRecord` and kept on
    the device in base_sdk's LocalStorage host-record store
    (`productivity.plant`) by the hosts' run-save hook; the templates
    read it for due dates and for the readings' limits. Until it exists
    the compose lane offers the setup first and draws the service
    templates present but dimmed, with one line saying why.
  * **The entry point — "From template" in the compose lane (44b)**:
    one row of chips on a new task, keyed through this SDK's manifest
    `tr_keys` (`from_template`, `plant_setup`, `softener_maintenance`,
    `megachar_maintenance`, `pre_filter_replacement`,
    `ro_filter_replacement`, `ro_membrane_replacement`,
    `describe_the_plant_before_it_can_be_serviced`). Picking one fills
    the same form — title, steps, deadline, reminder, recurrence — and
    nothing is saved until Save task. The task map gains a `template`
    key naming what it was made from.
  * **Local-first, not on the wire.** The step kinds, specs, values,
    note and skipped flag live in the subtask map and so in the device's
    `TasksTable.data` blob. They are NOT sent: `task_sync.py`'s
    `SUBTASK_STEP_FIELDS` passthrough on the `Task Subtask` child
    doctype drops keys it does not list, so the seam is a comment on
    `TaskSubtaskRequest` naming that whitelist, and no fake call. A pull
    now keeps these device-only keys from the device's own row (same
    step by title at the same position), the way it already keeps
    `notifId`, instead of wiping them.
  * **Tour fragment updated** (`templates/tour/productivity.tour.yaml`):
    `productivity_task_compose` reaches the "From template" chooser,
    `productivity_maintenance_readings` opens a softener service at its
    readings step with a value out of spec, and
    `productivity_maintenance_photo` finishes it to the photo step. The
    steps seed one plant and one service run on the device through the
    same repository the page uses; there is no demo repository for
    tasks and none is added.
  * **Tests.** `test/task_step_kinds_test.dart` pins the reading gate
    (empty, out of spec, in spec, the note as the route out), the
    optional Skip against the required step, the overnight clock with
    an injected DateTime, the map shapes and the pull merge.
    `test/maintenance_templates_test.dart` pins both step lists against
    the one duration map, the 47b block on the brine rinse, the 47d gate,
    the plant record read off a finished setup run, and the due dates.
    `test/task_run_kinds_view_test.dart` drives the drawn card: the
    refusal wording, Finish locked then unlocked, Skip finishing the
    run, a picked photo on the map. Nothing existing was skipped or
    changed. The six database-backed suites that need the composed
    `AppDatabase` still do not load on a bare checkout, as before.
  * Not built here, on purpose: the server columns for readings and
    photos (the `Task Subtask` whitelist and the water thread's service
    log), a scheduler for the 180/365-day intervals (`recurrence` has no
    such Select value; those two repeat by the next template pick), and
    any water screen.

## 1.4.0

* Design strip **section 41 — the M2 vision cluster** (frames 41a, 41b,
  41c, 41d; approved 2026-08-30 13:18Z). The legacy JuvoONE Plans /
  Mastery tabs reborn in the settled plane language on the REAL
  productivity backend — new screens for the productivity gate (approved
  7e, coverage group M2); nothing existed in Dart before this.
  * **41a — plan on a page** (`/vision`, `templates/pages/vision/plan_on_a_page.dart`):
    the board DECLARES ALL. Header + count pill ("3 pillars · 6
    objectives", canonical 700), the **785 vision masthead** across the
    claim (the single Plan On A Page doc's linked Vision: eye tile,
    title + "Vision" tag, statement line), then **786 one pillar per
    plane-aligned column** (accent-tinted header: glyph + title +
    objective-count badge + description) with **787 objective cards**
    (title, description, accent "N KPIs" pill, chevron). Accent and
    glyph are PRESENTATION-ONLY and positional — the Pillar doctype has
    no icon / colour / display_order (flag b); the KPI count is DERIVED
    by counting `get_kpis`, and an unreadable count draws no pill.
  * **41b — the drill**: tapping an objective pushes its detail with the
    default one-plane claim; newest wins, the detail takes the LAST
    plane and the board compresses beside it — same columns, tighter
    dress — with the tapped card lit primary + "Selected" (**788**).
    The **789 detail pane** carries the **790 breadcrumb** (Vision ›
    Pillar, the pillar leg in its accent), the title + description and
    the **791 KPI cards** — title + description ONLY, no gauge: the KPI
    doctype has no metric / target / current / unit (flag b). The corner
    pill pops the detail and the board re-spreads.
  * **41c — personal mastery** (`/vision/mastery`,
    `templates/pages/vision/personal_mastery_page.dart`) in the
    sec-33/38 list language: header + "4 goals" pill (700), the **794
    weekly check-in strip** naming the two shipped schedulers as page
    facts (Monday check-in · `send_weekly_goal_reminders`; Friday wins ·
    `send_friday_wins_reminders`), then **792 goal cards** in two
    plane-aligned columns (`ListPlaneColumns`) whose only progress
    metric is the `todos` child table — "N of M" pill, thin bar (green
    at complete) — and the rows as **793 check lines** (Closed check /
    Open circle from `ToDo.status`, closed rows dim, `ToDo.date` faint
    at the end). No status tabs: the goal has no status field.
  * **41d — the phone fold** of 41a: one plane, the pillar columns
    become stacked sections, compact masthead and headers, the count
    pill reads "3 pillars"; the drill takes the whole screen. Nothing
    phone-only is minted.
  * **Canonical 347** on every state: both pages are pushed from the
    productivity gate, so each draws the corner back pill (bottom-END)
    itself and folds the full nav; it pops the newest step — the drill
    while one is open, else the page.
  * **`VisionRepositoryFacade` / `VisionRepositoryImpl`** over the
    productivity module's own read cmds through the platform gateway:
    `tenant.api.get_plan_on_a_page` / `get_visions` /
    `get_personal_mastery_goals` (`VisionCmds`, zero Dart callers before
    this) plus the three `ObjectiveCmds` frame 44c already asks. Pillars
    and objectives are required; the masthead and the KPI count are
    dress on the board and a failure there costs only the dress. The
    plan's vision is the doc's link, falling back to the tenant's one
    vision when the link is unset and exactly one exists. VIEW-FIRST
    (flag a): nothing here writes, and `commit_plan` stays unreachable.
  * **Models** (`vision_data.dart`): `Vision`, `Kpi`, `PlanBoard`,
    `MasteryGoal`, `MasteryTodo`, `planText` (a Text Editor field as one
    line). `Pillar` / `StrategicObjective` are frame 44c's, reused, and
    the pillar accent is `pillarAccent` from the picker, so the two
    screens agree on a pillar's colour.
  * **Honest gap, drawn honestly:** `get_personal_mastery_goals` is a
    `frappe.get_all` and returns title / description only — no `todos`
    rows. `MasteryGoal.todos` is read when the row carries them and is
    NULL otherwise, and a null draws no progress at all rather than
    "0 of 0". Extending the endpoint to send the child table is the
    backend follow-up that lights 792's bar and 793's lines.
  * Routes `/vision` and `/vision/mastery` registered; the launcher glance
    integration gains two `GlanceCardItem`s beside Tasks so the pages are
    reachable in hosts that compose launch_sdk. The hub-side door (rows
    under the manager hub's productivity group) is the commerce side of
    the section and is not in this release, like the tasks-row markers.
  * Tests: `test/vision_cluster_test.dart` (the board at three planes,
    the fold at one, the drill's selected card and detail pane, the
    mastery card's derived progress, the empty states) and
    `test/vision_repository_test.dart` (the gateway names asked, the
    vision resolution, `get_kpis` failing costing the count and not the
    board, `todos` read when sent and null when not).

## 1.3.2

* **The tasks page paints the theme ground again.** Every page-level
  `Scaffold` in `templates/pages/tasks/tasks_page.dart` (the list plane,
  the compose pane, the run pane and the objective picker) was built
  with `backgroundColor: AppStyle.transparent`, and nothing beneath the
  page paints a ground: base_sdk's `PlaneHost` lays its planes side by
  side over a bare seam and leaves an unclaimed plane an empty stage,
  `AdaptiveShell` adds nothing, and the app theme sets no
  `scaffoldBackgroundColor`. The page therefore showed the platform's
  raw surface — opaque black on Android — in BOTH theme modes: in light
  mode the `Tasks` title (`#1B1B20` ink) was invisible and the search
  field and sort segment sat as white boxes on black; in dark mode the
  ground was `#000000` instead of the theme's `#101010`. It showed up as
  the `productivity_tasks` still of the minilauncher guided tour. The
  four Scaffolds now paint `AppStyle.surfaceDark` — the per-mode surface
  token (light `#ECECEF`, dark `#101010`) that `task_run_page.dart` and
  calc's `CalculatorView` already paint — and the page paints the same
  token once behind the `PlaneHost`, so the seam and the empty stage on
  a wide window carry the ground too. No layout, control or handler
  changed.

## 1.3.1

* **A demo build no longer reports a failed sync.** `TaskPullService.pull`
  ran `api.projects.list_personal_tasks` even under
  `--dart-define=IS_DEMO=true`, where there is no backend by design, so
  every demo pull failed, set `lastFailure`, and the tasks page's empty
  state drew "Sync paused. Your tasks will sync when the connection is
  back." — a connection-failure notice on a build that has no connection
  to fail. It showed up as the `productivity_tasks` still of the
  paas_manager guided tour. The pull is now gated on `AppConstants.isDemo`,
  the same gate the other SDKs put in front of their network paths: in a
  demo build it resolves as a successful no-op (0 rows, `lastFailure`
  cleared, no telemetry, nothing on the wire). `TaskSyncNotice`, the
  `syncFailed` status and the telemetry event are unchanged for real
  builds. `TaskPullService.isDemoOverride` (`@visibleForTesting`) lets a
  test stand in a demo build, since the constant is fixed at compile time.

## 1.3.0

* **A failed task pull is no longer silent.** `TaskPullService.pull`
  used to catch every failure of the `api.projects.list_personal_tasks`
  pull and drop it, so a dead or uncomposed backend produced no
  telemetry and no visible state. Tasks stay local-first and the read
  path is untouched (`TodoRepositoryImpl` is not changed; `syncNow`
  still never throws and the page still kicks sync off unawaited) —
  what changed is that the failure is now observable:
  * **Telemetry.** Every failed pull emits one event on base_sdk's
    error lane (`TelemetryClient.I.logError`) with type
    `task_pull_failed` and a context of exactly two fields: `cmd`
    (the gateway cmd the pull was issued under) and `error_class`
    (`e.runtimeType.toString()`). Never the error text, which can
    carry a URL, a token or server-authored copy.
  * **A typed status.** `TaskPullService.lastFailure`
    (`ValueNotifier<TaskPullFailure?>`, plus the `syncFailed` getter)
    records the same cmd + error class and is cleared by the next
    pull that completes.
  * **One friendly line.** New `TaskSyncNotice` widget; the installed
    tasks page watches `lastFailure` and draws, in its empty state
    only, "Sync paused. Your tasks will sync when the connection is
    back." when the LOCAL list is empty and the last
    pull failed. A list with rows in it shows nothing new — no banner —
    and no cmd name, error class or error text ever reaches the screen.
* Version bumped past the open 1.2.0 (PR #33) so the two do not collide.

## 1.2.0

* Design strip **frame 44c — the M2 bridge**: linking a task to a
  strategic objective. Approved 2026-08-30; the amber NOT-IN-BACKEND
  flag the frame carried is now obsolete and is NOT drawn — both of
  its preconditions exist (`sync_personal_task` carries the link;
  tasks push through the outbox), so the link is real.
  * **834 the objective picker pane**, a 1-plane push that wins the
    last plane: header + count pill, the provenance note naming
    `get_strategic_objectives` / `get_pillars`, pillar filter tabs
    with counts (All pillars / one per pillar), the objective cards
    with a round radio, Cancel / Link objective at 2 : 3.
  * **787 the approved 41a objective card**, reused verbatim: title,
    pillar tag with its accent, KPI count — nothing added. The accent
    is DERIVED from the pillar's position in the pillar list (a pillar
    has no colour column) and the KPI count is DERIVED by counting
    `get_kpis`; there is no count field to read.
  * **833 the link row** in the task detail pane: what objective the
    task serves (pillar › title), and the door to the picker. A saved
    task is linked the moment Link objective is tapped; a task being
    composed keeps the link on the form until Save task, like every
    other field.
  * **`ObjectivesRepositoryFacade` / `ObjectivesRepositoryImpl`** over
    the productivity module's own read cmds through the platform
    gateway (`tenant.api.get_strategic_objectives` / `get_pillars` /
    `get_kpis`) — zero Dart callers before this. Read-only by
    construction: `commit_plan` is a destructive whole-plan replace
    and nothing in this SDK can reach it.
  * **`strategicObjective` on the task map** travels the way
    `stepsAreSequential` does — `TaskRequest` / `TaskResponse` and the
    existing `task.upsert` op — to Task's typed `strategic_objective`
    column (projects module, this release). Three wire states: absent
    is silence, `""` unlinks, a name links. A pull that unlinked wins
    over a stale local link; the handshake, which never carries the
    column, clears nothing. The title / pillar pair chip 833 reads is
    device bookkeeping beside the name and never goes to the wire.
  * The tasks page now builds the section-38 list flow as the
    `PlaneHost` stack `ListPlaneFlow` wraps, with the same page names
    and corner Back, because the picker is a THIRD step: list + detail
    slide left and the picker takes plane 3, as the frame draws.
* Design strip **frame 46i — the paused run on the hub's Tasks row**
  (approved 2026-08-30; 2026-08-31: 47j folds into it). Chip 859
  promoted to the hub row: ONE LINE on the existing Tasks row — not a
  new row, not a new group — naming which run is paused, which task it
  belongs to and where it stopped ("1 run paused · Month-end stock
  count, step 3 of 6", "kept from Thursday — resumes where it
  stopped"), and gone when no run is paused. Productivity half only.
  * **`PausedRunSummary`**, DERIVED from the task list through
    `TodoRepositoryFacade.loadTodos()` and `TaskRun.isInProgress` /
    `positionLabel`: no table, no flag anybody sets, most recently
    touched first. A paused maintenance run surfaces on identical
    terms to any other task.
  * **`pausedRunProvider`** (Riverpod, auto-disposed, the local store
    and nothing else) and **`PausedRunLine`** over it; loading and
    failure draw nothing. `PausedRunLineView` for a host or test that
    holds the derivation already.
  * **Two manifest integrations** for the merchants manager hub,
    declared exactly as the launcher glance is: the
    `// @productivity-tasks-row` marker (with its 8-space indent) takes
    the widget, `// @productivity-tasks-row-imports` at column 0 takes
    the import. The run opens by route path (`/tasks/run?task=<id>`)
    through `context.router`, so the hub never imports a page. The
    markers themselves are the COMMERCE side of the frame and are not
    in this release; until they land the composer reports the marker
    missing and skips the wiring.

## 1.1.0

* Design strip **section 46 — the guided run** (frames 46a, 46b, 46c,
  46f, 46g, 46i's badge) and the visible half of **section 47** (47k,
  47l, 47m, 47n). Both are GENERIC ON THE TASK: per the owner's ruling
  a maintenance run "is just a normal multi step task with reminder, it
  doesnt have any privilege", so there is no field, screen or string
  for any vertical anywhere in this release.
  * **The run is DERIVED state.** `TaskRun` (pure Dart, no store)
    reads a task's subtasks as steps: the current step is the first
    one not complete, a timed step's remaining time is
    `duration_seconds − (now − started_at)` recomputed on every read,
    and "finished" is every step done. Nothing is counted down in
    memory, so a run resumes after the app is killed with its
    wall-clock credit intact (ruling three). One `Timer.periodic` per
    page, alive only while a clock is running, asks for a repaint and
    nothing else. paas_pos's stage dialog — two timers per stage,
    ~2× fast, and an elapsed credit computed then discarded on resume —
    is deliberately NOT ported.
  * **Four generic step fields on a subtask** (server: `Task Subtask`
    in the projects module): `instruction` (shown under the active
    step's title), `durationSeconds` (0 = untimed, confirm-only — its
    Continue is live at once and it never auto-completes), `startedAt`
    (written once, never rewritten; no pause in v1) and `completedAt`.
    One flag on the task, `stepsAreSequential` (default false = the
    any-order checklist of today), gates the next step on the one
    before it. All travel through `TaskRequest` / `TaskResponse` and
    the existing `task.upsert` op; the server writes them through a
    meta-checked whitelist.
  * **Rulings rendered.** A blocked step cannot be skipped: the only
    block in the generic model is a clock, `TaskRun.complete` refuses
    while it runs, and chip 857 keeps Continue on screen, disabled,
    locked — never hidden — with the reason (856) naming the clock and
    the route out (858) honestly saying there is none but time; amber,
    never red. Abandoning keeps progress: Leave (866) writes nothing
    and `restart()` is the one destructive act, named Start over and
    tinted so on the resume card (860). Back (855) moves ONE step and
    keeps the reopened step's start.
  * **852 / 865** the step rail — "STEP 3 OF 9", "6 left", a
    three-state hairline, each done step with its outcome kept beside
    it; on one plane it folds to the compact rail (46f). **853** the
    step card, **872** its clock, **862** Skip for now — offered only
    on an any-order run, because a sequential run has no skip and a
    blocked step has none either. **859** the run badge on the task
    card, "Step 3 of 9" beside the derived progress, and a Run / Resume
    pill.
  * **Two hosts, one view.** On a wide window /tasks hosts
    `TaskRunView` in its detail plane (46a: "the run is 44a's detail
    plane, no new push"); at one plane the workspace pushes the new
    `/tasks/run?task=<id>` route (`TaskRunRoute`, template
    `task_run_page.dart`), which other SDKs may open by path without
    importing this one. Finishing a run does not tick the task by
    itself: the finished card offers "Mark task done", the route pops
    `true`, and the workspace acts on it.
  * **47k / 47l snooze**, wired to the shipped `snoozeReminder`:
    `TaskReminderRow` draws REMIND and DUE side by side (1061) with the
    invariant in words (1063) and the snooze control that counts itself
    (1060, `snoozeCount` is device bookkeeping); `showSnoozeSheet` offers
    three fixed offsets and a free pick with tomorrow morning
    pre-selected (1062) and hands back a reminder time and NOTHING else.
    The device-local notification moves with it. The deadline is not
    written anywhere on this path.
  * **47m the long-term band** (`LongTermBandHeader`, 1064): tasks with
    `isLongTerm` sit in a labelled band above the day's work, and the
    compose pane gains the toggle. The surfacing rule frame 47m
    proposed (recurrence ≠ None and cycle ≥ 7 days) awaits the owner's
    word and is NOT derived.
  * **47n the sync-state badge** (`TaskSyncBadge`, 1066 / 1067 / 1068
    plus the parked failure): derived by `taskSyncStateFor` from the
    two facts the device holds — a queued outbox op's status, and
    whether the row carries the server's id. There is no synced flag
    and none is invented; a pushed row's absence is the success signal.
    `TaskSyncQueue.statesFor` answers for the whole list in one query.
  * **The compose pane** lets a step carry an instruction and a
    duration in minutes (chip 831's composer grew two fields) and the
    task carry STEPS IN ORDER and LONG TERM. Editing an existing task
    now keeps the fields the form does not show (`remindAt`,
    `snoozeCount`, `stepsAreSequential`, the sync ids) instead of
    rebuilding the map from scratch; a rolled-over recurrence copies
    the procedure and clears the step timestamps
    (`TaskRunStep.freshCopy`). Nothing else about recurrence changed and
    no scheduling was added.
  * **Not built here, on purpose:** 46d / 46h first-run setup on the
    runner (onboarding_sdk, another repo), 46i's mid-run line on the
    hub's Tasks row (merchants_sdk, another repo — `TaskRun.isInProgress`
    and `positionLabel` are exported for it), 47d / 47e / 47h readings
    and setup gates and 47i's photo tile (the water thread's own
    doctypes, linked to Task by name; nothing of theirs lives on a
    subtask).
  * **Tests.** `test/task_run_test.dart` pins the derivation as plain
    Dart: current step, the sequential gate, remaining time from
    timestamps, resume after a kill, the confirm-only step, Back,
    Skip, Start over and the map round trip. `test/manifest_wiring_test.dart`
    pins the route declaration (the radio pattern).
    `test/task_section_47_test.dart` pins the snooze arithmetic, the
    sync-state derivation and the reminder row. The build environment
    had a Dart SDK but no Flutter toolchain: the pure run derivation
    and the models were analyzed and their tests executed, while the
    widget files and widget tests were parse-checked and read by hand.
    The PR body says so.

## 1.0.5

* **Task sync, client side.** The four personal-task endpoints landed
  server-side on 2026-08-31 (`projects/frappe/src/task_sync.py`) and
  nothing on the client called them; that commit said so itself. This is
  the wiring. The /tasks workspace now pushes to `sync_personal_task`
  and `delete_personal_task`, pulls from `list_personal_tasks`, and
  moves a reminder through `snooze_task_reminder`.
  * **IT IS ADDITIVE, AND THAT IS THE POINT.** The local store is still
    the source of truth for every read, and every write still lands in
    drift FIRST and returns. Not one user-facing path awaits a network
    round trip: a save queues an op on the SyncEngine outbox and asks
    the engine to drain WITHOUT waiting for it. There is no offline
    branch — the same code runs with a live backend and with none ever
    configured, and the only difference is how long an op sits in the
    outbox. A device that never reaches a server behaves exactly as it
    did before this change, and `test/task_sync_test.dart` pins that
    with no `HttpService` registered at all.
  * **The handshake is orders', copied rather than reinvented.** A task
    is born on the device with a locally minted `client_id`; that id
    travels with every push; the server upserts on it and hands back its
    real `name`, which lands on the local row. Retrying a create after a
    dropped connection therefore updates the same Task instead of making
    a second one — the same property `OrderCreateSyncHandler` relies on,
    reached the same way.
  * **`TasksTable` gains `client_id` and `remote_id`** (schema 15,
    `addColumn`). `client_id` is deliberately NOT the engine's
    `offline:<uuid>` temp-id convention: the engine rewrites those
    tokens inside pending payloads once it learns a mapping, which for a
    task would rewrite a queued upsert's key into the server's name and
    duplicate the task on the next push.
  * **Pushes coalesce.** The page saves the whole list on every action,
    so ops are queued with `enqueueOrReplace` keyed on `client_id` and
    only when the WIRE payload actually changed. Ten edits before the
    first successful push cost one outbox row carrying the latest
    snapshot.
  * **A pull never overwrites an unsent local edit.** A task with a
    queued op is skipped, because the device's copy is the newer one.
    Pulled tasks are merged onto the local row, so device-local
    bookkeeping the server does not carry (the notification id) survives.
  * **Snooze moves the reminder and NEVER the deadline.** The op carries
    no deadline field at all, the local write does not touch the
    `dueDate` column, and a response claiming `deadline_moved` is
    refused rather than applied.
  * **`TaskRequest` / `TaskResponse` rewritten** against the endpoints
    they were supposed to describe. They previously matched nothing:
    `TaskRequest` had no `clientId`, no `remindAt` and no subtasks.
    Absent fields are now OMITTED rather than sent as null, because the
    server reads a present key as an instruction and an absent one as
    silence.
  * **828 `LocalOnlyStrip` is REMOVED**, and only because it stopped
    being true. It said "no remote store, no sync"; there is now both.
    Nothing replaces it: a claim that these tasks ARE synced would be
    just as wrong for a host that composes this SDK without a backend.
    The flag it drew is struck from the page's own header comment rather
    than quietly dropped.
  * `ProductivitySdkDependencies.register` is now idempotent, matching
    every other SDK's hook — it threw on a second call.

## 1.0.4

* Design strip section 44 — **the /tasks workspace**, frames **44a**
  (list · detail), **44b** (the compose lane), **44d** (the phone fold)
  and **44e** (calendar mode). The page was BUILT and the screen was
  never designed; section 7e settled its door and explicitly deferred
  what lies behind it. This is that design pass.
  * **The plane claim, and the fork this closes.** Frame 44a's stamp
    reads "/tasks DECLARES 2 — HUB YIELDS TO 1", while section 7e had
    drawn /tasks landing in the bare trailing plane — a claim of one.
    The frame calls that "a choice, not a defect" and asks for it to be
    made explicitly rather than inherited. **Two is picked**, on 44a's
    stamp, and expressed through base_sdk's shipped `ListPlaneFlow`
    (`listSpan: PlaneSpan.two`) — the section-38 list flow, whose corner
    back pill (canonical 347) is raised only while a pane is open.
  * **44b is the reason the claim matters.** The shipped page built the
    whole compose form as an inline block **wedged above the list** —
    five `Expanded` rows of chips and dropdowns competing with the list
    for the same column. It now takes the LAST plane, so the list keeps
    its planes and stays legible while you type. No field is added and
    none is removed; create and edit stay ONE component with an empty
    model, exactly as the shipped page already treated them.
  * **825** `TaskCard` — the section-33 list card: 19px round checkbox,
    title struck through when done, the meta chip run (priority flag
    tinted red/amber/blue, deadline in the shipped
    `DateFormat('MMM dd, hh:mm a')`, category, recurrence, reminder
    bell), then the subtask progress. **That progress is DERIVED from
    the list and never read** — there is no progress field anywhere, the
    same honesty rule section 41 used for mastery goals.
  * **826** `SubtaskCheckLine` — deliberately the same shape as 41c's
    ToDo check line, so a task's subtasks and a mastery goal's todos
    read alike.
  * **827** `TaskSortSegment` — Created / Deadline / Priority as a 30px
    three-way segment. Promoted from the shipped `DropdownButton`
    because there are only three values and a dropdown hid two of them
    behind a tap.
  * **828** `LocalOnlyStrip` — flag (a), stated on the screen for the
    first time: these tasks live on this device only, no remote store,
    no sync. It names `TasksTable` and `TodoRepositoryImpl` in code type
    so a reader can go and check, sits above the first card at EVERY
    width including the phone, and is **not dismissible and not a
    warning tint** — the fact does not change between sessions.
  * **831** `SubtaskComposerRow` — dashed 44px row; dashed means nothing
    committed yet, the rule frame 43a used for the driver row.
  * **canonical 700 / 362 / 363** `TaskListHeader` and `TaskStatusTabs`
    — header with count pill, and All / Pending / Completed as
    colour-coded tabs carrying their own counts, re-dressing the shipped
    `ChoiceChip` row. Every count is derived from the same list the tabs
    filter.
  * **44d, the fold** — on one plane the detail pane has no phone form
    of its own: the card **expands in place**, keeping the shipped
    `ExpansionTile` behaviour, so the subtask check lines still reach
    the phone rather than becoming a second push. The expansion IS the
    fold.
  * **44e, calendar mode** — the shipped `TableCalendar` re-dressed in
    base tokens: today ringed in primary, the selected day filled
    primary, and a primary dot under any day a local task's `deadline`
    lands on. A mode of the list plane, not a screen.
* **Two flags ride the screen and are drawn rather than hidden.**
  `recurrence` is stored and **nothing ever acts on it** — no scheduler,
  no rollover, no next-instance creation anywhere in the SDK, so a task
  marked Daily is a label; the REPEATS quad is drawn because the field
  is real, and "None" is deliberately never drawn as a repeat chip.
  Reminders are **local notifications only**, and the toggle's sub-line
  says exactly that.
* **Nothing behavioural changed.** `_saveTask`, `_startEditing`,
  `_cancelEditing`, `_toggleTodo`, `_removeTodo`, `_addSubtask`,
  `_toggleSubtaskStatus`, `_toggleFormSubtaskStatus`, `_handleRecurrence`,
  `_pickDeadline`, `_exportData` and `_getFilteredAndSortedTodos` are
  the shipped implementations, untouched. What changed is where things
  are drawn.
* **Superseded but NOT deleted:** `_sortOptions` and `_getPriorityColor`
  fed the shipped dropdown and card tint and are now unreferenced. They
  are left in place with a note — nothing in this pass was asked to
  remove shipped code.
* **Testing.** The components live in `lib/` rather than in the template
  and take no host wiring — their imports are base_sdk, Flutter and the
  two leaf packages `flutter_screenutil` and `intl`, all four of them
  now declared in this package's `pubspec.yaml` (they had been resolving
  only transitively through base_sdk). That is what makes them testable:
  a widget test constructs one directly with no app shell. This
  package's two existing test files **cannot load on a bare checkout**
  because `build_runner` is not a dev_dependency and drift's and
  freezed's generated sources are therefore absent. That is unchanged
  here and pre-existing. Suite goes **0 passing / 2 failing to load →
  28 passing / the same 2 failing to load**. The template itself was
  verified by composing it with `${package}` substituted and analyzing
  that, since `templates/**` is excluded from analysis fleet-wide.

## 1.0.2

* **Fix: deleted tasks came back on the next start.** Removing a task on
  /tasks dropped it from the in-memory list and then called `saveTodos`, which
  only inserts and updates - it has no delete. The row stayed in `TasksTable`,
  so the next `loadTodos` read it straight back and every task the user had
  ever deleted reappeared. Deletion is now its own repository operation,
  `deleteTodo(id)`, and `_removeTodo` calls it with the id of the task it just
  removed.
* **Deletion is an operation, not an inference.** The obvious alternative -
  having `saveTodos` prune any row absent from the list it was handed - was
  rejected because `TasksTable` has a second writer. `TaskService` inserts and
  updates rows the tasks surface never sees, and nothing on a row records
  which writer put it there: the `createdBy` column is only ever echoed back
  from a row that was already loaded, so it is null for both writers and
  cannot scope a prune. A prune-on-save would therefore have deleted
  `TaskService`'s rows whenever the tasks page saved. Naming the id keeps the
  write to the one row the user actually deleted, and is correct no matter how
  ownership of the table is settled later.
* **Both halves are pinned by tests** against a real drift/SQLite database: a
  deleted task is absent after a genuine save-and-reload cycle, and a delete
  issued by the tasks surface leaves `TaskService`'s rows intact and readable.

## 1.0.1

* **Fix: /tasks lost everything but the name and the checkbox on restart.**
  `TasksTable` stores a task's subtasks, notification id, reminder flag,
  priority, category and recurrence in its `data` JSON column - the typed
  columns hold none of them. `saveTodos` wrote that column correctly, but
  `loadTodos` handed the column back as a raw, still-encoded string and never
  decoded it, so every one of those fields was silently dropped the next time
  the page opened. `loadTodos` now decodes the blob and rebuilds the full map,
  with the typed columns staying authoritative for the fields they own.
* **Rows without a usable blob keep loading.** A `data` column that is null,
  empty, malformed, or holds valid JSON that is not an object degrades to "no
  extras" for that one row instead of throwing - a decode that threw would
  have turned a silent loss into a tasks page that will not open at all, and
  dev databases written before this fix hold exactly those rows.
* **Save path hardened alongside it.** The row id is resolved once and stored
  in the blob as well, so a task saved without an id comes back under the id
  its row actually has; the transient `data` key is stripped before encoding,
  so a reloaded task can no longer nest one encoding inside the next on every
  save; and a task holding a value json cannot encode now loses only its own
  extras instead of aborting the transaction and the write for every other
  task in the list.
