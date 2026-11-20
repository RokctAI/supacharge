# API Reference: stick_extras

Source file: `agent/dart/lib/src/sticks/domain/stick_extras.dart`

## Classes

### class `StickExtras`

The rest of a Stick's working life, next to [StickData]: its routines,
what it remembers, its skills and computer, the work it made, team chats,
search, archived Sticks, approval rules, connected apps and spaces.
Two implementations: [StickExtrasRepository] over the `api.sticks.*`
gateway cmds (a demo session and the guided tour are answered by the
fixtures for those cmds), and [RemoteStickExtras] over a remote server.

### class `AutoReview`

### class `AiRecipient`

One service your data goes to, and why.

### class `AiSharing`

What the server shares with AI services. [scope] and [version] go back
with an allow, so it applies to the wording that was shown.

### class `VoiceChoice`

### class `VoiceService`

One voice service we provide: speech, and listening when [listens].

### class `VoiceSetup`

### class `ChatAppLink`

### class `ChatInvite`

A group in a chat app your Stick was added to, or a link between your
Stick and someone else's.

### class `MessagingSetup`

### class `StickPlugin`

An installed plugin or tool server.

### class `PluginPreview`

### class `StickOrg`

### class `ModelKey`

### class `TaskComment`

One comment on a task, by a Stick ([stickId] set) or a person.

### class `NotepadItem`

### class `ActivityRow`

### class `UsageSummary`

### class `StickBrain`

### class `AccountInfo`

The signed-in person and what their account has used.

### class `StickFolder`

One Stick's settings: what the original app's Chat settings holds.
A folder the owner groups Sticks in (the original app's sections).

### class `InstructionVersion`

An earlier version of a Stick's instructions.

### class `StickSettings`

### class `VaultItem`

A saved login, card, contact or key. The value itself never leaves the
server here.

### class `StickRoutine`

### class `RoutineRun`

### class `MemoryNote`

### class `StickSkill`

### class `SkillPlaybook`

What a taught skill says: when to use it, the steps, and its limits.

### class `TaughtSkill`

A skill you taught a Stick by doing it on its computer.

### class `ComputerEntry`

One file or folder on a Stick's computer.

### class `StickComputer`

### class `WorkItem`

### class `WorkVersion`

One version of a file a Stick made.

### class `WorkFile`

A file's content, to look at or keep a copy of.

### class `TeamChat`

### class `ChatLine`

### class `SearchResult`

### class `ArchivedStick`

### class `ApprovalRule`

### class `AppToConnect`

An app the server can connect (its catalogue).

### class `ConnectedApp`

### class `WorkSpace`

## Whitelisted API Endpoints

### `routines(String stickId)`

*No documentation provided (generation failed).*

### `routineRuns(String routineId)`

*No documentation provided (generation failed).*

### `setRoutineOn(String routineId, bool on)`

*No documentation provided (generation failed).*

### `runRoutineNow(String routineId)`

*No documentation provided (generation failed).*

### `removeRoutine(String routineId)`

*No documentation provided (generation failed).*

### `createRoutine`

```dart
Future<StickRoutine> createRoutine({
  required String stickId,
  required String name,
  required String prompt,
  required List<String> schedule,
})
```

*No documentation provided (generation failed).*

### `memory(String stickId)`

*No documentation provided (generation failed).*

### `saveMemory(MemoryNote note, String content)`

*No documentation provided (generation failed).*

### `removeMemory(String noteId)`

*No documentation provided (generation failed).*

### `skills()`

*No documentation provided (generation failed).*

### `skill(String skillId)`

One shared skill with its instructions ([StickSkill.body]).

### `createSkill`

```dart
Future<StickSkill> createSkill({
  required String name,
  required String description,
  String body = '',
})
```

*No documentation provided (generation failed).*

### `updateSkill`

```dart
Future<StickSkill> updateSkill(
  String skillId,
  {String? name, String? description, String? body}
)
```

*No documentation provided (generation failed).*

### `removeSkill(String skillId)`

*No documentation provided (generation failed).*

### `taughtSkills(String stickId)`

Skills you taught [stickId] by showing it on its computer.

### `startTeaching(String stickId, String goal)`

Starts teaching: you get its computer and every step you show is
recorded until [stopTeaching].

### `teachStep(String skillId)`

Notes what is on the screen now as a step of the lesson.

### `stopTeaching(String skillId)`

Ends the lesson; the Stick writes it up as a draft to check.

### `saveTaughtDraft`

```dart
Future<TaughtSkill> saveTaughtDraft(
  String skillId,
  {String? name, required SkillPlaybook playbook}
)
```

*No documentation provided (generation failed).*

### `keepTaught(String skillId, {String? name})`

Keeps the skill, so the Stick uses it from now on.

### `tryTaught(String skillId)`

Has the Stick try the skill once now.

### `removeTaught(String skillId)`

*No documentation provided (generation failed).*

### `computer(String stickId)`

*No documentation provided (generation failed).*

### `startComputer(String stickId)`

*No documentation provided (generation failed).*

### `stopComputer(String stickId)`

*No documentation provided (generation failed).*

### `screenUrl(String stickId)`

The page that shows the Stick's computer screen live, view only; null
when the computer is not running or has no screen. While you have
taken over ([takeOver]) the page takes your mouse and keys.

### `restartComputer(String stickId)`

Turns it off and on again.

### `recoverComputer(String stickId)`

Brings a computer that went wrong back, keeping its files.

### `resetComputer(String stickId)`

A fresh computer: everything on it is wiped.

### `computerFiles(String stickId, String path)`

The files in [path] on the Stick's computer, folders first.

### `computerFile(String stickId, String path)`

One file from the Stick's computer.

### `uploadToComputer(String stickId, String path, List<int> bytes)`

Puts [bytes] on the Stick's computer at [path].

### `takeOver(String stickId)`

Takes the mouse and keyboard from the Stick, which waits meanwhile.
Gives when it ends unless given back first.

### `giveBack(String stickId)`

Hands the computer back to the Stick.

### `stillHere(String stickId)`

Says you are still looking, so a computer you are using stays awake.

### `work({String? stickId})`

*No documentation provided (generation failed).*

### `removeWork(WorkItem item)`

Deletes a file or page a Stick made, every version of it. Only the
owner can: a Stick has no tool for it (Ray, 2026-11-07).

### `workVersions(String fileId)`

Every version of a file, newest first.

### `workFile(String fileId)`

A file's content (any version's id).

### `renamePage(String pageId, String title)`

*No documentation provided (generation failed).*

### `pinPage(String pageId, bool pinned)`

*No documentation provided (generation failed).*

### `sharePage(String pageId, bool on)`

Turns a page's share link on (returns the link) or off (null). Off
breaks the old link; turning it on again makes a new one.

### `pageLink(String pageId)`

The share link of a page that has one.

### `pageDocument(String pageId, {bool dark = true, String errorTitle = ''})`

A page as one self-contained web document, to show in the app (Ray,
2026-11-08: a page the Stick made "doesn't open"). [errorTitle] is
what the page says when it can't draw.

### `prepareSpeech(String stickId, String text)`

Splits [text] into the pieces the server reads aloud in [stickId]'s
voice, as the original app's Speak message does. Null when no voice is
set up on the server.

### `speech(String stickId, String piece)`

One piece from [prepareSpeech], as sound to play.

### `attach`

```dart
Future<String?> attach(
  String stickId,
  {required String name, required String mimeType, required Uint8List bytes}
)
```

Puts a photo or file on the server for a message to [stickId], as the
original app does before sending. Returns its id, for
`MessageAttachment('file:<id>', name)`; null where files cannot be
sent (the demo).

### `teamChats()`

*No documentation provided (generation failed).*

### `archivedTeamChats()`

Team chats put away; they can be brought back.

### `renameTeamChat(String chatId, String name)`

*No documentation provided (generation failed).*

### `archiveTeamChat(String chatId)`

*No documentation provided (generation failed).*

### `restoreTeamChat(String chatId)`

*No documentation provided (generation failed).*

### `removeTeamChat(String chatId)`

Deletes a team chat and its messages for good.

### `teamChatLines(String chatId)`

*No documentation provided (generation failed).*

### `sendTeamChat(String chatId, String text)`

*No documentation provided (generation failed).*

### `createTeamChat(String name, List<String> stickIds)`

*No documentation provided (generation failed).*

### `search(String query)`

*No documentation provided (generation failed).*

### `archived()`

*No documentation provided (generation failed).*

### `archiveStick(String stickId)`

*No documentation provided (generation failed).*

### `pinStick(String stickId, bool pinned)`

Pins a Stick to the top of the team page, open, or unpins it.

### `duplicateStick(String stickId)`

A new Stick with the same instructions, settings and look.

### `reorderSticks(List<String> stickIds)`

The team in this order (the Team page and pickers follow it).

### `folders()`

The owner's folders for Sticks, in order.

### `createFolder(String name, String stickId)`

A new folder holding [stickId].

### `renameFolder(String folderId, String name)`

*No documentation provided (generation failed).*

### `removeFolder(String folderId)`

Deletes a folder; its Sticks go back to the top level.

### `setStickFolder(String stickId, String? folderId)`

Moves a Stick into [folderId], or out of any folder with null.

### `restoreInstructions(String stickId, String versionId, String expected)`

Puts back an earlier version of a Stick's instructions.
[expected] is what the instructions are now, so a change made
elsewhere meanwhile is not lost.

### `restoreStick(String stickId)`

*No documentation provided (generation failed).*

### `approvalRules()`

*No documentation provided (generation failed).*

### `setApprovalRule(String kind, String value, ApprovalEffect effect)`

*No documentation provided (generation failed).*

### `removeApprovalRule(String ruleId)`

*No documentation provided (generation failed).*

### `connections()`

*No documentation provided (generation failed).*

### `spaces()`

*No documentation provided (generation failed).*

### `switchSpace(String spaceId)`

*No documentation provided (generation failed).*

### `notepad(String stickId)`

A Stick's notepad: short items it keeps while it works.

### `addNote(String stickId, String title)`

*No documentation provided (generation failed).*

### `setNoteStatus(String itemId, String status)`

*No documentation provided (generation failed).*

### `removeNote(String itemId)`

*No documentation provided (generation failed).*

### `activity({bool recent = false})`

What the Sticks are doing now ([recent] false) or did lately.

### `exportMemory(String? stickId)`

Everything [stickId] remembers (every Stick's when null) as one
Markdown document.

### `autoReview()`

How actions that need an OK are handled for every Stick.

### `setAutoReview(ApprovalMode mode)`

*No documentation provided (generation failed).*

### `aiSharing()`

Who the server sends your data to (the model, voice and memory
services), and whether you allowed each.

### `allowAiSharing(AiSharing current, List<String> keys)`

*No documentation provided (generation failed).*

### `revokeAiSharing(String? key)`

Takes back one permission ([key]) or all of them (null).

### `voice()`

The voice Sticks read aloud with, and the voice services we provide.

### `voices({String? provider})`

The voices [provider] offers (the one in use when null).

### `setVoice(String voiceId, {String? provider})`

*No documentation provided (generation failed).*

### `messaging()`

Chat apps (WhatsApp, Slack, ...) you can reach your Sticks from.

### `setChatAppStick(String identityId, String stickId)`

*No documentation provided (generation failed).*

### `unlinkChatApp(String identityId)`

*No documentation provided (generation failed).*

### `answerGroupInvite(String membershipId, bool accept)`

*No documentation provided (generation failed).*

### `leaveGroup(String membershipId)`

*No documentation provided (generation failed).*

### `answerStickLink(String connectionId, bool accept)`

*No documentation provided (generation failed).*

### `endStickLink(String connectionId)`

*No documentation provided (generation failed).*

### `addWorkChat(String? stickId)`

The page that adds the Sticks to a work chat (a Slack workspace).

### `removeWorkChat(String installationId)`

*No documentation provided (generation failed).*

### `plugins()`

Plugins and tool servers your Sticks can use.

### `previewPlugin(String source)`

What the plugin at [source] (a GitHub address) would add.

### `installPlugin(PluginPreview preview)`

*No documentation provided (generation failed).*

### `removePlugin(String id)`

*No documentation provided (generation failed).*

### `addToolServer(String name, String url, {String? secret})`

Adds a tool server at [url]; it is checked once straight after.

### `checkToolServer(String id)`

Starts a tool server once, to see that it works and what tools it has.

### `removeToolServer(String id)`

*No documentation provided (generation failed).*

### `organizations()`

*No documentation provided (generation failed).*

### `createOrganization(String name)`

*No documentation provided (generation failed).*

### `renameOrganization(String id, String name)`

*No documentation provided (generation failed).*

### `removeOrganization(String id)`

*No documentation provided (generation failed).*

### `switchOrganization(StickOrg org)`

Opens [org] (its first space).

### `modelKeys()`

Model keys you added yourself, used when our credits run out.

### `addModelKey(String provider, String apiKey)`

*No documentation provided (generation failed).*

### `removeModelKey(ModelKey key)`

*No documentation provided (generation failed).*

### `trustedSites()`

Websites whose links open from chat without asking first.

### `trustSite(String url)`

Trusts the website [url] is on and gives its name.

### `removeTrustedSite(String site)`

*No documentation provided (generation failed).*

### `moveTask(String taskId, BoardColumn to)`

Moves a task to another column of the board.

### `createTask`

```dart
Future<String> createTask({
  required String stickId,
  required String title,
  String? note,
  String priority = 'normal',
})
```

Puts a new task on the board for [stickId] and gives its id.
[priority] is `low`, `normal`, `high` or `urgent`.

### `editTask`

```dart
Future<void> editTask(
  String taskId,
  {String? title, String? note, String? priority, String? stickId}
)
```

Changes a task's title, note, priority or Stick. Only what is given
changes; an empty [note] clears it.

### `taskComments(String taskId)`

The comments on a task, oldest first.

### `commentTask(String taskId, String body)`

Adds the owner's comment to a task.

### `usage()`

What the Sticks cost this month, as the server counts it.

### `brains()`

The models a Stick can think with, and the one it uses (null: the
space's default).

### `brainOf(String stickId)`

*No documentation provided (generation failed).*

### `setBrain(String stickId, StickBrain? brain)`

*No documentation provided (generation failed).*

### `signOut()`

Signs out of the Sticks server, and with it the app.

### `account()`

The signed-in person, or null where the data source has no accounts
(the gateway and the tour). Null hides the account screens.

### `changePassword(String current, String next)`

Changes the password; the session stays signed in.

### `deleteAccount(String password)`

Deletes the account and everything in it for good; [password]
confirms it. Signs out after.

### `stickSettings(String stickId)`

The settings of one Stick, as the original app's Chat settings shows.

### `updateStick`

```dart
Future<void> updateStick(
  String stickId,
  { String? description, String? instructions, String? thinking, bool?
      readAloud, bool? crossSpace, bool? manageOwnSticks, bool? notify, }
)
```

Writes the given settings; a null leaves that one as it is.

### `setComputerPrivate(String stickId, bool private)`

A computer of its own ([private]) or the team's shared one.

### `deleteStick(String stickId, {required bool deleteMemories})`

Deletes a Stick for good: its conversation, files and routines.
[deleteMemories] false keeps what it remembered.

### `createSpace(String name)`

A new space, kept apart from the others.

### `vault()`

Logins, cards and keys the Sticks may use, without their values.

### `removeVaultItem(String name)`

*No documentation provided (generation failed).*

### `addVaultItem(VaultDraft draft)`

Saves a new login, key, card or address. The value goes to the server
once and is never read back. Throws [VaultProblem] for a value the
server would turn down.

### `appCatalog({String query = ''})`

Apps that can be connected, matching [query] (all when empty).

### `finishConnect(String connectionId)`

Whether the sign-in for [connectionId] has finished; true once the app
is connected. Asked again while the owner signs in in the browser.

### `setDefaultBrain(StickBrain brain)`

The model every Stick without its own uses.

### `boardWire(BoardColumn c)`

*No documentation provided (generation failed).*

### `boardColumnOf(Object? s)`

*No documentation provided (generation failed).*

### `AutoReview({this.mode = ApprovalMode.ask, this.checkerAvailable = false})`

*No documentation provided (generation failed).*

### `AiSharing`

```dart
const AiSharing({
  this.scope = '',
  this.version = '',
  this.recipients = const [],
  this.privacyUrl,
})
```

*No documentation provided (generation failed).*

### `VoiceChoice`

```dart
const VoiceChoice({
  required this.id,
  required this.label,
  this.description = '',
})
```

*No documentation provided (generation failed).*

### `VoiceChoice`

```dart
VoiceChoice(
  id: (m['id'] ?? '').toString(),
  label: (m['label'] ?? m['id'] ?? '').toString(),
  description: (m['description'] ?? '').toString()
)
```

*No documentation provided (generation failed).*

### `VoiceService({required this.id, required this.name, this.listens = false})`

*No documentation provided (generation failed).*

### `VoiceSetup`

```dart
const VoiceSetup({
  this.ready = false,
  this.listens = false,
  this.provider,
  this.voiceId = '',
  this.services = const [],
})
```

*No documentation provided (generation failed).*

### `ChatAppLink`

```dart
const ChatAppLink({
  required this.id,
  required this.provider,
  required this.address,
  required this.stickId,
  this.stickName = '',
})
```

*No documentation provided (generation failed).*

### `ChatInvite`

```dart
const ChatInvite({
  required this.id,
  required this.name,
  required this.status,
  this.incoming = true,
  this.detail = '',
})
```

*No documentation provided (generation failed).*

### `MessagingSetup`

```dart
const MessagingSetup({
  this.enabled = false,
  this.workChatsAvailable = false,
  this.providers = const [],
  this.addresses = const {},
  this.links = const [],
  this.groups = const [],
  this.stickLinks = const [],
  this.workChats = const [],
})
```

*No documentation provided (generation failed).*

### `StickPlugin`

```dart
const StickPlugin({
  required this.id,
  required this.name,
  required this.kind,
  this.detail = '',
  this.health = 'unknown',
  this.tools,
})
```

*No documentation provided (generation failed).*

### `PluginPreview`

```dart
const PluginPreview({
  required this.source,
  required this.name,
  this.description = '',
  required this.digest,
  this.skills = const [],
  this.servers = const [],
  this.skipped = const [],
})
```

*No documentation provided (generation failed).*

### `names(Object? v)`

*No documentation provided (generation failed).*

### `StickOrg`

```dart
const StickOrg({
  required this.id,
  required this.name,
  this.firstSpaceId = '',
  this.current = false,
  this.canManage = false,
})
```

*No documentation provided (generation failed).*

### `ModelKey({required this.id, required this.provider, this.label = ''})`

*No documentation provided (generation failed).*

### `ModelKey`

```dart
ModelKey(
  id: (m['id'] ?? '').toString(),
  provider: (m['provider'] ?? '').toString(),
  label: (m['label'] ?? '').toString()
)
```

*No documentation provided (generation failed).*

### `TaskComment`

```dart
const TaskComment({
  required this.id,
  required this.body,
  this.author = '',
  this.stickId,
  this.at,
})
```

*No documentation provided (generation failed).*

### `NotepadItem`

```dart
const NotepadItem({
  required this.id,
  required this.title,
  this.notes = '',
  this.status = 'open',
  this.updated,
})
```

*No documentation provided (generation failed).*

### `ActivityRow`

```dart
const ActivityRow({
  required this.id,
  required this.stickId,
  required this.stickName,
  required this.status,
  required this.what,
  this.chatName,
  this.fromStick,
  this.at,
})
```

*No documentation provided (generation failed).*

### `UsageSummary`

```dart
const UsageSummary({
  this.runs = 0,
  this.modelCalls = 0,
  this.tokens,
  this.costUsd,
  this.byModel = const [],
})
```

*No documentation provided (generation failed).*

### `StickBrain`

```dart
const StickBrain({
  required this.provider,
  required this.id,
  required this.label,
  this.auto = false,
})
```

*No documentation provided (generation failed).*

### `friendlyBrains`

```dart
List<StickBrain> friendlyBrains(
  List<StickBrain> all,
  [Map<String, String> names = sticksModelNames]
)
```

The models to offer: one per entry of [names] that the server can run,
in the map's order, labelled with the map's name. Models not on the map
are not offered. A model id with a dated suffix
("claude-opus-5-5-20261101") counts as its plain id.

### `matches(StickBrain b, String want)`

*No documentation provided (generation failed).*

### `AccountInfo({required this.name, required this.email, this.defaultBrain})`

*No documentation provided (generation failed).*

### `StickFolder(this.id, this.name)`

*No documentation provided (generation failed).*

### `InstructionVersion`

```dart
const InstructionVersion({
  required this.id,
  required this.instructions,
  this.reason = '',
  this.at,
})
```

*No documentation provided (generation failed).*

### `StickSettings`

```dart
const StickSettings({
  required this.name,
  this.description = '',
  this.instructions = '',
  this.brain,
  this.thinking,
  this.computerPrivate = false,
  this.readAloud = false,
  this.crossSpace = false,
  this.manageOwnSticks = true,
  this.notify = true,
  this.history = const [],
})
```

*No documentation provided (generation failed).*

### `VaultItem`

```dart
const VaultItem({
  required this.name,
  this.title = '',
  this.site = '',
  this.kind = '',
  this.updated,
})
```

*No documentation provided (generation failed).*

### `shortName(String name)`

A name short enough for a group list: the part before the first comma,
so "Ada, research lead" shows as "Ada".

### `extrasTime(Object? v)`

*No documentation provided (generation failed).*

### `extrasMaps(Object? v)`

*No documentation provided (generation failed).*

### `StickRoutine`

```dart
const StickRoutine({
  required this.id,
  required this.stickId,
  required this.name,
  required this.prompt,
  this.schedule = const [],
  this.on = false,
  this.lastRun,
  this.nextRun,
})
```

*No documentation provided (generation failed).*

### `RoutineRun({required this.id, required this.status, this.error, this.at})`

*No documentation provided (generation failed).*

### `MemoryNote`

```dart
const MemoryNote({
  required this.id,
  required this.path,
  required this.content,
  this.revision = 1,
  this.updated,
})
```

*No documentation provided (generation failed).*

### `StickSkill`

```dart
const StickSkill({
  required this.id,
  required this.name,
  required this.description,
  this.builtIn = false,
  this.body = '',
})
```

*No documentation provided (generation failed).*

### `SkillPlaybook`

```dart
const SkillPlaybook({
  this.whenToUse = '',
  this.inputs = const [],
  this.steps = const [],
  this.howToCheck = '',
  this.whatToReturn = '',
  this.approvalBoundaries = '',
  this.failureHandling = '',
})
```

*No documentation provided (generation failed).*

### `toMap()`

*No documentation provided (generation failed).*

### `TaughtSkill`

```dart
const TaughtSkill({
  required this.id,
  required this.stickId,
  required this.name,
  required this.goal,
  required this.state,
  this.playbook = const SkillPlaybook(),
  this.steps = 0,
  this.until,
})
```

*No documentation provided (generation failed).*

### `ComputerEntry({required this.path, this.dir = false, this.size = 0})`

*No documentation provided (generation failed).*

### `typeOfName(String name)`

A file's type from its name, for the preview.

### `StickComputer`

```dart
const StickComputer({
  required this.state,
  this.driver = 'none',
  this.screen = false,
  this.busyWith,
})
```

*No documentation provided (generation failed).*

### `pageViewerHtml`

```dart
String pageViewerHtml({
  required String runtime,
  required String code,
  required bool dark,
  String errorTitle = '',
})
```

A page's document: the server's page runtime and the page's compiled
code, as the server's own viewer builds it. `<` is escaped so no page
text can close the script.

### `WorkItem`

```dart
const WorkItem({
  required this.id,
  required this.title,
  required this.kind,
  this.description,
  this.stickId,
  this.type,
  this.at,
  this.pinned = false,
  this.shared = false,
  this.versions = 1,
})
```

*No documentation provided (generation failed).*

### `WorkVersion({required this.id, required this.version, this.at})`

*No documentation provided (generation failed).*

### `WorkFile({required this.name, required this.type, required this.bytes})`

*No documentation provided (generation failed).*

### `TeamChat`

```dart
const TeamChat({
  required this.id,
  required this.name,
  this.preview = '',
  this.stickIds = const [],
  this.names = const [],
  this.unread = false,
  this.at,
})
```

*No documentation provided (generation failed).*

### `ChatLine`

```dart
const ChatLine({
  required this.id,
  required this.text,
  this.stickId,
  this.name,
  this.at,
})
```

*No documentation provided (generation failed).*

### `SearchResult`

```dart
const SearchResult({
  required this.kind,
  required this.title,
  this.snippet = '',
  this.stickId,
  this.chatId,
})
```

*No documentation provided (generation failed).*

### `ArchivedStick`

```dart
const ArchivedStick({
  required this.id,
  required this.name,
  this.role = '',
  this.archivedAt,
})
```

*No documentation provided (generation failed).*

### `ApprovalRule`

```dart
const ApprovalRule({
  required this.id,
  required this.kind,
  required this.value,
  required this.effect,
})
```

*No documentation provided (generation failed).*

### `wire(ApprovalEffect e)`

*No documentation provided (generation failed).*

### `AppToConnect`

```dart
const AppToConnect({
  required this.connectorId,
  required this.slug,
  required this.name,
  this.logo,
  this.connected = false,
  this.noAuth = false,
})
```

*No documentation provided (generation failed).*

### `ConnectedApp`

```dart
const ConnectedApp({
  required this.id,
  required this.name,
  required this.provider,
  required this.status,
})
```

*No documentation provided (generation failed).*

### `WorkSpace({required this.id, required this.name, this.current = false})`

*No documentation provided (generation failed).*
