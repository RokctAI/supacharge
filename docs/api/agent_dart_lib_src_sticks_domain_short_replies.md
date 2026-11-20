# API Reference: short_replies

Source file: `agent/dart/lib/src/sticks/domain/short_replies.dart`

## Classes

### class `ShortReplies`

The "Short replies" rule (Ray, 2026-11-06): on by default, the owner can
turn it off. Rakazo has no brevity setting, so the rule is one marked
block inside each Stick's instructions. The markers let the app add,
update or take out only its own block, never what the owner or the Stick
wrote. It covers chat messages only: documents, code and files stay full
length, and the wording says so.

## Whitelisted API Endpoints

### `has(String instructions)`

Whether [instructions] carry the current rule exactly once.

### `apply(String instructions, bool on)`

[instructions] with the block in place when [on] (where it already is,
else at the end), or taken out. Idempotent, and trimmed the way the
server stores it.

### `placeBlock(String instructions, RegExp block, String? text)`

[instructions] with the blocks [block] matches replaced by [text]: kept
where a single one already is (so the app's blocks never swap places and
rewrite each other), else added at the end; taken out when [text] is
null. Trimmed the way the server stores it.
