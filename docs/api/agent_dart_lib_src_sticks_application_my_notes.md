# API Reference: my_notes

Source file: `agent/dart/lib/src/sticks/application/my_notes.dart`

## Classes

### class `MyNotes`

The owner's own notes, in the productivity SDK's note store (Ray,
2026-11-11: notes on the Tasks page, and "Copy to notes" on a message).
Kept on the phone, as the productivity notes are.

## Whitelisted API Endpoints

### `MyNotes(this.store)`

*No documentation provided (generation failed).*

### `load()`

Every note, newest change first.

### `add(String body)`

Saves [body] as a new note; its first line (cut to 60) is the title.

### `save(Map<String, dynamic> note)`

*No documentation provided (generation failed).*

### `remove(String id)`

*No documentation provided (generation failed).*
