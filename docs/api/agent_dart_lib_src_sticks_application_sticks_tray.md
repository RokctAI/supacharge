# API Reference: sticks_tray

Source file: `agent/dart/lib/src/sticks/application/sticks_tray.dart`

## Classes

### class `SticksTray`

The Windows tray icon. Closing the window hides Sticks to the tray instead
of quitting, so the minimized check (and its toast) keeps running; the
tray menu has Open and Quit, and a click on the icon opens the window.
Windows only, fail-open: on any other platform [start] does nothing, and
if the tray cannot start the window closes normally.

## Whitelisted API Endpoints

### `start()`

*No documentation provided (generation failed).*
