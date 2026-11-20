# API Reference: more_screens

Source file: `agent/dart/lib/src/sticks/presentation/screens/more_screens.dart`

## Classes

### class `MoreScreens`

The screens behind `/sticks/more?screen=<key>&id=<id>`: everything a
Stick does beyond tasks and asks. [MoreScreens.keys] lists the keys.

### class `MoreIndexScreen`

Everything beyond the team, tasks and asks, in one list.

### class `RoutinesScreen`

A Stick's routines: work it does on a schedule without being asked.

### class `RoutineScreen`

One routine: what it does, when, and its past runs.

### class `MemoryScreen`

What a Stick remembers between tasks. You can correct or remove a note.

### class `ComputerScreen`

A Stick's own computer: is it on, and who is at the screen.

### class `WorkScreen`

Artifacts: the files and pages the Sticks made. From the account it
lists every Stick's, with a chip per Stick to narrow it and a search.

### class `TeamChatsScreen`

### class `TeamChatScreen`

### class `NewTeamChatScreen`

### class `SearchScreen`

### class `ArchivedScreen`

### class `ApprovalRulesScreen`

### class `ConnectedAppsScreen`

### class `SpacesScreen`

### class `BoardScreen`

Every task by column. Drag a card to another column (long-press on a
phone), or use its menu.

### class `NotepadScreen`

A Stick's notepad: what it is keeping track of while it works.

### class `ActivityScreen`

### class `UsageScreen`

### class `BrainScreen`

Which model a Stick thinks with: the space's default or one picked.

### class `StickSettingsScreen`

Everything about one Stick that the original app keeps under its name:
model and thinking, its computer, voice, permissions, label,
instructions, notifications, open work, routines, artifacts, and
archive or delete.

### class `PasswordScreen`

### class `VaultScreen`

### class `ModelsScreen`

The models on the server, and which one every Stick without its own uses.

### class `VaultAddSheet`

Adds a login, key, card or address to the Vault. The values go to the
server once, in this call, and the fields are cleared after.

### class `ConnectAppSheet`

The apps the server can connect, with search. Tapping one opens its
sign-in page in the browser, then checks every two seconds (for two
minutes at most, and only while this is open) until it is connected.

## Whitelisted API Endpoints

### `build(String key, String? id)`

The screen for [key]. [id] is a Stick id for the per-Stick screens, a
chat id for `chat`, and `stickId|routineId` for `routine`.

### `createState()`

*No documentation provided (generation failed).*

### `didChangeDependencies()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `ListView`

```dart
ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: children)
```

*No documentation provided (generation failed).*

### `scheduleWords(String cron)`

Plain words for a cron line; anything else shows as written.

### `MoreIndexScreen({super.key})`

*No documentation provided (generation failed).*

### `who(String? id)`

*No documentation provided (generation failed).*

### `TeamChatScreen({super.key, required this.chatId})`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `stick(String? id)`

*No documentation provided (generation failed).*

### `SearchScreen({super.key})`

*No documentation provided (generation failed).*

### `BoardScreen({super.key})`

*No documentation provided (generation failed).*

### `move(StickTask t, BoardColumn to)`

*No documentation provided (generation failed).*

### `card(StickTask t)`

*No documentation provided (generation failed).*

### `column(BoardColumn c, double width)`

*No documentation provided (generation failed).*

### `ActivityScreen({super.key})`

*No documentation provided (generation failed).*

### `money(double? v)`

*No documentation provided (generation failed).*

### `count(int? v)`

*No documentation provided (generation failed).*

### `group(String label, List<Widget> rows)`

*No documentation provided (generation failed).*

### `toggle`

```dart
Widget toggle(
  String title,
  bool on,
  Future<void> Function(bool) write,
  {String? sub}
)
```

*No documentation provided (generation failed).*

### `field(TextEditingController c, String hint)`

*No documentation provided (generation failed).*

### `openCreateMenu(BuildContext context)`

The original app's Create menu: a group chat or a new Stick (a new
private space too, while [sticksShowSpaces] is on).

### `field`

```dart
Widget field(
  TextEditingController c,
  String label,
  {bool hidden = false, TextInputType? type, Key? key}
)
```

*No documentation provided (generation failed).*
