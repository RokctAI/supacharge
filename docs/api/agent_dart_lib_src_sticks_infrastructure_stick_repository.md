# API Reference: stick_repository

Source file: `agent/dart/lib/src/sticks/infrastructure/stick_repository.dart`

## Classes

### class `StickRepository`

[StickData] over the Sticks call contract. Replies are the value inside
Frappe's `message` envelope; an already-unwrapped body is tolerated, as
the other agent repositories do. A failure is thrown, never faked: the
screens show a retry line.

## Whitelisted API Endpoints

### `fire()`

*No documentation provided (generation failed).*

### `StickRepository(this._call)`

*No documentation provided (generation failed).*

### `sticks()`

*No documentation provided (generation failed).*

### `stick(String id)`

*No documentation provided (generation failed).*

### `tasks({String? stickId})`

*No documentation provided (generation failed).*

### `confirm(String stickId)`

*No documentation provided (generation failed).*

### `answerConfirm`

```dart
Future<ConfirmAnswered> answerConfirm(
  String confirmId,
  String key,
  {String? note, List<String>? values}
)
```

*No documentation provided (generation failed).*

### `inbox(String forWho, {bool unreadOnly = false})`

*No documentation provided (generation failed).*

### `markRead(String stickId)`

*No documentation provided (generation failed).*

### `stopReply(String stickId)`

*No documentation provided (generation failed).*

### `clearChat(String stickId)`

*No documentation provided (generation failed).*

### `react(String stickId, String messageId, String reaction)`

*No documentation provided (generation failed).*

### `markUnread(String stickId, String messageId)`

*No documentation provided (generation failed).*

### `watchChat(String stickId)`

The gateway has no live connection; open screens reload on [changes].

### `setShortReplies(bool on, {Set<String>? seesMyTasks})`

*No documentation provided (generation failed).*

### `setOwnerTasks(String stickId, String? body)`

*No documentation provided (generation failed).*

### `setBlindMode(String stickId, bool on)`

*No documentation provided (generation failed).*

### `hasOlder(String stickId)`

*No documentation provided (generation failed).*

### `loadOlder(String stickId)`

*No documentation provided (generation failed).*

### `retrySend(String messageId)`

The gateway sends at once and keeps no outbox.

### `discardSend(String messageId)`

*No documentation provided (generation failed).*

### `sendMessage`

```dart
Future<MessageStatus> sendMessage({
  required String to,
  required MessageKind kind,
  required String body,
  String? replyTo,
  String? replyQuote,
  String? taskId,
  List<MessageAttachment> attachments = const [],
})
```

*No documentation provided (generation failed).*

### `roles()`

*No documentation provided (generation failed).*

### `createStick`

```dart
Future<Stick> createStick({
  required String fullName,
  required bool woman,
  required String roleKey,
  String? hours,
  StickLook? look,
})
```

*No documentation provided (generation failed).*

### `hex(Color c)`

*No documentation provided (generation failed).*

### `calls({String? stickId})`

*No documentation provided (generation failed).*

### `lines(Object? v)`

*No documentation provided (generation failed).*

### `weeklyReport({DateTime? until})`

*No documentation provided (generation failed).*

### `notifications()`

*No documentation provided (generation failed).*
