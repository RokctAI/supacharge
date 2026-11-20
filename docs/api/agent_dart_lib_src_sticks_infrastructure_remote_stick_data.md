# API Reference: remote_stick_data

Source file: `agent/dart/lib/src/sticks/infrastructure/remote_stick_data.dart`

## Classes

### class `RemoteError`

Thrown when remote answers with an error. [status] 401 means sign in again.

### class `RemoteClient`

A small client for a remote server: Better Auth sign-in at /api/auth and
oRPC procedures at /rpc/<group>/<name> with body {"json": input}.

### class `RemoteStickData`

[StickData] over a remote server: a Stick is a remote bot, a Stick task
is a ticket assigned to that bot, and a Stick's inbox is the bot's thread.
Confirms are the bot's open approval and choice cards; calls are its
voice-call cards; roles are the built-ins plus the team's own roles.

### class `WorkingHours`

Daily working hours, `HH:MM-HH:MM` in the phone's own time. An end
before the start runs past midnight (`22:00-06:00`).

## Whitelisted API Endpoints

### `RemoteError(this.status, this.message)`

*No documentation provided (generation failed).*

### `toString()`

*No documentation provided (generation failed).*

### `RemoteClient`

```dart
RemoteClient(
  String baseUrl,
  {this.token, this.spaceId, this.onToken, RemoteTransport? transport,
      RemoteStreamTransport? stream}
)
```

*No documentation provided (generation failed).*

### `moveTo(String url)`

Points every later call at [url]: the server a chain named (the hub
gives the tenant's site, the site gives its Sticks server).

### `signIn(String email, String password)`

Signs in and returns the server's reply (its `user` among it).

### `changePassword(String current, String next)`

Changes the password. The server revokes the other sessions and this
one with them, and answers with a new session, which replaces ours.

### `deleteAccount(String password)`

Deletes the signed-in person's account and everything in it, after the
password confirms it is them, then signs out.

### `updateName(String name)`

Renames the signed-in person on the server.

### `signOut({bool forced = false})`

Ends the session. [forced] is for a 401 or an expired token.

### `getText(String path)`

Reads a plain text file the server serves, e.g. the page runtime.
Tests set [getter].

### `postBytes(String path, Object json)`

Posts [json] to [path] (an `/api/...` route, not an oRPC call) and
returns the raw answer, such as the sound of a spoken message.

### `call(String procedure, [Object? input])`

Calls one oRPC procedure, e.g. `bots/list`, and returns its output.

### `subscribe(String procedure, [Object? input])`

Opens a live oRPC procedure, e.g. `threads/subscribe`, and gives each
output as it arrives. Cancelling the subscription closes the connection.

### `fire()`

*No documentation provided (generation failed).*

### `RemoteStickData`

```dart
RemoteStickData(
  this.client,
  {this.readLooks, this.writeLooks, ThreadStore? threads}
)
```

*No documentation provided (generation failed).*

### `refresh()`

Asks open screens to reload, e.g. after a space switch.

### `messageText(Map<String, dynamic> m)`

The readable text of a server message (see [_text]).

### `genderOf(Map<String, dynamic> m)`

The bot's gender from the pronouns its description or instructions
give ("(He/him)", "she/her"); null when they name none, and the look
then falls back to one fixed per bot id.

### `hasOlder(String stickId)`

*No documentation provided (generation failed).*

### `loadOlder(String stickId)`

*No documentation provided (generation failed).*

### `watchChat(String stickId)`

Keeps [stickId]'s chat live while it is open: new messages land in the
kept copy as the server sends them (no reload from the server), and the
Stick's reply shows as it is written.

### `sticks()`

*No documentation provided (generation failed).*

### `stick(String id)`

*No documentation provided (generation failed).*

### `tasks({String? stickId})`

*No documentation provided (generation failed).*

### `confirm(String stickId)`

*No documentation provided (generation failed).*

### `answerConfirm`

```dart
Future<ConfirmAnswered> answerConfirm(
  String confirmId,
  String key,
  {String? note, List<String>? values}
)
```

*No documentation provided (generation failed).*

### `startLive`

```dart
void startLive({
  Duration every = const Duration(seconds: 8),
  Duration idle = const Duration(seconds: 30),
})
```

Starts a light check of the bot list and fires [changes] when any
Stick's status, preview or unread flag moves, so open screens reload.
The check runs every [every] while something is moving. While every
Stick rests and nothing changed, it slows down step by step to [idle]
(Ray: don't ask for the same data all day); any change, a message the
owner sends, or coming back to the app brings it back to [every].

### `adoptTimezone()`

Tells the server the owner's time zone, once per start, as the web app
does. Without it a Stick reads "wake me at 8:40" as 8:40 UTC (Ray,
2026-11-11: a wake-up that never came). The server only fills an empty
zone and never overrides one the owner chose. Best effort.

### `stopLive()`

*No documentation provided (generation failed).*

### `quietUntil`

```dart
static DateTime? quietUntil(
  List<Map<String, dynamic>> bots,
  DateTime now,
  [Map<String, Map<String, dynamic>>? saved]
)
```

When the team check can next be needed, if every Stick is quiet and
outside its working hours; null means keep checking as usual.
* A Stick with hours that is inside them: keep checking (null).
* A Stick with no set hours: it can work any time, but it is resting
(the caller only asks when no Stick is busy), so it does not keep
the app checking.
* No Stick has hours: null, the usual slow check.
Otherwise: the earliest next shift start among the Sticks with hours.

### `attachmentsOf(Map<String, dynamic> m)`

The files, pictures and pages a message carries (Ray, 2026-11-08: a
file the Stick attached showed in the server's own app but not here).
Refs are `file:<id>` or `page:<id>`, which the chat opens.

### `stepsOf(Map<String, dynamic> m)`

The tools used for a reply, from its `steps` blocks.

### `toolLabel(String name)`

A tool's name as words: `web_search` reads "Web search".

### `inbox(String forWho, {bool unreadOnly = false})`

*No documentation provided (generation failed).*

### `setShortReplies(bool on, {Set<String>? seesMyTasks})`

*No documentation provided (generation failed).*

### `setOwnerTasks(String stickId, String? body)`

*No documentation provided (generation failed).*

### `setBlindMode(String stickId, bool on)`

*No documentation provided (generation failed).*

### `markRead(String stickId)`

The server keeps the read position per chat, so it follows the owner
across devices. Does not fire [changes]: reading is not a write the
open screens need to reload for.

### `stopReply(String stickId)`

*No documentation provided (generation failed).*

### `clearChat(String stickId)`

*No documentation provided (generation failed).*

### `react(String stickId, String messageId, String reaction)`

*No documentation provided (generation failed).*

### `markUnread(String stickId, String messageId)`

*No documentation provided (generation failed).*

### `sendMessage`

```dart
Future<MessageStatus> sendMessage({
  required String to,
  required MessageKind kind,
  required String body,
  String? replyTo,
  String? replyQuote,
  String? taskId,
  List<MessageAttachment> attachments = const [],
})
```

[replyTo] answers one message; [replyQuote] is the part of it quoted.

### `retrySend(String messageId)`

*No documentation provided (generation failed).*

### `discardSend(String messageId)`

*No documentation provided (generation failed).*

### `roles()`

The built-in roles, plus every role a Stick on the server already has
(a bot's description), so a team can hire another of the same kind.

### `createStick`

```dart
Future<Stick> createStick({
  required String fullName,
  required bool woman,
  required String roleKey,
  String? hours,
  StickLook? look,
})
```

*No documentation provided (generation failed).*

### `calls({String? stickId})`

*No documentation provided (generation failed).*

### `weeklyReport({DateTime? until})`

*No documentation provided (generation failed).*

### `notifications()`

*No documentation provided (generation failed).*

### `stop()`

*No documentation provided (generation failed).*

### `WorkingHours(this.start, this.end)`

*No documentation provided (generation failed).*

### `parse(String text)`

Null when [text] is empty or not `HH:MM-HH:MM`.

### `at(int h, int mm)`

*No documentation provided (generation failed).*

### `contains(DateTime t)`

*No documentation provided (generation failed).*

### `followServerChain(String start, List<ServerHop> hops)`

Follows [hops] in order from [start] and returns where they end. With
no hops (today) the start is the Sticks server itself. A hop that fails
or answers something that is not an https address stops the chain at
the last good address, so a broken link never strands the app.
