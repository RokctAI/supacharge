# API Reference: stick_data

Source file: `agent/dart/lib/src/sticks/domain/stick_data.dart`

## Classes

### class `StickData`

Everything the Sticks screens read and write. One implementation,
[StickRepository], talks to the `api.sticks.*` gateway cmds of the call
contract; a demo session is served by the fixtures for those same cmds,
so demo and production take the same path.

### class `ChatWatch`

An open chat kept live (see [StickData.watchChat]).

## Whitelisted API Endpoints

### `sticks()`

*No documentation provided (generation failed).*

### `stick(String id)`

*No documentation provided (generation failed).*

### `tasks({String? stickId})`

*No documentation provided (generation failed).*

### `confirm(String stickId)`

The Stick's oldest open confirm, or null.

### `answerConfirm`

```dart
Future<ConfirmAnswered> answerConfirm(
  String confirmId,
  String key,
  {String? note, List<String>? values}
)
```

[values] fills the confirm's [StickConfirm.inputs], in order.

### `inbox(String forWho, {bool unreadOnly = false})`

Owner inbox is [forWho] `owner`; `team` is every Stick-to-Stick message
(owner only); otherwise a Stick id, for oversight.

### `setShortReplies(bool on, {Set<String>? seesMyTasks})`

Adds the "Short replies" block to every Stick's instructions ([on]) or
takes it out, and to new Sticks from then on. Returns how many Sticks
were changed. Does nothing where [canShortenReplies] is false.
[seesMyTasks], when given, are the Sticks allowed to see the owner's
tasks: any other Stick still holding them (switched off while offline)
has them taken out in the same pass.

### `setOwnerTasks(String stickId, String? body)`

Keeps [body] (the owner's open tasks, [OwnerTasks.body]) in [stickId]'s
instructions, or takes it out when null. Read only for the Stick.

### `setBlindMode(String stickId, bool on)`

Tells [stickId] that blind mode is on ([on]) or off, through a marked
block in its instructions ([BlindModeNote]). Nothing where the server
keeps no instructions.

### `hasOlder(String stickId)`

Whether the chat with [stickId] has older messages than those
[inbox] returned, which [loadOlder] can bring in.

### `loadOlder(String stickId)`

Fetches the next older page of the chat with [stickId] (a long chat
opens on its newest page). True when it added messages; the next
[inbox] includes them.

### `watchChat(String stickId)`

Keeps the chat with [stickId] live while it is open, where the data
source can: new messages arrive without a reload, and [ChatWatch.draft]
is the Stick's reply as it is being written. Call [ChatWatch.close]
when the chat closes.

### `retrySend(String messageId)`

Sends a message that is waiting or was not sent again now.

### `discardSend(String messageId)`

Deletes a message that is waiting or was not sent, before it goes out.

### `markRead(String stickId)`

Marks the owner's chat with [stickId] read. Returns the position the
owner had read up to before (the "New" line goes below it), or null
when nothing was unread.

### `stopReply(String stickId)`

Stops the reply [stickId] is working on in the owner's chat, as the
original app's stop button does.

### `clearChat(String stickId)`

Empties the owner's chat with [stickId], on the server and on this
device. The Stick keeps its memory.

### `react(String stickId, String messageId, String reaction)`

Reacts to a Stick's message in the owner's chat. The Stick sees it and
may answer.

### `markUnread(String stickId, String messageId)`

Marks the owner's chat with [stickId] unread from [messageId] on.

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

### `roles()`

*No documentation provided (generation failed).*

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

Calls the Sticks made or have lined up for approval.

### `weeklyReport({DateTime? until})`

Worked out from the task feed; no cmd serves it. Counts the seven days
ending with the day [until] falls on (today when null).

### `notifications()`

Open confirms and recent messages as the push would show them.

### `ChatWatch(this.draft, this.close, {ValueListenable<String?>? doing})`

*No documentation provided (generation failed).*
