# API Reference: inbox_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/inbox_screen.dart`

## Classes

### class `InboxScreen`

The owner's inbox, and any Stick's inbox for oversight. In the owner's
own inbox a message can be answered, or handed back with an attachment;
another Stick's inbox is read-only. Where the server keeps a chat per
Stick ([StickData.inboxIsChat]), a Stick's inbox is that chat instead:
it opens where the owner last read, marks what came since as New, and
has a reply box at the bottom.

### class `ChatHead`

The top of every chat: back to Team, whose chat this is, and the bar to
switch to another Stick's chat (You first). Pinned, so it never scrolls
away.

## Whitelisted API Endpoints

### `InboxScreen({super.key, this.forWho = 'owner'})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `didChangeDependencies()`

*No documentation provided (generation failed).*

### `initState()`

*No documentation provided (generation failed).*

### `didChangeAppLifecycleState(AppLifecycleState state)`

*No documentation provided (generation failed).*

### `look(Duration _)`

*No documentation provided (generation failed).*

### `item(String key, IconData icon, String label)`

*No documentation provided (generation failed).*
