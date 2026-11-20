# API Reference: sticks_screens_test

Source file: `agent/dart/test/sticks_screens_test.dart`

## Classes

### class `FixtureGateway`

A gateway over the demo fixtures, the way a demo session answers: one
file per cmd, `$demo_select` by payload field, `$now_iso` offsets.

## Whitelisted API Endpoints

### `call(String cmd, Map<String, dynamic> payload)`

*No documentation provided (generation failed).*

### `watchChat(String stickId)`

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

### `attach`

```dart
Future<String?> attach(
  String stickId,
  {required String name, required String mimeType, required Uint8List bytes}
)
```

*No documentation provided (generation failed).*

### `inbox(String forWho, {bool unreadOnly = false})`

*No documentation provided (generation failed).*

### `hasOlder(String stickId)`

*No documentation provided (generation failed).*

### `loadOlder(String stickId)`

*No documentation provided (generation failed).*

### `markRead(String stickId)`

*No documentation provided (generation failed).*

### `main()`

*No documentation provided (generation failed).*

### `painting(StickMood mood)`

*No documentation provided (generation failed).*

### `attach(String from)`

*No documentation provided (generation failed).*

### `hold()`

*No documentation provided (generation failed).*

### `st(String id, StickStatus s, {DateTime? at, bool pin = false})`

*No documentation provided (generation failed).*

### `l(StickGender g)`

*No documentation provided (generation failed).*

### `any(String role)`

*No documentation provided (generation failed).*

### `px(num v)`

*No documentation provided (generation failed).*
