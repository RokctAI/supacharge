# API Reference: give_task_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/give_task_screen.dart`

## Classes

### class `GiveTaskScreen`

Give a task in plain words to one Stick. It goes as a message from the
owner (`api.sticks.send_message`, kind `ask`); the Stick plans the steps
itself and asks before anything leaves the company. A Stick that is off
shift gets it held until its next shift, the way a note waits at reception.
The task is typed in the shared floating composer (base_sdk
[FloatingNavControlsMode], the same bar a lesson chats in), so the line
being typed rides on the keyboard. Who it goes to is the bar's target
chip ("To Nandi"); tapping it grows the bar upward into a short picker:
the Sticks working now, then pinned, then the most recently active, with
search for everyone else. A team of a hundred never becomes one row.

### class `SticksModelPanel`

Which model the picked Stick thinks with: the space's default or one of
the server's models. Saved on the Stick, so its next tasks use it too.

### class `SticksModelPanelState`

## Whitelisted API Endpoints

### `GiveTaskScreen({super.key, this.stickId})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `pickerOrder(List<Stick> sticks)`

Sticks in the order the picker offers them: busy now first, then
pinned, then the most recently active, then by name.

### `activeAgo(DateTime? t, {DateTime? now})`

"Active 5 min ago", "Active yesterday"; empty when unknown.

### `initState()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `SticksModelPanel`

```dart
const SticksModelPanel({
  super.key,
  required this.stickId,
  required this.name,
  required this.onDone,
  this.keyPrefix = 'sticks.give.model',
})
```

*No documentation provided (generation failed).*

### `row(String label, bool on, VoidCallback tap, {Key? key})`

*No documentation provided (generation failed).*

### `label(String t)`

*No documentation provided (generation failed).*

### `row(Stick s)`

*No documentation provided (generation failed).*

### `step(IconData icon, String text, {bool you = false})`

*No documentation provided (generation failed).*
