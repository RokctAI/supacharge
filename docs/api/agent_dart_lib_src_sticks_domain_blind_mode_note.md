# API Reference: blind_mode_note

Source file: `agent/dart/lib/src/sticks/domain/blind_mode_note.dart`

## Classes

### class `BlindModeNote`

Tells a Stick that blind mode is on for it (Ray, 2026-11-11: "will
stick know its now in blind mode?"). Kept as one marked block in its
instructions, added when blind mode picks it and taken out when blind
mode is turned off.

## Whitelisted API Endpoints

### `apply(String instructions, bool on)`

[instructions] with the block in ([on]) or out. Idempotent.
