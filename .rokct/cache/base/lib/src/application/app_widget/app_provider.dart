import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:base_sdk/src/application/app_widget/app_notifier.dart';
import 'package:base_sdk/src/application/app_widget/app_state.dart';

final appProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(),
);
