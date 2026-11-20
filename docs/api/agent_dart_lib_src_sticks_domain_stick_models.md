# API Reference: stick_models

Source file: `agent/dart/lib/src/sticks/domain/stick_models.dart`

## Classes

### class `StickLook`

How a Stick looks. The server may send hints (`look` in `list_sticks`);
without them the look comes from [StickLooks] so no two Sticks on a team
look alike.

### class `Stick`

One Stick as `api.sticks.list_sticks` returns it.

### class `StickActivity`

One line of a Stick's day: when, and what it did.

### class `TaskStep`

One step of a task's plan (`steps`, optional on a task): what the Stick
does, a short detail, and how far it got.

### class `StickTask`

One task as `api.sticks.get_task_feed` returns it.

### class `ConfirmOption`

### class `ConfirmInput`

A field the owner types into to answer a confirm: a password, a website
login, a code or a free answer. [hidden] values are typed masked and are
never shown again or kept by the app.

### class `StickDraft`

An outward action a Stick drafted for the owner to approve.

### class `StickConfirm`

An ask only the owner can answer, as `api.sticks.get_confirm` returns it:
a plain confirm, a permission to share sensitive data, or a draft.

### class `ConfirmAnswered`

What `api.sticks.answer_confirm` says came of an answer.

### class `MessageAttachment`

### class `StickMessage`

One message between two Stick-or-owner parties (`api.sticks.list_inbox`).

### class `ToolStep`

One tool a Stick used while writing a reply, and how many times in a row.

### class `RoleHold`

### class `RoleOption`

A role choice from `api.sticks.list_roles`.

### class `ReportRow`

One row of the weekly report (the last seven days), worked out on the
phone from the task feed.

### class `StickNotification`

### class `CallLine`

One line of a call, said by the Stick or by the person called.

### class `StickCall`

A call a Stick makes for the owner, as `api.sticks.list_calls` returns it.
[outcome] is the server's one-line result. The script is what the owner
approved; the transcript is what was said.

## Whitelisted API Endpoints

### `StickLook`

```dart
const StickLook({
  required this.skin,
  required this.skinShade,
  required this.clothes,
  required this.clothesShade,
  required this.hair,
  required this.dress,
  required this.glasses,
  required this.hairStyle,
  required this.prop,
})
```

*No documentation provided (generation failed).*

### `Stick`

```dart
const Stick({
  required this.id,
  required this.name,
  required this.role,
  required this.look,
  required this.accent,
  required this.status,
  required this.mood,
  required this.statusText,
  this.hours = '',
  this.backAt,
  this.owns = const [],
  this.openConfirms = 0,
  this.activity = const [],
  this.lastActive,
  this.pinned = false,
  this.folder,
  this.unread = false,
})
```

*No documentation provided (generation failed).*

### `StickActivity(this.at, this.text)`

*No documentation provided (generation failed).*

### `TaskStep(this.title, {this.detail, this.state = TaskState.todo})`

*No documentation provided (generation failed).*

### `StickTask`

```dart
const StickTask({
  required this.id,
  required this.stickId,
  required this.title,
  required this.state,
  this.priority = 'normal',
  this.due,
  this.note,
  this.confirmId,
  this.steps = const [],
  this.board,
})
```

*No documentation provided (generation failed).*

### `ConfirmOption(this.key, this.label, {this.primary = false})`

*No documentation provided (generation failed).*

### `ConfirmInput(this.label, {this.hidden = false, this.optional = false})`

*No documentation provided (generation failed).*

### `StickDraft`

```dart
const StickDraft({
  required this.channel,
  this.to = const [],
  this.subject = '',
  this.body = '',
  this.attachments = const [],
})
```

*No documentation provided (generation failed).*

### `StickConfirm`

```dart
const StickConfirm({
  required this.id,
  required this.kind,
  required this.stickId,
  required this.question,
  required this.options,
  this.requesterId,
  this.dataLabel,
  this.messageId,
  this.taskId,
  this.deadline,
  this.draft,
  this.inputs = const [],
  this.skipKey,
})
```

*No documentation provided (generation failed).*

### `ConfirmAnswered({required this.already, required this.answer})`

*No documentation provided (generation failed).*

### `MessageAttachment(this.ref, this.label)`

*No documentation provided (generation failed).*

### `StickMessage`

```dart
const StickMessage({
  required this.id,
  required this.fromId,
  required this.toId,
  required this.kind,
  required this.body,
  required this.status,
  this.sentAt,
  this.read = true,
  this.sensitive = false,
  this.confirmId,
  this.replyTo,
  this.taskId,
  this.attachments = const [],
  this.seq,
  this.steps = const [],
  this.stepsTook,
})
```

*No documentation provided (generation failed).*

### `ToolStep(this.label, [this.count = 1])`

*No documentation provided (generation failed).*

### `RoleHold(this.key, this.label, {this.sensitive = false})`

*No documentation provided (generation failed).*

### `RoleOption`

```dart
const RoleOption(
  this.key,
  this.label,
  {this.owns = const [], this.holds = const []}
)
```

*No documentation provided (generation failed).*

### `reportEnd(DateTime today, int? weekday)`

The day the report ends on: today when [weekday] is null (a rolling
week), else the latest [weekday] (1 Monday .. 7 Sunday) up to today.

### `ReportRow(this.stickId, this.tasksDone)`

*No documentation provided (generation failed).*

### `StickNotification(this.stickId, this.title, this.body, this.when)`

*No documentation provided (generation failed).*

### `CallLine(this.stick, this.text)`

*No documentation provided (generation failed).*

### `StickCall`

```dart
const StickCall({
  required this.id,
  required this.stickId,
  required this.who,
  required this.number,
  required this.purpose,
  required this.status,
  this.outcome,
  this.at,
  this.script = const [],
  this.transcript = const [],
})
```

*No documentation provided (generation failed).*
