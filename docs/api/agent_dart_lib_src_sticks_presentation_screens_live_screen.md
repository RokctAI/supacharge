# API Reference: live_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/live_screen.dart`

## Classes

### class `LiveScreenPage`

A Stick's computer screen, live and view only: you watch, it works.
The server hands out a screen page (noVNC) whose address carries a
pass that lasts about an hour; it is read again every 50 minutes while
the page is open. Touches never reach the screen. On Windows, where the
app has no web view, the page opens in the browser instead.

## Whitelisted API Endpoints

### `LiveScreenPage`

```dart
const LiveScreenPage({
  super.key,
  required this.name,
  required this.read,
  this.viewer,
  this.inApp,
})
```

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `initState()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `didUpdateWidget(_ScreenWebView old)`

*No documentation provided (generation failed).*
