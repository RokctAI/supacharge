# API Reference: task_run_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/task_run_screen.dart`

## Classes

### class `TaskRunScreen`

One task: the Stick's plan as a checklist (done, doing, still to do) on a
sheet the Stick peeks over. A task without `steps` shows its status,
priority, due date and note instead. When it waits on the owner, the ask
is one tap away.

## Whitelisted API Endpoints

### `TaskRunScreen({super.key, required this.taskId})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `paint(Canvas canvas, Size size)`

*No documentation provided (generation failed).*

### `shouldRepaint(_ArcPainter o)`

*No documentation provided (generation failed).*

### `nobodyStick(List<Stick> team)`

Stands in for the Stick on a task no Stick holds: plain grey, named
"No one". Null only when there is no Stick at all to borrow a figure from.
