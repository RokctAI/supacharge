# API Reference: chat_attach

Source file: `agent/dart/lib/src/sticks/presentation/screens/chat_attach.dart`

## Classes

### class `PickedAttachment`

A photo or file picked for the next message.

### class `AttachTray`

Above the chat bar: what will go with the next message, each with a way
to take it off, and Send for when there are no words to go with them.

## Whitelisted API Endpoints

### `PickedAttachment`

```dart
const PickedAttachment({
  required this.name,
  required this.mimeType,
  required this.bytes,
})
```

*No documentation provided (generation failed).*

### `mimeTypeFor(String name)`

The type the server is told, from the file's name.

### `pickAttachments(AttachSource source)`

*No documentation provided (generation failed).*

### `askAttachSource(BuildContext context)`

Asks where to attach from; null if cancelled.

### `AttachTray`

```dart
const AttachTray({
  super.key,
  required this.items,
  required this.onRemove,
  this.onSend,
})
```

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*
