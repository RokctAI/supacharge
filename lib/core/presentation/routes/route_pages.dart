// Host-side route shells for base_sdk's initial pages.
//
// auto_route's generator only scans the host package, so SDK-resident pages
// are wrapped in thin @RoutePage shells here. Feature SDKs contribute their
// own shells through their manifest installs when they own routed pages.
// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: base_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:base_sdk/src/presentation/pages/initial/closed/closed_page.dart' as pages;
import 'package:base_sdk/src/presentation/pages/initial/no_connection/no_connection_page.dart' as pages;
import 'package:base_sdk/src/presentation/pages/initial/splash/splash_page.dart' as pages;
import 'package:base_sdk/src/presentation/pages/initial/ui_type/ui_type_page.dart' as pages;

/// Host route shell for [pages.SplashPage] (base_sdk-resident page).
@RoutePage(name: 'SplashRoute')
class SplashRouteView extends StatelessWidget {
  const SplashRouteView({super.key});

  @override
  Widget build(BuildContext context) => const pages.SplashPage();
}

/// Host route shell for [pages.NoConnectionPage] (base_sdk-resident page).
@RoutePage(name: 'NoConnectionRoute')
class NoConnectionRouteView extends StatelessWidget {
  const NoConnectionRouteView({super.key});

  @override
  Widget build(BuildContext context) => const pages.NoConnectionPage();
}

/// Host route shell for [pages.ClosedPage] (base_sdk-resident page).
@RoutePage(name: 'ClosedRoute')
class ClosedRouteView extends StatelessWidget {
  const ClosedRouteView({super.key});

  @override
  Widget build(BuildContext context) => const pages.ClosedPage();
}

/// Host route shell for [pages.UiTypePage] (base_sdk-resident page).
@RoutePage(name: 'UiTypeRoute')
class UiTypeRouteView extends StatelessWidget {
  final bool isBack;
  const UiTypeRouteView({super.key, this.isBack = false});

  @override
  Widget build(BuildContext context) => pages.UiTypePage(isBack: isBack);
}
