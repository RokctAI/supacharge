import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/application/main/main_notifier.dart';
import 'package:base_sdk/src/application/main/main_state.dart';

final mainProvider = StateNotifierProvider<MainNotifier, MainState>(
  (ref) => MainNotifier(),
);
