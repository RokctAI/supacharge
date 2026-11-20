# API Reference: stick_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/stick_screen.dart`

## Classes

### class `StickScreen`

One Stick: the live feed of what it is doing, and its tasks for today.

### class `StickFeed`

The "Now" timeline: the Stick's day, newest first, on a thin rule. The
newest line is live while the Stick is on shift. Without `activity` from
the server it is one line, the status.

### class `TaskCard`

A task row: title, progress bar and how far along it is ("3 of 4 steps").

### class `StickHero`

The tinted band with the full Stick standing on it.

## Whitelisted API Endpoints

### `StickScreen({super.key, required this.stickId})`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `TaskCard({super.key, required this.task})`

*No documentation provided (generation failed).*

### `progress(StickTask t)`

*No documentation provided (generation failed).*

### `label(StickTask t)`

*No documentation provided (generation failed).*

### `StickHero`

```dart
const StickHero({
  super.key,
  required this.stick,
  required this.subtitle,
  this.onTitleTap,
})
```

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*
