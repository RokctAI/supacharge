// saved_cards_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/application/save_card/saved_card_notifier.dart';
import 'package:base_sdk/src/application/save_card/saved_cards_state.dart';

// Provider for saved cards
final savedCardsProvider =
    StateNotifierProvider<SavedCardsNotifier, SavedCardsState>((ref) {
  return SavedCardsNotifier();
});
