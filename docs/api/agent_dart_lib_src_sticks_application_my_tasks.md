# API Reference: my_tasks

Source file: `agent/dart/lib/src/sticks/application/my_tasks.dart`

## Classes

### class `MyTasks`

### class `MemoryTodoRepository`

A [TodoRepositoryFacade] in memory: tests, and the standalone [SticksApp].

## Whitelisted API Endpoints

### `MyTasks(this.store)`

*No documentation provided (generation failed).*

### `load()`

Every task, open ones first, newest first within each.

### `at(Map<String, dynamic> t)`

*No documentation provided (generation failed).*

### `find(String id)`

*No documentation provided (generation failed).*

### `idFor(String messageId)`

The id a card in message [messageId] is kept under, so adding the same
card twice keeps one task.

### `has(String messageId)`

*No documentation provided (generation failed).*

### `add(MyTaskCard card, {required String messageId, String? from})`

Adds [card] as a task and returns its id. Already added: nothing changes.

### `save(Map<String, dynamic> task)`

Saves [task] as it is now (a guided run's step, a tick).

### `setDone(Map<String, dynamic> task, bool done)`

*No documentation provided (generation failed).*
