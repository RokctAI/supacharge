# API Reference: sticks_prefs

Source file: `agent/dart/lib/src/sticks/presentation/sticks_prefs.dart`

## Classes

### class `SticksPrefs`

The Sticks flavor's own preferences, per install. Kept in base_sdk's
generic `LocalStorage` JSON record API, the same store the team page's
coach-mark progress uses (`LocalStorageGuideStore`), under one versioned
key the flavor owns.

## Whitelisted API Endpoints

### `setLockShowsWork(bool value)`

*No documentation provided (generation failed).*

### `setReportDay(int? weekday)`

*No documentation provided (generation failed).*

### `setLiveStatus(bool value)`

*No documentation provided (generation failed).*

### `setShowGuides(bool value)`

*No documentation provided (generation failed).*

### `setShortReplies(bool value)`

*No documentation provided (generation failed).*

### `setShortRepliesSynced(bool on, DateTime at)`

*No documentation provided (generation failed).*

### `setShowPokeButton(bool value)`

*No documentation provided (generation failed).*

### `setLastStick(String stickId)`

*No documentation provided (generation failed).*

### `setHaptics(bool value)`

*No documentation provided (generation failed).*

### `setBlindStick(String? stickId)`

*No documentation provided (generation failed).*

### `seesMyTasks(String stickId)`

*No documentation provided (generation failed).*

### `setSeesMyTasks(String stickId, bool on)`

*No documentation provided (generation failed).*

### `setStreamReplies(bool value)`

*No documentation provided (generation failed).*

### `setLoadWebImages(bool value)`

*No documentation provided (generation failed).*

### `unsent(String chatId)`

What the owner typed in a chat and has not sent yet, kept so leaving
the chat or closing the app does not lose it. Empty when nothing waits.

### `setUnsent(String chatId, String text)`

Keeps (or, when [text] is blank, forgets) a chat's unsent text. Does
not notify: only the chat it belongs to shows it.

### `clearUnsent()`

Forgets every chat's unsent text (signing out).

### `setPinned(String chatId, String? id, [String text = ''])`

Pins [id] in a chat (one pin per chat), or with null takes it off.

### `setPanes({double? left, double? right, bool? leftMini, bool? rightOpen})`

Saves the pane sizes. Does not notify: the layout already shows them,
and a notify would reload every open screen.
