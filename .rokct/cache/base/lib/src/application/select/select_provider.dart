import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:base_sdk/src/application/select/select_state.dart';
import 'package:base_sdk/src/application/select/select_notifier.dart';

final selectProvider =
    StateNotifierProvider.autoDispose<SelectNotifier, SelectState>(
  (ref) => SelectNotifier(),
);
