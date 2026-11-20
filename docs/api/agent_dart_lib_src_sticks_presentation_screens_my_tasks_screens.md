# API Reference: my_tasks_screens

Source file: `agent/dart/lib/src/sticks/presentation/screens/my_tasks_screens.dart`

## Classes

### class `TaskCardView`

A task card under a Stick's reply: the steps, and "Add to My tasks".

### class `TaskCardWriting`

A Stick still writing its card: shown instead of the half-written block.

### class `MyTasksList`

The owner's own tasks, as rows for the Tasks page.

### class `MyTaskRunScreen`

One of the owner's tasks, run step by step with the productivity SDK's
guided run: a timer on each timed step, done in order, progress kept.

## Whitelisted API Endpoints

### `TaskCardView`

```dart
const TaskCardView({
  super.key,
  required this.card,
  required this.messageId,
  this.from,
})
```

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `didChangeDependencies()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `TaskCardWriting({super.key})`

*No documentation provided (generation failed).*

### `MyTaskRunScreen({super.key, required this.taskId})`

*No documentation provided (generation failed).*
