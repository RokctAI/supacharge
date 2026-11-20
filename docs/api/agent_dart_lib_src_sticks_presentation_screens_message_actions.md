# API Reference: message_actions

Source file: `agent/dart/lib/src/sticks/presentation/screens/message_actions.dart`

## Classes

### class `MessageSpeaker`

Reads Stick messages aloud in the Stick's voice from the server, one at
a time: a new one, or [stop], ends the one playing.

### class `ReplyBar`

Above the chat bar while answering one message: who it answers and the
words quoted (or the start of the message), with a way out.

## Whitelisted API Endpoints

### `speak(StickExtras extras, String stickId, String messageId, String text)`

Reads [text] (Markdown) aloud for [stickId]. Returns false when the
server has no voice set up; throws when it could not be read.

### `stop()`

*No documentation provided (generation failed).*

### `showSelectText(BuildContext context, String text)`

The message's words, selectable, in a sheet (Select text).

### `pickQuote(BuildContext context, String text)`

Asks which words of the message to quote; null if cancelled. Nothing
selected quotes it all.

### `ReplyBar`

```dart
const ReplyBar({
  super.key,
  required this.name,
  required this.words,
  required this.onCancel,
})
```

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*
