# API Reference: sticks_shell

Source file: `agent/dart/lib/src/sticks/presentation/screens/sticks_shell.dart`

## Classes

### class `SticksTopNav`

The floating nav on a top-level page that is not one of the four tabs
(inbox, Stick talk, calls, settings, team chats, board, search and the
other menu pages), so it shows on every top-level page as in the tabs.
No tab is marked; picking one goes back to the shell on that tab via
[onTab]. A big screen has the three panels instead and gets no pill.

### class `SticksShell`

The four tabs: Team, Tasks, Asks, Reports. Navigated with the shared
[FloatingBottomNav] in tabs mode, like every other fleet app.

## Whitelisted API Endpoints

### `SticksTopNav({super.key, required this.child, required this.onTab})`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `SticksShell({super.key, this.initialTab = 0})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*
