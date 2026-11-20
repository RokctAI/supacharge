# API Reference: my_task_card

Source file: `agent/dart/lib/src/sticks/domain/my_task_card.dart`

## Classes

### class `MyTaskCardStep`

One step of a [MyTaskCard]. [minutes] only when the step needs a timer.

### class `MyTaskCard`

What a Stick hands the owner to do: a short title and the steps in order.

### class `TaskCardSplit`

A message body split around its task card.

### class `TaskCards`

### class `OwnerTasks`

The owner's open tasks, kept in the instructions of each Stick the owner
lets see them ("Can see My tasks", off by default; Ray 2026-11-07). For
context only: the Stick may remind or advise, never change them. A task
marked private (`sticksPrivate`) is never in it.

## Whitelisted API Endpoints

### `MyTaskCard(this.title, this.steps)`

*No documentation provided (generation failed).*

### `toTodo({required String id, String? from, DateTime? now})`

The card as a task in the productivity SDK's vocabulary (the map its
tasks page and guided run read): each step a subtask, a timed step's
clock in `durationSeconds`, done in order.

### `TaskCardSplit(this.text, this.card, {this.writing = false})`

*No documentation provided (generation failed).*

### `split(String body)`

[body] with its first task card taken out. A card that does not read
is left in the text as the Stick wrote it, so nothing is lost.

### `parse(String raw)`

Reads the inside of a card: JSON (`{"title", "steps": [{"step",
"minutes"}]}`), or, forgiving a Stick that wrote it by hand, a title
line and one `- step (20 min)` line per step.

### `has(String instructions)`

Whether [instructions] carry the current rule exactly once.

### `apply(String instructions, {bool on = true})`

[instructions] with the block in place (where it already is, else at
the end), or taken out. Idempotent, and trimmed the way the server
stores it.

### `body(List<Map<String, dynamic>> tasks)`

The block's words for [tasks]: open, not private, newest first as
given; null when there is nothing to share.

### `apply(String instructions, String? body)`

[instructions] with the block replaced by [body], or taken out when
[body] is null. Idempotent, and trimmed the way the server stores it.

### `strip(String instructions)`

[instructions] without the block: what the owner edits.

### `read(String instructions)`

The block's words in [instructions], or null.

### `keep(String edited, String original)`

[edited] (instructions the owner changed, shown without the block)
with [original]'s block kept.
