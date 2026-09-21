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

// RoutePresence: the "does this compose actually have that route?" question
// an SDK must be able to ask before it offers an optional destination.
//
// AppRoutes' host implementation throws out of noSuchMethod for a method no
// installed SDK declared, which is right for a navigation the app cannot do
// without and wrong for an optional affordance like "and here is your
// profile". These pin both answers, and pin the route NAME against
// base_sdk's own manifest so the name can never drift into one nothing
// mounts.

import 'dart:convert';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/navigation/route_presence.dart';

/// A root router carrying exactly [names], which is all [RoutePresence] looks
/// at.
class _FakeRootRouter extends Fake implements RootStackRouter {
  _FakeRootRouter(List<String> names)
      : routeCollection = RouteCollection.fromList(
          names
              .map((String name) => AutoRoute(
                    path: '/${name.toLowerCase()}',
                    page: PageInfo(name,
                        builder: (RouteData _) => const SizedBox.shrink()),
                  ))
              .toList(),
          root: true,
        );

  @override
  final RouteCollection routeCollection;
}

class _FakeStackRouter extends Fake implements StackRouter {
  _FakeStackRouter(this.root);

  @override
  final RootStackRouter root;
}

/// Puts [names] on the router above the probe, exactly as an app shell's
/// generated router sits above every SDK widget.
Future<bool?> _ask(
  WidgetTester tester,
  String routeName, {
  List<String>? names,
}) async {
  bool? answer;
  final Widget probe = Builder(
    builder: (BuildContext context) {
      answer = RoutePresence.has(context, routeName);
      return const SizedBox.shrink();
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      home: names == null
          ? probe
          : StackRouterScope(
              controller: _FakeStackRouter(_FakeRootRouter(names)),
              stateHash: 0,
              child: probe,
            ),
    ),
  );
  return answer;
}

void main() {
  group('RoutePresence.has', () {
    testWidgets('is false, not a throw, with no router above the widget',
        (tester) async {
      expect(
        await _ask(tester, RoutePresence.genericProfileRouteName),
        isFalse,
      );
    });

    testWidgets('is true when the host router carries the route',
        (tester) async {
      expect(
        await _ask(
          tester,
          RoutePresence.genericProfileRouteName,
          names: <String>[RoutePresence.genericProfileRouteName],
        ),
        isTrue,
      );
    });

    testWidgets('is false when the host router carries other routes only',
        (tester) async {
      expect(
        await _ask(
          tester,
          RoutePresence.genericProfileRouteName,
          names: <String>['SplashRoute', 'MaintenanceRoute'],
        ),
        isFalse,
      );
    });
  });

  group('the generic profile route name', () {
    test('is the one base_sdk\'s manifest mounts, and it declares a push', () {
      final Map<String, dynamic> manifest = jsonDecode(
        File('manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final List<String> pages = (manifest['routes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> route) => route['page'] as String)
          .toList();
      expect(pages, contains('${RoutePresence.genericProfileRouteName}.page'));

      final List<String> bodies = (manifest['app_routes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> entry) => entry['body'] as String)
          .toList();
      expect(
        bodies,
        contains(
            'context.router.push(${RoutePresence.genericProfileRouteName}());'),
      );
    });
  });
}
