# API Reference: card_widgets

Source file: `lib/src/card_widgets.dart`

## Classes

### class `SDKColors`

### class `ARCardFront`

### class `ARCardBack`

## Whitelisted API Endpoints

### `SDKColors`

```dart
const SDKColors({
  this.background = const Color(0xFF0A0E12),
  this.surface = const Color(0xFF141A22),
  this.accent = const Color(0xFF00E676),
  this.alert = const Color(0xFFFF3D00),
  this.textPrimary = Colors.white,
  this.textSecondary = const Color(0xFF90A4AE),
})
```

*No documentation provided (generation failed).*

### `ARCardFront`

```dart
const ARCardFront({
  super.key,
  required this.match,
  required this.isFav,
  this.colors = const SDKColors(),
})
```

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `ARCardBack`

```dart
const ARCardBack({
  super.key,
  required this.match,
  required this.isFav,
  required this.isFollowing,
  required this.recommendedStake,
  required this.onPlaceBet,
  this.showBetting = true,
  this.colors = const SDKColors(),
})
```

*No documentation provided (generation failed).*
