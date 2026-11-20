# API Reference: task_edit

Source file: `agent/dart/lib/src/sticks/presentation/screens/task_edit.dart`

## Classes

### class `TaskComments`

A task's comments, oldest first, with a box to add one. Hidden when the
server has no extras (the demo always has them).

## Whitelisted API Endpoints

### `showTaskSheet`

```dart
Future<bool> showTaskSheet(
  BuildContext context,
  {StickTask? task, required List<Stick> team}
)
```

A sheet to put a new task on the board ([task] null) or change one:
title, note, which Stick, and priority. True once it saved.

### `createState()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `TaskComments({super.key, required this.taskId, this.team = const []})`

*No documentation provided (generation failed).*

### `didChangeDependencies()`

*No documentation provided (generation failed).*
