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


// Regression guard for the composed app's route wiring, which is DATA in
// this manifest rather than code in lib/ (agent/radio's manifest_wiring_test
// pattern). Fix-wave 2026-09-02 (G6): the pre-fork customer routes this SDK
// owns are declared here with their AppRoutes seam implementations; a
// composed app's lib/ is generated and gitignored, so nothing else in this
// package can fail when the manifest stops declaring what the shell needs.
//
// What it guards: every declared route's page has a matching
// @RoutePage(name:) shell in templates/routes/ (auto_route only generates
// classes for the HOST's lib/, which is where the template installs), every
// app_routes entry navigates to a route this SDK declares and imports the
// host router, and the template file is actually installed.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest =
      jsonDecode(File('manifest.json').readAsStringSync()) as Map<String, dynamic>;
  final block = (manifest['app_type'] as Map)['customer'] as Map<String, dynamic>;

  List<Map<String, dynamic>> listOf(String key) =>
      ((block[key] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList();

  final shellSource = Directory('templates/routes')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  const expectedRoutes = <String, String>{
    '/shop': 'ShopRoute',
    '/shops_detail': 'ShopDetailRoute',
  };
  const expectedSeams = <String>[
    'pushShopRoute',
    'replaceShopRoute',
    'pushShopDetailRoute',
  ];

  group('merchants_sdk manifest route wiring (app_type.customer)', () {
    test('declares the pre-fork customer paths with their route classes', () {
      final declared = {
        for (final r in listOf('routes'))
          r['path'] as String: (r['page'] as String).replaceAll('.page', ''),
      };
      expectedRoutes.forEach((path, page) {
        expect(declared, containsPair(path, page));
      });
      for (final r in listOf('routes')) {
        expect(
          r['import'],
          startsWith('package:\${package}/presentation/routes/'),
          reason: 'routes must point at the installed shell file, not lib/',
        );
      }
    });

    test('every declared page has a @RoutePage shell in templates/routes', () {
      for (final r in listOf('routes')) {
        final page = (r['page'] as String).replaceAll('.page', '');
        expect(
          shellSource,
          contains("@RoutePage(name: '$page')"),
          reason: '$page has no shell, so auto_route generates nothing for '
              '${r['path']}',
        );
      }
    });

    test('fills the AppRoutes seams this SDK owns', () {
      final appRoutes = listOf('app_routes');
      final methods = appRoutes.map((r) => r['method']).toSet();
      expect(methods, containsAll(expectedSeams));

      final declared = listOf('routes')
          .map((r) => (r['page'] as String).replaceAll('.page', ''))
          .toSet();
      for (final route in appRoutes) {
        final body = route['body'] as String;
        expect(body, isNotEmpty,
            reason: 'an app_routes entry with no body is dropped silently');
        expect(
          declared.any(body.contains),
          isTrue,
          reason: '${route['method']} navigates to a route no SDK declares, '
              'which auto_route drops from the generated router: $body',
        );
        expect(
          (route['imports'] as List).cast<String>(),
          contains("import 'package:\${package}/presentation/routes/app_router.dart';"),
          reason: 'the generated route classes must resolve in main.dart',
        );
        final params = route['params'] as String?;
        if (params != null) {
          expect(params, startsWith('BuildContext context'),
              reason: 'params become an @override of base_sdk AppRoutes');
        }
      }
    });

    test('installs the shell file the routes import', () {
      final installed = listOf('installs').map((i) => i['to']).toSet();
      final imported = listOf('routes')
          .map((r) => (r['import'] as String)
              .replaceFirst('package:\${package}/', 'lib/'))
          .toSet();
      for (final imp in imported) {
        expect(installed, contains(imp),
            reason: '$imp is imported by a route but never installed');
      }
    });
  });
}
