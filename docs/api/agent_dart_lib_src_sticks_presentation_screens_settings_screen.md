# API Reference: settings_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/settings_screen.dart`

## Classes

### class `SettingsScreen`

Settings: the person's account, appearance and the team. On a Sticks
server it is the original app's Account page: name and email, usage,
password, appearance and every settings page, then Sign out. The gear on
Your team opens it, and it covers the whole app.

### class `SettingsGroup`

A rounded group of settings rows with hairlines between them, like the
original app's grouped lists.

### class `SettingsLink`

One row of a [SettingsGroup]: a title, an optional line under it, an
optional value on the right, and a chevron when it opens a page.

## Whitelisted API Endpoints

### `SettingsScreen`

```dart
const SettingsScreen({
  super.key,
  this.onThemeMode,
  this.themeMode = ThemeMode.system,
  this.offerAuto = true,
})
```

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `SettingsGroup({super.key, required this.children})`

*No documentation provided (generation failed).*

### `SettingsLink`

```dart
const SettingsLink(
  this.title,
  {super.key, this.sub, this.value, this.trailing, this.onTap}
)
```

*No documentation provided (generation failed).*
