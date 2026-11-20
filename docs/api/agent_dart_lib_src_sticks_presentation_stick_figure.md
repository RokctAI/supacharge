# API Reference: stick_figure

Source file: `agent/dart/lib/src/sticks/presentation/stick_figure.dart`

## Classes

### class `StickFigure`

One Stick, drawn from the design's 200 x 280 drawing. [crop] shows the
whole body, the head on a round avatar, or the head peeking over a sheet.
In [dark] the Stick keeps its colours; only a thin white outline is added
around the black lines, cut off above the ground shadow so it never
touches it.

### class `StickPainter`

## Whitelisted API Endpoints

### `n()`

*No documentation provided (generation failed).*

### `StickFigure`

```dart
const StickFigure({
  super.key,
  required this.look,
  this.mood = StickMood.neutral,
  this.crop = StickCrop.full,
  this.dark = false,
  this.outlineAlpha = .4,
  this.shadow = true,
})
```

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `StickPainter`

```dart
const StickPainter({
  required this.look,
  required this.mood,
  required this.view,
  required this.dark,
  required this.outlineAlpha,
  required this.shadow,
})
```

*No documentation provided (generation failed).*

### `paint(Canvas canvas, Size size)`

*No documentation provided (generation failed).*

### `shouldRepaint(StickPainter o)`

*No documentation provided (generation failed).*

### `draw()`

*No documentation provided (generation failed).*
