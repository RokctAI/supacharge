// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.


import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:base_sdk/src/application/app_widget/app_provider.dart';
import 'package:base_sdk/src/presentation/adaptive/breakpoints.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/settings.dart';
import 'package:base_sdk/src/services/app_ui_keys.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:${package}/presentation/routes/app_router.dart';

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
    final state = ref.refresh(appProvider);
    return FutureBuilder(
      future: Future.wait([
        if (LocalStorage.getTranslations().isEmpty) _fetchSettings(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        return LayoutBuilder(builder: (context, constraints) {
          // Adaptive ScreenUtil scaling: the phone design size only applies
          // to phone-shaped (compact) windows. On wider windows the actual
          // logical size is passed as the design size, so .w/.h/.sp resolve
          // to ~1:1 instead of blowing a 375px design up to desktop width.
          final logicalSize = constraints.biggest;
          final isCompact = logicalSize.width < AppBreakpoints.medium;
          return ScreenUtilInit(
            useInheritedMediaQuery: false,
            designSize: isCompact ? const Size(375, 812) : logicalSize,
            builder: (context, child) {
              return MaterialApp.router(
                debugShowCheckedModeBanner: false,
                // Root messenger handle: lets SDK services without a
                // BuildContext (e.g. comms' DesktopNotificationPoller)
                // surface SnackBars — see base_sdk AppUiKeys.
                scaffoldMessengerKey: AppUiKeys.scaffoldMessenger,
                routerDelegate: _appRouter.delegate(),
                routeInformationParser: _appRouter.defaultRouteParser(),
                locale: Locale(state.activeLanguage?.locale ?? 'en'),
                // AppBarTheme.systemOverlayStyle: without it every Material
                // AppBar derives a style from its background luminance —
                // SystemUiOverlayStyle.light on these dark screens — which
                // repaints the navigation bar opaque black (eating the full
                // frame) and leaves non-AppBar screens with mismatched
                // status icons. Pinning the shared token keeps both bars
                // transparent with white icons everywhere.
                theme: ThemeData(
                  useMaterial3: false,
                  brightness: Brightness.light,
                  scaffoldBackgroundColor: AppStyle.surfaceLightRaw,
                  appBarTheme: const AppBarTheme(
                    systemOverlayStyle: AppStyle.systemUiOverlay,
                  ),
                ),
                // Real dark counterpart built from the AppStyle dark palette
                // (polarity-pinned raw tokens — they track the brand palette
                // injected via injectBrandColors but never flip with the
                // current mode). With darkTheme: wired, the themeMode line
                // below actually switches the Material tree; AppStyle's
                // mode-resolving tokens follow the same isDarkMode state via
                // AppNotifier's AppStyle.setBrightness sync.
                darkTheme: ThemeData(
                  useMaterial3: false,
                  brightness: Brightness.dark,
                  scaffoldBackgroundColor: AppStyle.surfaceDarkRaw,
                  appBarTheme: const AppBarTheme(
                    systemOverlayStyle: AppStyle.systemUiOverlay,
                  ),
                ),
                themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              );
            },
          );
        });
      },
    );
  }
}
