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

// Regression guard for the composed app's wiring, which is DATA in this
// manifest rather than code in lib/ (radio_sdk's manifest_wiring_test
// pattern): a composed app's lib/ is generated and gitignored, so nothing
// else in this package can fail when the manifest stops declaring what the
// host needs.
//
// What it guards: the pre-fork `/term` and `/policy` routes are served by
// TermRoute / PolicyRoute, which only exist because
// templates/routes/corporate_route_pages.dart carries a
// `@RoutePage(name: ...)` shell per route AND the manifest installs that
// file into the host's lib/presentation/routes/. Drop either half and
// auto_route silently generates nothing — the path 404s at runtime. The
// embedded_widgets assertion pins the other seam: auth's login footer
// reaches the same pages through EmbeddedWidgets.I.termPage()/policyPage()
// and must keep doing so after the routed entry was added.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// `flutter test` runs with the package directory as its working
  /// directory, so the manifest sits right next to `pubspec.yaml`.
  final manifest =
      jsonDecode(File('manifest.json').readAsStringSync()) as Map<String, dynamic>;

  List<Map<String, dynamic>> listOf(String key) =>
      ((manifest[key] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList();

  const routePages = 'templates/routes/corporate_route_pages.dart';

  group('corporate_sdk manifest route wiring', () {
    test('declares the pre-fork /term and /policy paths', () {
      final byPath = {for (final r in listOf('routes')) r['path']: r};
      expect(byPath.keys, containsAll(['/term', '/policy']));
      expect(byPath['/term']!['page'], 'TermRoute.page');
      expect(byPath['/policy']!['page'], 'PolicyRoute.page');
    });

    test('every route resolves against the installed route-pages shell',
        () {
      final shell = File(routePages).readAsStringSync();
      for (final route in listOf('routes')) {
        final page = (route['page'] as String).replaceAll('.page', '');
        expect(
          shell,
          contains("@RoutePage(name: '$page')"),
          reason: '$page has no @RoutePage shell in $routePages, so the '
              "host's auto_route build generates nothing for ${route['path']}",
        );
        expect(
          route['import'],
          'package:\${package}/presentation/routes/corporate_route_pages.dart',
          reason: 'the route class is generated from the INSTALLED shell, '
              "not from corporate_sdk's own lib/",
        );
        expect(route['type'], 'MaterialRoute');
      }
    });

    test('installs the route-pages shell into the host', () {
      final install = listOf('installs').singleWhere(
        (i) => i['from'] == routePages,
        orElse: () => <String, dynamic>{},
      );
      expect(install, isNotEmpty,
          reason: 'without this install the routes import a file the host '
              'does not have');
      expect(install['to'], 'lib/presentation/routes/corporate_route_pages.dart');
    });

    test("the auth footer's embedded-widget seam is still declared", () {
      final methods = listOf('embedded_widgets').map((w) => w['method']);
      expect(methods, containsAll(['termPage', 'policyPage']));
    });
  });
}
