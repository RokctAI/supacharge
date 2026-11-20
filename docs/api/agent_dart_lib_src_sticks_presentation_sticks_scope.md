# API Reference: sticks_scope

Source file: `agent/dart/lib/src/sticks/presentation/sticks_scope.dart`

## Classes

### class `SticksNav`

Where a Sticks screen can go. The host's router implements this (see the
installed `sticks_pages.dart`); [SticksApp] has a Navigator-based one so
the screens also run on their own.

### class `SticksScope`

Carries the data source and navigation to every Sticks screen, and
rebuilds them when the data source reports a change.

### class `StickPalette`

The app's paper, ink and rules in light and dark. The Sticks themselves
never change with the theme.

## Whitelisted API Endpoints

### `openStick(String id)`

*No documentation provided (generation failed).*

### `openProfile(String id)`

*No documentation provided (generation failed).*

### `openTask(String id)`

*No documentation provided (generation failed).*

### `openAsk(String stickId)`

*No documentation provided (generation failed).*

### `openGiveTask({String? stickId})`

*No documentation provided (generation failed).*

### `openHire()`

*No documentation provided (generation failed).*

### `openSetup({String? role, bool animated = false})`

The setup panel for a new Stick. [animated] plays the first-run intro:
a beam of light, a naked Stick, then the room lights up.

### `openReport()`

*No documentation provided (generation failed).*

### `openTalk()`

*No documentation provided (generation failed).*

### `openInbox({String? forWho})`

*No documentation provided (generation failed).*

### `openCalls()`

*No documentation provided (generation failed).*

### `openMore(String screen, {String? id})`

One of the [MoreScreens] (`screen` is its key, e.g. `routines`).

### `openSettings()`

*No documentation provided (generation failed).*

### `openLock()`

*No documentation provided (generation failed).*

### `back()`

*No documentation provided (generation failed).*

### `SticksScope`

```dart
SticksScope({
  super.key,
  required this.data,
  this.extras,
  required this.nav,
  required this.child,
  SticksPrefs? prefs,
  MyTasks? myTasks,
  MyNotes? notes,
})
```

*No documentation provided (generation failed).*

### `of(BuildContext context)`

*No documentation provided (generation failed).*

### `maybeOf(BuildContext context)`

The scope above [context], or null outside one.

### `createState()`

*No documentation provided (generation failed).*

### `initState()`

*No documentation provided (generation failed).*

### `didUpdateWidget(SticksScope old)`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `updateShouldNotify(_Inherited o)`

*No documentation provided (generation failed).*
