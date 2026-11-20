# API Reference: more_work

Source file: `agent/dart/lib/src/sticks/presentation/screens/more_work.dart`

## Whitelisted API Endpoints

### `createState()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `saveACopy(BuildContext context, String name, List<int> bytes)`

Where a saved copy goes: Downloads where the system has one, else the
app's own documents folder.
Saves [bytes] as [name] in [workSaveDir], never over a file already
there ("Plan (2).txt"), and says where it went.

### `utf8Text(List<int> bytes)`

*No documentation provided (generation failed).*

### `openAttachment(BuildContext context, MessageAttachment a)`

Opens a file or page a Stick attached in a chat (refs `file:<id>` and
`page:<id>`). False when the ref is neither.

### `load()`

*No documentation provided (generation failed).*
