import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:base_sdk/src/application/closed/closed_notifier.dart';
import 'package:base_sdk/src/application/closed/closed_state.dart';

final closedProvider =
    StateNotifierProvider.autoDispose<ClosedNotifier, ClosedState>(
  (ref) => ClosedNotifier(),
);
