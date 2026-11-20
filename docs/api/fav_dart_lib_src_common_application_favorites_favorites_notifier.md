# API Reference: favorites_notifier

Source file: `fav/dart/lib/src/common/application/favorites/favorites_notifier.dart`

## Classes

### class `FavoritesNotifier`

## Whitelisted API Endpoints

### `build()`

*No documentation provided (generation failed).*

### `fetchFavoritesShop(BuildContext context)`

Loads the liked shop IDs from the device, then the shops themselves.

### `toggleShop(String shopId)`

Likes or unlikes a shop on the device; returns true when now liked.
A newly liked shop is fetched and added to [FavoritesState.shops]
when online, so the list matches the count without a manual refresh;
offline it arrives with the next [fetchFavoritesShop].
