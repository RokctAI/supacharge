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
//
// LmsProfilePlaneHost — a profile TAB on planes with no thread (the
// partner profile): at plane widths the profile sits in a two-plane
// PlaneHost (the universal profile cap, frames 1c/1f — two planes at
// most, the leftover plane a bare stage at the END); the host never
// draws a corner Back pill, because a top-level tab keeps its FULL
// floating nav (12:36Z; the bare pill is for pushed pages only, 12d) and
// the route shell paints that nav over the host, bottom-centre, exactly
// as before. On a phone the host is the bare profile.

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Transitive via base_sdk; test-only use, same as profile_plane_flow_test.
// ignore: depend_on_referenced_packages
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The seam PlaneHost puts between planes (its default gap).
const _gap = 14.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The partner tab the way the route shell composes it: the host filling
  /// the screen with the FULL persona nav painted over it, bottom-centre.
  Widget tab({
    required Size size,
    void Function(Planes?)? onProfilePlanes,
  }) => ProviderScope(
    child: ScreenUtilInit(
      designSize: size,
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: LmsProfilePlaneHost(
                  profileBuilder: (context) {
                    onProfilePlanes?.call(Planes.maybeOf(context));
                    return const Text('PROFILE');
                  },
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: ValueKey('partner-nav'),
                  width: 240,
                  height: 56,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> pumpTab(
    WidgetTester tester,
    Size size, {
    void Function(Planes?)? onProfilePlanes,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(tab(size: size, onProfilePlanes: onProfilePlanes));
    await tester.pump();
  }

  /// The profile's own subtree in the host — its granted planes.
  Finder profilePlanes() => find.byKey(
        const ValueKey('plane-page-${LmsProfilePlaneHost.planePageName}'),
      );

  /// The nav the shell paints over the host: still there, still
  /// bottom-centre — never folded to a corner pill.
  void expectFullNav(WidgetTester tester, Size size) {
    final nav = tester.getRect(find.byKey(const ValueKey('partner-nav')));
    expect(nav.center.dx, size.width / 2);
    expect(nav.bottom, size.height);
    expect(find.byType(FloatingBackPill), findsNothing);
  }

  testWidgets(
      'three-plane tablet (1066 dp): hosted, capped at TWO planes, the '
      'third a bare stage at the END; full nav kept, no Back pill',
      (tester) async {
    const size = Size(1066, 800);
    Planes? planes;
    await pumpTab(tester, size, onProfilePlanes: (p) => planes = p);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
    expect(planes, isNotNull);
    expect(planes!.count, 3);
    expect(planes!.span, 2);
    expect(planes!.index, 0);
    // The universal profile cap: two of the three planes, the third a
    // bare stage — the content does not stretch across the window.
    final planeWidth = (size.width - 2 * _gap) / 3;
    final twoPlanes = 2 * planeWidth + _gap;
    final rect = tester.getRect(profilePlanes());
    expect(rect.left, 0);
    expect(rect.right, moreOrLessEquals(twoPlanes, epsilon: 0.5));

    expectFullNav(tester, size);
  });

  testWidgets(
      'two-plane tablet (800 dp): hosted across both planes; full nav '
      'kept, no Back pill', (tester) async {
    const size = Size(800, 1280);
    Planes? planes;
    await pumpTab(tester, size, onProfilePlanes: (p) => planes = p);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(planes, isNotNull);
    expect(planes!.count, 2);
    expect(planes!.span, 2);
    // Two planes IS the grant here: the page gets the whole window, on
    // the plane grid.
    expect(tester.getRect(profilePlanes()).right, size.width);

    expectFullNav(tester, size);
  });

  testWidgets('phone: the bare profile, no host — exactly as before',
      (tester) async {
    const size = Size(393, 852);
    var built = false;
    Planes? planes;
    await pumpTab(tester, size, onProfilePlanes: (p) {
      built = true;
      planes = p;
    });

    expect(find.byType(PlaneHost), findsNothing);
    expect(find.text('PROFILE'), findsOneWidget);
    expect(built, isTrue);
    expect(planes, isNull);
    expect(tester.getRect(find.text('PROFILE')).left, 0);

    expectFullNav(tester, size);
  });
}
