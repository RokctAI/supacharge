# API Reference: thread_cache

Source file: `agent/dart/lib/src/sticks/infrastructure/thread_cache.dart`

## Classes

### class `ThreadStore`

Where the chats kept on the device are saved: one entry per Stick.

### class `MemoryThreadStore`

Keeps the chats for this run of the app only (tests, and where no folder
is at hand).

### class `FileThreadStore`

One small JSON file per chat in the app's private support folder, so a
chat opens from the phone before (or without) the network.

### class `CachedThread`

One Stick's chat as kept on the device: the server's message rows (oldest
first), the position of the newest thing applied ([cursor], what a live
connection resumes after), and the team-list line the rows were read
against ([sig]): while that line is unchanged, nothing new has happened
in the chat and the rows are used without asking the server.

## Whitelisted API Endpoints

### `read(String botId)`

*No documentation provided (generation failed).*

### `write(String botId, String json)`

*No documentation provided (generation failed).*

### `clear()`

Forgets every chat, on sign-out.

### `FileThreadStore({Future<Directory> Function()? root})`

*No documentation provided (generation failed).*

### `Directory('${(await getApplicationSupportDirectory()).path}/sticks_chats')`

*No documentation provided (generation failed).*

### `CachedThread`

```dart
CachedThread({
  required this.messages,
  this.cursor = -1,
  this.sig = '',
  this.hasOlder = false,
})
```

*No documentation provided (generation failed).*

### `decode(String? json)`

*No documentation provided (generation failed).*

### `encode()`

*No documentation provided (generation failed).*

### `mergePage(List<Map<String, dynamic>> page, {int? coveredThroughSeq})`

Puts a fetched page in: rows the page covers are replaced by its copy
(edits, answered cards), older rows the page no longer reaches stay.

### `mergeOlder(List<Map<String, dynamic>> page, {required bool more})`

Puts an older page in front of what is kept. [more] is whether the
server has still older messages.

### `upsert(Map<String, dynamic> row)`

Adds or replaces one message (from the live connection).
