# API Reference: assistant_history_store

Source file: `agent/dart/lib/src/common/infrastructure/services/assistant_history_store.dart`

## Classes

### class `AssistantHistoryStore`

Reads and writes [AssistantHistoryTable] for the signed-in account - the
"assistant chat history saved per account" that agent_sdk 1.0.4 scoped
but nothing used.
Speaks plain SQL through [GeneratedDatabase] (radio_sdk's
`DriftListenStatsStore` precedent): the generated
`assistantHistoryTable` accessor only exists on base_sdk's composed
AppDatabase, while custom statements compile and unit test standalone
against any database holding the table. Date values go through drift
[Variable]s and [QueryRow.read], so they follow the database's own
date-time storage setting.
Owner-scoped:
* a write stamps `OwnerScope.instance.current`, resolved per call (the
store outlives sign-ins). With nobody signed in nothing is written:
an unowned row would be visible to whoever signs in next.
* a read is base_sdk's `ownerVisible` rule as SQL: this account's rows
plus unowned (pre-scoping) ones. Another account's messages are never
returned.
Local and best-effort: no network, and every failure is logged and
swallowed. A chat that cannot save or load its history still works, and
offline it works exactly as online.

## Whitelisted API Endpoints

### `AssistantHistoryStore(this._db)`

*No documentation provided (generation failed).*

### `save`

```dart
Future<bool> save(
  ChatMessage message,
  { String session = kAssistantChatHistorySession, }
)
```

Saves [message] to the signed-in account's transcript for [session].
Saving the same id again updates it rather than adding a row. Returns
whether a row was written.

### `load`

```dart
Future<List<ChatMessage>> load({
  String session = kAssistantChatHistorySession,
  int limit = defaultLimit,
})
```

The signed-in account's latest [limit] messages in [session], oldest
first. Empty when there are none or they cannot be read.
