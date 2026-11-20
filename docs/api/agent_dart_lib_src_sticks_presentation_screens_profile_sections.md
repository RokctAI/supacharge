# API Reference: profile_sections

Source file: `agent/dart/lib/src/sticks/presentation/screens/profile_sections.dart`

## Classes

### class `SticksAdvancedCard`

The original app's Advanced group: folded until opened, with whether
replies show as they are written and whether web pictures load.

### class `SticksAboutRows`

The app's version, and Delete account where there is an account.

### class `SticksUsageStats`

Runs, tokens and cost, under the name in the profile's user card. Tapping
it opens Usage.

### class `SticksSettingsRows`

Every Sticks settings page: models, approvals, the vault and the rest on
a Sticks server; the index of them on the platform.

### class `SticksLockRows`

What the lock screen shows of an ask, and a preview of it.

## Whitelisted API Endpoints

### `registerSticksProfileSections`

```dart
void registerSticksProfileSections({
  required Widget Function(BuildContext context, Widget child) scope,
  required StickExtras? Function() extras,
  required void Function(BuildContext context) onSignOut,
})
```

The Sticks part of the app's shared profile page, the one every fleet app
opens: the page itself keeps the user card (name, email, the edit pencil),
the theme switch and Sign out; the Sticks add their usage under the name
and their own sections below it.
[scope] puts a [SticksScope] above each piece, since the profile page is
not a Sticks screen; [extras] is what that scope reads, so the account
gates can ask it without a context.
The page draws Sign out and the edit pencil only where the app wired
them, so this wires both (`??=`: a composition that already owns them
keeps its own): [onSignOut] ends the session and leaves the page, and
the pencil opens the shared edit sheet.

### `hasAccount()`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `toggle(String key, bool on, ValueChanged<bool> set)`

*No documentation provided (generation failed).*

### `groupThousands(int n)`

17271336 as 17,271,336.

### `open(String screen)`

*No documentation provided (generation failed).*

### `pickBlindStick(BuildContext context)`

Picks the one Stick blind mode talks to, then says how to leave it.
