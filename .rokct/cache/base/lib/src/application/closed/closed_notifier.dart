import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:base_sdk/src/application/closed/closed_state.dart';

class ClosedNotifier extends StateNotifier<ClosedState> {
  ClosedNotifier() : super(const ClosedState());

  void changeIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }
}
