# API Reference: sticks_app

Source file: `agent/dart/lib/src/sticks/presentation/sticks_app.dart`

## Classes

### class `SticksRoutes`

Route paths of the Sticks flavor, also the ones in the manifest.

### class `SticksPage`

Each screen on a paper page with the safe area applied, so a host route
page is just `SticksPage(child: ...)`.

### class `NavigatorSticksNav`

A [SticksNav] on a plain Navigator. [SticksApp] uses it; a host with its
own router implements [SticksNav] instead.

### class `SticksApp`

The Sticks screens as a small app of their own: used by tests and by a
host that wants the whole flavor behind one route.

### class `BlindGate`

Opens on blind mode while a blind Stick is set (Profile > Advanced >
Blind mode), and on [child] once it is turned off.

## Whitelisted API Endpoints

### `SticksPage({super.key, required this.child})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `sticksTheme(ThemeData base, StickPalette p)`

The host theme with the Sticks colours, so switches, buttons, fields,
pickers and loaders take the app's ink and paper instead of the host's
default blue.

### `openStick(String id)`

*No documentation provided (generation failed).*

### `openProfile(String id)`

*No documentation provided (generation failed).*

### `openTask(String id)`

*No documentation provided (generation failed).*

### `openAsk(String id)`

*No documentation provided (generation failed).*

### `openGiveTask({String? stickId})`

*No documentation provided (generation failed).*

### `openHire()`

*No documentation provided (generation failed).*

### `openSetup({String? role, bool animated = false})`

*No documentation provided (generation failed).*

### `openReport()`

*No documentation provided (generation failed).*

### `openSettings()`

*No documentation provided (generation failed).*

### `openLock()`

*No documentation provided (generation failed).*

### `openTalk()`

*No documentation provided (generation failed).*

### `openInbox({String? forWho})`

*No documentation provided (generation failed).*

### `openCalls()`

*No documentation provided (generation failed).*

### `openMore(String screen, {String? id})`

*No documentation provided (generation failed).*

### `back()`

*No documentation provided (generation failed).*

### `SticksApp`

```dart
const SticksApp({
  super.key,
  required this.data,
  this.extras,
  this.themeMode = ThemeMode.system,
  this.firstRun = false,
  this.prefs,
  this.myTasks,
})
```

*No documentation provided (generation failed).*

### `BlindGate({super.key, required this.child})`

*No documentation provided (generation failed).*
