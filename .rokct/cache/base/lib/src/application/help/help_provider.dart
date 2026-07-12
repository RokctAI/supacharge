import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/application/help/help_notifier.dart';
import 'package:base_sdk/src/application/help/help_state.dart';

final helpProvider = StateNotifierProvider<HelpNotifier, HelpState>(
  (ref) => HelpNotifier(settingsRepository),
);
