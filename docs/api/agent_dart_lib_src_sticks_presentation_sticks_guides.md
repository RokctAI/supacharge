# API Reference: sticks_guides

Source file: `agent/dart/lib/src/sticks/presentation/sticks_guides.dart`

## Classes

### class `SticksGuide`

Coach-marks for [definition] over [child], while the owner has guides on
(Profile > Advanced > Show guides).

### class `SticksActiveTab`

Whether the tab around it is the one showing. The tabs sit in one
IndexedStack, where the hidden ones are still laid out, so a tip on a
hidden tab would otherwise count as on screen.

### class `SticksTip`

The target of a tip, only while its tab is the one showing.

## Whitelisted API Endpoints

### `showSticksGuidesAgain()`

Shows the guides again: each starts over the next time its page opens.

### `SticksGuide({super.key, required this.definition, required this.child})`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `SticksActiveTab({super.key, required this.active, required super.child})`

*No documentation provided (generation failed).*

### `of(BuildContext context)`

*No documentation provided (generation failed).*

### `updateShouldNotify(SticksActiveTab old)`

*No documentation provided (generation failed).*

### `SticksTip(this.id, {super.key, required this.child})`

*No documentation provided (generation failed).*
