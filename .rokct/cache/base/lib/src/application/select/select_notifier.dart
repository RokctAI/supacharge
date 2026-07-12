import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/application/select/select_state.dart';

class SelectNotifier extends StateNotifier<SelectState> {
  SelectNotifier() : super(const SelectState());

  void selectIndex(int index) {
    state = state.copyWith(selectedIndex: index);
  }
}
