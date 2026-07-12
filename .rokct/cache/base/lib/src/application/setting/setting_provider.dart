import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/application/setting/setting_notifier.dart';
import 'package:base_sdk/src/application/setting/setting_state.dart';

final settingProvider = StateNotifierProvider<SettingNotifier, SettingState>(
  (ref) => SettingNotifier(settingsRepository, userRepository),
);
