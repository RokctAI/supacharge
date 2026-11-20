# API Reference: drift_tables

Source file: `agent/dart/lib/src/common/infrastructure/database/drift_tables.dart`

## Classes

### class `AssistantCacheTable`

Answers the assistant has already produced, keyed by the question.
Deliberately NOT owner-scoped: the question and its answer are content,
not a record of who asked. Two accounts on one device asking the same
thing should share the cached answer rather than each pay for it, and a
row here says nothing about either of them. Only the transcript in
[AssistantHistoryTable] does.

### class `AssistantHistoryTable`

One account's chat transcript with the assistant.
Owner-scoped. One device, one `rokct_app.sqlite`, one process-wide
AppDatabase: without an owner on the row, the account that signs in next
reads the previous account's conversation. Scoping is a VISIBILITY rule -
signing out writes nothing and deletes nothing here, it only stops the
next account seeing these rows.

## Whitelisted API Endpoints

### `ensureAgentOwnerScopeColumns(GeneratedDatabase db)`

Brings `assistant_history_table` up to the owner-scoped definition when
the opened file predates it, and does nothing at all when it does not.
A plain `ALTER TABLE ... ADD COLUMN` is not enough: `owner` joins the
PRIMARY KEY and SQLite cannot alter a primary key in place. So the table
is rebuilt the long way round - rename the old one aside, create the new
one from its current Dart definition, copy every column the two have in
common, drop the old one. `owner` is not among those columns, so every
row already on the device takes its `''` default and comes out unowned,
which is exactly the state the visibility rule treats as the current
account's. Nothing is deleted and no owner is guessed.
Idempotent and self-checking, so it is safe in the manifest migration
step, in a `beforeOpen` floor, or in both - the same reasoning as
base_sdk's `AppDatabase.ensureOwnerScopeColumns`. Returns the tables it
actually rebuilt, which is what the tests assert on.
