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

// Regression guard for the composed app's navigation wiring, which is
// DATA in this manifest rather than code in lib/: the host's
// _HostAppRoutes only carries the methods some installed SDK declares in
// `app_routes`, and every seam nobody fills resolves to
// _UnsetAppRoutes.noSuchMethod -> StateError at the call site.
//
// What it guards (route map 2026-09-02, row 3 `/login`): base_sdk's
// AppRoutes declares BOTH replaceLoginRoute (splash's empty-token branch)
// and pushLoginRoute (the guest "sign in to continue" prompts in
// merchants/products/marketplace). auth_sdk owns LoginPage, so auth_sdk
// is the one place both must be filled. It also checks that every route
// this manifest declares has its @RoutePage shell in templates/routes/,
// because auto_route only generates route classes for widgets in the
// host's own lib/ (see auth_route_pages.dart) — a route pointing at a
// page with no shell is dropped silently from the generated router.

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

  // Route classes declared by other SDKs that auth_sdk may legitimately
  // navigate to without owning them. Empty since auth_sdk stopped declaring
  // replaceUiTypeRoute: base_sdk's /ui-type picker is removed in base_sdk
  // 1.58.0, so every app_routes body below targets a route this SDK declares.
  const baseOwnedRoutes = <String>{};

  group('auth_sdk manifest navigation wiring', () {
    test('fills both login seams base_sdk\'s AppRoutes declares', () {
      final appRoutes = listOf('app_routes');
      final methods = appRoutes.map((r) => r['method']).toSet();

      expect(methods, containsAll(['replaceLoginRoute', 'pushLoginRoute']));

      for (final route in appRoutes) {
        expect(route['body'], isNotEmpty,
            reason: 'an app_routes entry with no body is dropped silently');
        expect(
          (route['imports'] as List).cast<String>(),
          contains(
              "import 'package:\${package}/presentation/routes/app_router.dart';"),
          reason: 'the generated route classes must resolve in main.dart',
        );
      }
    });

    test('pushLoginRoute pushes (keeps the caller) and replaceLoginRoute '
        'replaces', () {
      final byMethod = {
        for (final r in listOf('app_routes')) r['method'] as String: r,
      };
      expect(byMethod['pushLoginRoute']!['body'],
          'context.router.push(LoginRoute());');
      expect(byMethod['replaceLoginRoute']!['body'],
          'context.router.replace(LoginRoute());');
    });

    test('every app_routes body targets a route this SDK (or base) declares',
        () {
      final declared = listOf('routes')
          .map((r) => (r['page'] as String).replaceAll('.page', ''))
          .toSet()
        ..addAll(baseOwnedRoutes);

      expect(declared, contains('LoginRoute'));

      for (final route in listOf('app_routes')) {
        final body = route['body'] as String;
        expect(
          declared.any(body.contains),
          isTrue,
          reason: '${route['method']} navigates to a route no SDK declares, '
              'which auto_route drops from the generated router: $body',
        );
      }
    });

    test('every declared route has its @RoutePage shell in templates/routes',
        () {
      final shells = Directory('templates/routes')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');

      for (final route in listOf('routes')) {
        final page = (route['page'] as String).replaceAll('.page', '');
        expect(
          shells,
          contains("@RoutePage(name: '$page')"),
          reason: '${route['path']} points at $page, which has no '
              '@RoutePage(name:) wrapper in templates/routes/',
        );
        expect(
          route['import'],
          startsWith('package:\${package}/presentation/routes/'),
          reason: 'routes must import the installed shell, not auth_sdk lib/',
        );
      }
    });
  });
}
