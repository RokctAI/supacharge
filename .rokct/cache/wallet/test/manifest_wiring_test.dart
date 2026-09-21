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

// Regression guard for the composed app's navigation wiring, which is DATA
// in this manifest rather than code in lib/: a composed app's lib/ is
// generated and gitignored, so nothing else in this package can fail when
// the manifest stops declaring what the host needs (same pattern as
// radio_sdk's manifest_wiring_test).
//
// What it guards (fix-wave 2026-09-02, plan item P3 / route-map row 25):
// base_sdk's AppRoutes seam declares pushWalletHistoryRoute, and commerce
// marketplace_sdk's profile page calls it. The host's _HostAppRoutes only
// carries methods some installed SDK declares in `app_routes`; without
// this SDK's entry the call hit noSuchMethod and threw a StateError. The
// entry's body must target a route this SDK actually declares, and that
// route's shell must exist in the installed template, or auto_route drops
// it from the generated router.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = jsonDecode(File('manifest.json').readAsStringSync())
      as Map<String, dynamic>;

  List<Map<String, dynamic>> listOf(String key) =>
      ((manifest[key] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList();

  const appRouterImport =
      "import 'package:\${package}/presentation/routes/app_router.dart';";

  group('wallet_sdk manifest navigation wiring', () {
    test('declares the /wallet-history route the seam pushes', () {
      final history = listOf('routes').singleWhere(
        (r) => r['path'] == '/wallet-history',
        orElse: () => <String, dynamic>{},
      );
      expect(history, isNotEmpty,
          reason: 'the wallet card and the seam both target /wallet-history');
      expect(history['page'], 'WalletHistoryRoute.page');
      expect(
        history['import'],
        "package:\${package}/presentation/routes/wallet_route_pages.dart",
      );
    });

    test('implements AppRoutes.pushWalletHistoryRoute', () {
      final entry = listOf('app_routes').singleWhere(
        (r) => r['method'] == 'pushWalletHistoryRoute',
        orElse: () => <String, dynamic>{},
      );
      expect(entry, isNotEmpty,
          reason: 'without this entry _HostAppRoutes.pushWalletHistoryRoute '
              'falls through to noSuchMethod and throws a StateError');
      // The seam signature is pushWalletHistoryRoute(BuildContext context):
      // no `params` override, so update_app_routes() emits its default.
      expect(entry.containsKey('params'), isFalse);
      expect(entry['body'], 'context.router.push(WalletHistoryRoute());');
      expect(
        (entry['imports'] as List).cast<String>(),
        contains(appRouterImport),
        reason: 'the generated route class must resolve in main.dart',
      );
    });

    test('every app_routes body targets a route this SDK declares', () {
      final declared = listOf('routes')
          .map((r) => (r['page'] as String).replaceAll('.page', ''))
          .toSet();

      expect(declared, containsAll(['WalletHistoryRoute', 'WalletTopUpRoute']));

      for (final route in listOf('app_routes')) {
        final body = route['body'] as String;
        expect(body, isNotEmpty,
            reason: 'an app_routes entry with no body is dropped silently');
        expect(
          declared.any(body.contains),
          isTrue,
          reason: '${route['method']} navigates to a route no SDK declares, '
              'which auto_route drops from the generated router: $body',
        );
      }
    });

    test('the installed route-pages template carries every declared shell',
        () {
      final install = listOf('installs').singleWhere(
        (i) => i['to'] == 'lib/presentation/routes/wallet_route_pages.dart',
        orElse: () => <String, dynamic>{},
      );
      expect(install, isNotEmpty,
          reason: 'the routes block imports this installed file');

      final template = File(install['from'] as String);
      expect(template.existsSync(), isTrue, reason: install['from']);
      final source = template.readAsStringSync();

      for (final route in listOf('routes')) {
        final name = (route['page'] as String).replaceAll('.page', '');
        expect(
          source,
          contains("@RoutePage(name: '$name')"),
          reason: '$name has no @RoutePage shell, so auto_route generates '
              'no class for the ${route['path']} entry',
        );
      }
    });
  });
}
