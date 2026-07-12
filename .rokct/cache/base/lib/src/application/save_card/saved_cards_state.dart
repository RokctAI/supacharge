import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:base_sdk/src/models/data/saved_card.dart';

part 'saved_cards_state.freezed.dart';

@freezed
class SavedCardsState with _$SavedCardsState {
  const factory SavedCardsState({
    @Default([]) List<SavedCardModel> cards,
    @Default(false) bool isLoading,
    String? error,
  }) = _SavedCardsState;

  const SavedCardsState._();
}
