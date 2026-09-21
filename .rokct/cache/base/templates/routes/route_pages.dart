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


// Host-side route shells for base_sdk's initial pages.
//
// auto_route's generator only scans the host package, so SDK-resident pages
// are wrapped in thin @RoutePage shells here. Feature SDKs contribute their
// own shells through their manifest installs when they own routed pages.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:base_sdk/src/presentation/pages/initial/maintenance/maintenance_page.dart' as pages;
import 'package:base_sdk/src/presentation/pages/initial/no_connection/no_connection_page.dart' as pages;
import 'package:base_sdk/src/presentation/pages/initial/splash/splash_page.dart' as pages;
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_route_page.dart' as pages;

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

/// Host route shell for [pages.MaintenancePage] (base_sdk-resident page).
@RoutePage(name: 'MaintenanceRoute')
class MaintenanceRouteView extends StatelessWidget {
  const MaintenanceRouteView({super.key});

  @override
  Widget build(BuildContext context) => const pages.MaintenancePage();
}

/// Host route shell for the generic profile (base_sdk-resident page):
/// [pages.GenericProfileRoutePage] hosts GenericProfilePage in a two-plane
/// PlaneHost with the corner Back pill at plane widths, the phone page
/// untouched on a phone.
/// Named GenericProfileRoute: marketplace_sdk already owns ProfileRoute.
@RoutePage(name: 'GenericProfileRoute')
class GenericProfileRouteView extends StatelessWidget {
  const GenericProfileRouteView({super.key});

  @override
  Widget build(BuildContext context) => const pages.GenericProfileRoutePage();
}
