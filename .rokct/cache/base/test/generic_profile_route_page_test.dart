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


// GenericProfileRoutePage — the routed /generic-profile page on planes:
// at plane widths GenericProfilePage sits in a two-plane PlaneHost (the
// approved profile cap, frames 1c/1f — two planes at most, two columns)
// with the pushed page's one Back parked at the bottom-END corner (frame
// 1d, "back button should always be at a corner"); on a phone the page
// renders exactly as before. With no detail beside it the profile is the
// whole flow and presents on its own planes, so those two planes share
// the full window and no stage is left bare (Ray, 2026-09-07: "on a
// tablet the generic profile host must not leave the third plane
// empty").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/blur_wrap.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_route_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';

// The page never touches the repositories in this test (no stored token,
// so fetchUser returns before its first repository call); the notifier
// only needs constructible instances.
class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

const _sectionCount = 5;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt
        .registerSingleton<GalleryRepositoryFacade>(_FakeGalleryRepository());
  });

  setUp(() {
    ProfileSectionRegistry.I.reset();
    for (var i = 0; i < _sectionCount; i++) {
      ProfileSectionRegistry.I.register(
        ProfileSection(
          id: 'section$i',
          order: i * 10,
          builder: (_) => SizedBox(
            key: ValueKey('section$i'),
            height: 40,
            width: double.infinity,
          ),
        ),
      );
    }
  });

  /// The routed page the way a composed app reaches it — PUSHED from a
  /// home page (pushGenericProfileRoute), so the route can pop. With
  /// [pushed] false the page is the root route instead: nothing to go
  /// back to.
  Future<void> pumpRoutedProfile(
    WidgetTester tester, {
    required double width,
    required double height,
    bool pushed = true,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: Size(width, height),
          builder: (context, _) => MaterialApp(
            home: pushed
                ? Builder(
                    builder: (context) => TextButton(
                      key: const ValueKey('open-profile'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GenericProfileRoutePage(),
                        ),
                      ),
                      child: const SizedBox.shrink(),
                    ),
                  )
                : const GenericProfileRoutePage(),
          ),
        ),
      ),
    );
    if (pushed) {
      await tester.tap(find.byKey(const ValueKey('open-profile')));
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// The distinct left edges of the registered sections — one per column
  /// the page spread itself across.
  Set<double> columnEdges(WidgetTester tester) {
    final edges = <double>{};
    for (var i = 0; i < _sectionCount; i++) {
      edges.add(
        tester
            .getTopLeft(find.byKey(ValueKey('section$i')))
            .dx
            .roundToDouble(),
      );
    }
    return edges;
  }

  /// The profile's own subtree in the host — its granted planes.
  Finder profilePlanes() => find.byKey(
        ValueKey('plane-page-${GenericProfileRoutePage.planePageName}'),
      );

  /// The corner pill's frosted housing — the one BlurWrap on screen.
  Finder pillHousing() => find.descendant(
        of: find.byType(FloatingBackPill),
        matching: find.byType(BlurWrap),
      );

  testWidgets(
      'three-plane tablet (1066 dp): hosted, capped at two planes with no '
      'bare stage, Back at the bottom-END corner', (tester) async {
    await pumpRoutedProfile(tester, width: 1066, height: 800);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(find.byType(GenericProfilePage), findsOneWidget);
    // Nothing is seeded here (the registry has no default section), so
    // the profile is the whole flow and presents on its OWN planes: the
    // host clamps the window to the two the cap allows and they share it
    // whole. The cap is still a cap — two planes, two columns — but no
    // third plane is left empty.
    expect(tester.getRect(profilePlanes()).right, 1066);
    expect(columnEdges(tester), hasLength(2));
    final planes =
        Planes.maybeOf(tester.element(find.byType(GenericProfilePage)));
    expect(planes, isNotNull);
    expect(planes!.count, 2);
    expect(planes.span, 2);
    expect(planes.isLast, isTrue);

    // The pushed page's one back: a FloatingBackPill at the bottom-END
    // corner, 16 logical in from both edges.
    expect(find.byType(FloatingBackPill), findsOneWidget);
    final pill = tester.getRect(pillHousing());
    expect(pill.right, 1066 - 16);
    expect(pill.bottom, 800 - 16);
    expect(pill.left, greaterThan(1066 / 2));
  });

  testWidgets(
      'two-plane tablet (800 dp): hosted across both planes, '
      'Back at the bottom-END corner', (tester) async {
    await pumpRoutedProfile(tester, width: 800, height: 1280);

    expect(find.byType(PlaneHost), findsOneWidget);
    // Two planes IS the grant here: the page spreads its two balanced
    // columns over the whole window, on the plane grid.
    expect(tester.getRect(profilePlanes()).right, 800);
    expect(columnEdges(tester), hasLength(2));

    expect(find.byType(FloatingBackPill), findsOneWidget);
    final pill = tester.getRect(pillHousing());
    expect(pill.right, 800 - 16);
    expect(pill.bottom, 1280 - 16);
    expect(pill.left, greaterThan(400));
  });

  testWidgets('the corner is directional: bottom-START in RTL',
      (tester) async {
    tester.view.physicalSize = const Size(1066, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(1066, 800),
          builder: (context, _) => MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-profile'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: GenericProfileRoutePage(),
                    ),
                  ),
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-profile')));
    await tester.pumpAndSettle();

    final pill = tester.getRect(pillHousing());
    expect(pill.left, 16);
    expect(pill.bottom, 800 - 16);
  });

  testWidgets('a root-route profile is hosted but draws no dead Back',
      (tester) async {
    await pumpRoutedProfile(
      tester,
      width: 1066,
      height: 800,
      pushed: false,
    );

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(columnEdges(tester), hasLength(2));
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets('phone (390 dp): GenericProfilePage exactly as before',
      (tester) async {
    await pumpRoutedProfile(tester, width: 390, height: 844);

    expect(find.byType(GenericProfilePage), findsOneWidget);
    expect(find.byType(PlaneHost), findsNothing);
    expect(find.byType(FloatingBackPill), findsNothing);
    expect(Planes.maybeOf(tester.element(find.byType(GenericProfilePage))),
        isNull);
    // The phone list: one column.
    expect(columnEdges(tester), hasLength(1));
  });
}
