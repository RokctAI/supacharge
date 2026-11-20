# API Reference: stick_extras_repository

Source file: `agent/dart/lib/src/sticks/infrastructure/stick_extras_repository.dart`

## Classes

### class `StickExtrasRepository`

[StickExtras] over the `api.sticks.*` gateway cmds. A demo session and
the guided tour are answered by the fixtures in assets/demo/sticks, so
every screen has sample data there.

## Whitelisted API Endpoints

### `StickExtrasRepository(this._call)`

*No documentation provided (generation failed).*

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

*No documentation provided (generation failed).*

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

*No documentation provided (generation failed).*

### `startTeaching(String stickId, String goal)`

*No documentation provided (generation failed).*

### `teachStep(String skillId)`

*No documentation provided (generation failed).*

### `stopTeaching(String skillId)`

*No documentation provided (generation failed).*

### `saveTaughtDraft`

```dart
Future<TaughtSkill> saveTaughtDraft(
  String skillId,
  {String? name, required SkillPlaybook playbook}
)
```

*No documentation provided (generation failed).*

### `keepTaught(String skillId, {String? name})`

*No documentation provided (generation failed).*

### `tryTaught(String skillId)`

*No documentation provided (generation failed).*

### `removeTaught(String skillId)`

*No documentation provided (generation failed).*

### `computer(String stickId)`

*No documentation provided (generation failed).*

### `startComputer(String stickId)`

*No documentation provided (generation failed).*

### `stopComputer(String stickId)`

*No documentation provided (generation failed).*

### `screenUrl(String stickId)`

*No documentation provided (generation failed).*

### `restartComputer(String stickId)`

*No documentation provided (generation failed).*

### `recoverComputer(String stickId)`

*No documentation provided (generation failed).*

### `resetComputer(String stickId)`

*No documentation provided (generation failed).*

### `computerFiles(String stickId, String path)`

*No documentation provided (generation failed).*

### `computerFile(String stickId, String path)`

*No documentation provided (generation failed).*

### `uploadToComputer(String stickId, String path, List<int> bytes)`

*No documentation provided (generation failed).*

### `takeOver(String stickId)`

*No documentation provided (generation failed).*

### `giveBack(String stickId)`

*No documentation provided (generation failed).*

### `stillHere(String stickId)`

*No documentation provided (generation failed).*

### `work({String? stickId})`

*No documentation provided (generation failed).*

### `removeWork(WorkItem item)`

*No documentation provided (generation failed).*

### `workVersions(String fileId)`

*No documentation provided (generation failed).*

### `workFile(String fileId)`

*No documentation provided (generation failed).*

### `renamePage(String pageId, String title)`

*No documentation provided (generation failed).*

### `pinPage(String pageId, bool pinned)`

*No documentation provided (generation failed).*

### `sharePage(String pageId, bool on)`

*No documentation provided (generation failed).*

### `pageLink(String pageId)`

*No documentation provided (generation failed).*

### `pageDocument(String pageId, {bool dark = true, String errorTitle = ''})`

The demo has no page runtime: a plain page with the title and words.

### `prepareSpeech(String stickId, String text)`

The demo has no voice.

### `speech(String stickId, String piece)`

*No documentation provided (generation failed).*

### `attach`

```dart
Future<String?> attach(
  String stickId,
  {required String name, required String mimeType, required Uint8List bytes}
)
```

*No documentation provided (generation failed).*

### `archivedTeamChats()`

*No documentation provided (generation failed).*

### `renameTeamChat(String chatId, String name)`

*No documentation provided (generation failed).*

### `archiveTeamChat(String chatId)`

*No documentation provided (generation failed).*

### `restoreTeamChat(String chatId)`

*No documentation provided (generation failed).*

### `removeTeamChat(String chatId)`

*No documentation provided (generation failed).*

### `duplicateStick(String stickId)`

*No documentation provided (generation failed).*

### `reorderSticks(List<String> stickIds)`

*No documentation provided (generation failed).*

### `folders()`

*No documentation provided (generation failed).*

### `createFolder(String name, String stickId)`

*No documentation provided (generation failed).*

### `renameFolder(String folderId, String name)`

*No documentation provided (generation failed).*

### `removeFolder(String folderId)`

*No documentation provided (generation failed).*

### `setStickFolder(String stickId, String? folderId)`

*No documentation provided (generation failed).*

### `restoreInstructions(String stickId, String versionId, String expected)`

*No documentation provided (generation failed).*

### `teamChats()`

*No documentation provided (generation failed).*

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

*No documentation provided (generation failed).*

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

*No documentation provided (generation failed).*

### `addNote(String stickId, String title)`

*No documentation provided (generation failed).*

### `setNoteStatus(String itemId, String status)`

*No documentation provided (generation failed).*

### `removeNote(String itemId)`

*No documentation provided (generation failed).*

### `activity({bool recent = false})`

*No documentation provided (generation failed).*

### `moveTask(String taskId, BoardColumn to)`

*No documentation provided (generation failed).*

### `exportMemory(String? stickId)`

*No documentation provided (generation failed).*

### `autoReview()`

*No documentation provided (generation failed).*

### `setAutoReview(ApprovalMode mode)`

*No documentation provided (generation failed).*

### `aiSharing()`

*No documentation provided (generation failed).*

### `allowAiSharing(AiSharing current, List<String> keys)`

*No documentation provided (generation failed).*

### `revokeAiSharing(String? key)`

*No documentation provided (generation failed).*

### `voice()`

*No documentation provided (generation failed).*

### `voices({String? provider})`

*No documentation provided (generation failed).*

### `setVoice(String voiceId, {String? provider})`

*No documentation provided (generation failed).*

### `messaging()`

*No documentation provided (generation failed).*

### `invite(Map<String, dynamic> x)`

*No documentation provided (generation failed).*

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

*No documentation provided (generation failed).*

### `removeWorkChat(String installationId)`

*No documentation provided (generation failed).*

### `plugins()`

*No documentation provided (generation failed).*

### `previewPlugin(String source)`

*No documentation provided (generation failed).*

### `installPlugin(PluginPreview preview)`

*No documentation provided (generation failed).*

### `removePlugin(String id)`

*No documentation provided (generation failed).*

### `addToolServer(String name, String url, {String? secret})`

*No documentation provided (generation failed).*

### `checkToolServer(String id)`

*No documentation provided (generation failed).*

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

*No documentation provided (generation failed).*

### `modelKeys()`

*No documentation provided (generation failed).*

### `addModelKey(String provider, String apiKey)`

*No documentation provided (generation failed).*

### `removeModelKey(ModelKey key)`

*No documentation provided (generation failed).*

### `trustedSites()`

*No documentation provided (generation failed).*

### `trustSite(String url)`

*No documentation provided (generation failed).*

### `removeTrustedSite(String site)`

*No documentation provided (generation failed).*

### `createTask`

```dart
Future<String> createTask({
  required String stickId,
  required String title,
  String? note,
  String priority = 'normal',
})
```

*No documentation provided (generation failed).*

### `editTask`

```dart
Future<void> editTask(
  String taskId,
  {String? title, String? note, String? priority, String? stickId}
)
```

*No documentation provided (generation failed).*

### `taskComments(String taskId)`

*No documentation provided (generation failed).*

### `commentTask(String taskId, String body)`

*No documentation provided (generation failed).*

### `usage()`

*No documentation provided (generation failed).*

### `brains()`

*No documentation provided (generation failed).*

### `brainOf(String stickId)`

*No documentation provided (generation failed).*

### `setBrain(String stickId, StickBrain? brain)`

*No documentation provided (generation failed).*

### `signOut()`

*No documentation provided (generation failed).*

### `account()`

*No documentation provided (generation failed).*

### `changePassword(String current, String next)`

*No documentation provided (generation failed).*

### `deleteAccount(String password)`

*No documentation provided (generation failed).*

### `stickSettings(String stickId)`

*No documentation provided (generation failed).*

### `updateStick`

```dart
Future<void> updateStick(
  String stickId,
  { String? description, String? instructions, String? thinking, bool?
      readAloud, bool? crossSpace, bool? manageOwnSticks, bool? notify, }
)
```

*No documentation provided (generation failed).*

### `setComputerPrivate(String stickId, bool private)`

*No documentation provided (generation failed).*

### `deleteStick(String stickId, {required bool deleteMemories})`

*No documentation provided (generation failed).*

### `createSpace(String name)`

*No documentation provided (generation failed).*

### `vault()`

*No documentation provided (generation failed).*

### `removeVaultItem(String name)`

*No documentation provided (generation failed).*

### `addVaultItem(VaultDraft draft)`

*No documentation provided (generation failed).*

### `appCatalog({String query = ''})`

*No documentation provided (generation failed).*

### `finishConnect(String connectionId)`

*No documentation provided (generation failed).*

### `setDefaultBrain(StickBrain brain)`

*No documentation provided (generation failed).*
