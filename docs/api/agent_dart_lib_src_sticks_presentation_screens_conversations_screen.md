# API Reference: conversations_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/conversations_screen.dart`

## Classes

### class `ConversationsScreen`

Between Sticks: every message from one Stick to another, read-only for
the owner. A sensitive request waits here until the owner allows it; the
Stick that holds the data is the one that asks.

### class `MessageBubble`

One message with who sent it, who it is for, and what became of it.

### class `ToolStepsRow`

"Done · 3 tools · 12s" under a reply; tap it to see each tool the Stick
used, as the original app lists them.

### class `WorkingRow`

"Working… Searching the web" while a Stick is busy with a tool.

### class `LookingIcon`

The Sticks app icon (a white face, two eyes, a smile) in a small
squircle, looking around while a Stick works (Ray, 2026-11-07: "take the
app icon and animate it… maybe it just looks around"). The eyes glance
left, right and up, and blink now and then; with animations turned off
in the system settings it holds still.

## Whitelisted API Endpoints

### `ConversationsScreen({super.key})`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `MessageBubble`

```dart
const MessageBubble({
  super.key,
  required this.m,
  required this.team,
  this.onOpenAsk,
  this.footer,
  this.onUnsent,
  this.latest = false,
  this.onHold,
})
```

*No documentation provided (generation failed).*

### `ToolStepsRow(this.steps, {super.key, this.took})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `WorkingRow(this.doing, {super.key})`

*No documentation provided (generation failed).*

### `LookingIcon({super.key, this.size = 22})`

*No documentation provided (generation failed).*

### `didChangeDependencies()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `look(double t)`

*No documentation provided (generation failed).*

### `open(double t)`

A quick blink just after the eyes come back to the centre.

### `paint(Canvas canvas, Size size)`

*No documentation provided (generation failed).*

### `shouldRepaint(_LookingFace old)`

*No documentation provided (generation failed).*
