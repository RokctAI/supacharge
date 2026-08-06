// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: base_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:base_sdk/src/application/app_widget/app_provider.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/settings.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:supacharge/core/presentation/routes/app_router.dart';

class AppWidget extends ConsumerWidget {
  const AppWidget({super.key});

  static final _appRouter = AppRouter();

  Future<void> _fetchSettings() async {
    // Settings live behind comms_sdk's registration; apps composed without
    // it simply skip the remote settings fetch.
    if (!getIt.isRegistered<SettingsRepositoryFacade>()) return;
    final connect = await Connectivity().checkConnectivity();
    if (connect.contains(ConnectivityResult.mobile) ||
        connect.contains(ConnectivityResult.ethernet) ||
        connect.contains(ConnectivityResult.wifi)) {
      settingsRepository.getGlobalSettings();
      await settingsRepository.getLanguages();
      await settingsRepository.getMobileTranslations();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    // Dark-first: on the very first launch seed the theme to dark, then honour
    // the user's explicit choice thereafter. AppStyle.isDark is the single
    // app-wide flag the mode-resolving surface tokens read.
    final bool isDark;
    if (!LocalStorage.getThemeSeeded()) {
      LocalStorage.setThemeSeeded(true);
      isDark = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(appProvider.notifier).changeTheme(true),
      );
    } else {
      isDark = state.isDarkMode;
    }
    AppStyle.isDark = isDark;
    return FutureBuilder(
      future: Future.wait([
        if (LocalStorage.getTranslations().isEmpty) _fetchSettings(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        return ScreenUtilInit(
          useInheritedMediaQuery: false,
          designSize: const Size(375, 812),
          builder: (context, child) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerDelegate: _appRouter.delegate(
                // Dev/demo entry: `--dart-define=DEMO_START_ROUTE=/schedule`
                // lands directly on that surface (e.g. to reach the demo
                // lesson without a backend). Unset (default) = normal splash
                // flow, production behaviour unchanged.
                deepLinkBuilder: (deepLink) {
                  const demoRoute =
                      String.fromEnvironment('DEMO_START_ROUTE');
                  return demoRoute.isEmpty
                      ? deepLink
                      : DeepLink.path(demoRoute);
                },
              ),
              routeInformationParser: _appRouter.defaultRouteParser(),
              locale: Locale(state.activeLanguage?.locale ?? 'en'),
              theme: ThemeData(brightness: Brightness.light, useMaterial3: false),
              darkTheme:
                  ThemeData(brightness: Brightness.dark, useMaterial3: false),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            );
          },
        );
      },
    );
  }
}
