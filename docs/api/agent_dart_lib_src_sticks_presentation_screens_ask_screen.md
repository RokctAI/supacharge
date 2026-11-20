# API Reference: ask_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/ask_screen.dart`

## Classes

### class `AskScreen`

An ask only the owner can answer, drawn from the confirm the server
sends: a plain confirm, a permission to share sensitive data, or a draft
of something that leaves the company (email, call, payment, post).
Nothing goes out until the owner answers; the screen renders exactly the
options it is given, in their order, and sends back the key.
Layout: the Stick that is asking stands in its own colour at the top (the
profile band), the chain of who asked whom runs under it, the thing being
asked about sits on the desk as a slip, and the answers wait in a dock at
the bottom so they never scroll away.

### class `AsksTab`

The Asks tab: every Stick that has a confirm waiting on the owner.

### class `EmptyState`

A calm empty page with a full Stick on it.

## Whitelisted API Endpoints

### `AskScreen({super.key, required this.stickId})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `flush()`

*No documentation provided (generation failed).*

### `AsksTab({super.key})`

*No documentation provided (generation failed).*

### `EmptyState`

```dart
const EmptyState({
  super.key,
  required this.title,
  required this.line,
  this.action,
  this.actionLabel,
})
```

*No documentation provided (generation failed).*
