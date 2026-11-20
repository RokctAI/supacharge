# API Reference: stick_looks

Source file: `agent/dart/lib/src/sticks/domain/stick_looks.dart`

## Classes

### class `StickLooks`

The uniqueness rule: a shirt or dress colour and a hair style already on
the team score against a candidate, and the least repeated one wins. The
seed is the gender and role, so the look does not flicker while a name is typed.

## Whitelisted API Endpoints

### `rolePool(String label)`

*No documentation provided (generation failed).*

### `assign`

```dart
static StickLook assign({
  required StickGender gender,
  required String roleKey,
  required String roleLabel,
  required List<StickLook> team,
  required List<String> teamRoles,
})
```

*No documentation provided (generation failed).*

### `fromHints`

```dart
static StickLook fromHints(
  Map<String, dynamic>? hints,
  StickLook base,
  {String? roleLabel}
)
```

A look from the server's hints (`skin`, `shirt`, `hair`, `hair_color`
as hex or a hair name, `prop` by name). Missing hints fall back to [base].

### `hex(Object? v)`

*No documentation provided (generation failed).*

### `shade(Color c)`

*No documentation provided (generation failed).*

### `why`

```dart
static String why({
  required StickGender gender,
  required String roleLabel,
  required StickLook look,
  required List<StickLook> team,
  required List<String> teamNames,
  required List<String> teamRoles,
})
```

The line setup shows under the chips, in the intro's wording.
