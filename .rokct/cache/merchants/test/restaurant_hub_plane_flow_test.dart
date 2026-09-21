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

// The manager restaurant hub on planes (approved 1f / 7d / 7e; tablet
// store review 2026-09-02, still 08-restaurant_hub: the hub rendered ONE
// column at 800 logical because the tab host put GenericProfilePage on
// screen with no PlaneHost above it). RestaurantHubPlaneFlow declares the
// profile's two-plane claim; base_sdk's page then takes its spread branch
// at two planes and its phone list at one.
//
// restaurant_page.dart itself lives in templates/ with `${package}`
// imports and cannot be pumped from this package; the flow is the lib
// half it wraps the page in, driven here with the real GenericProfilePage
// (the same harness as profile_edit_pencil_gate_test.dart).

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
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:merchants_sdk/src/manager/presentation/restaurant/restaurant_hub_plane_flow.dart';

// The page never touches the repositories here (no stored token, so
// fetchUser returns before its first repository call); the notifier only
// needs constructible instances.
class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    // Six keyed rows standing in for the merchant sections (shop info,
    // working hours, productivity, wallet, sections, footer).
    for (var i = 0; i < 6; i++) {
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

  Future<void> pumpHub(WidgetTester tester, double width,
      {void Function(Planes)? onPlanes}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: Size(width, 1400),
          builder: (context, _) => MaterialApp(
            home: RestaurantHubPlaneFlow(
              hubBuilder: (context) {
                onPlanes?.call(Planes.of(context));
                return const GenericProfilePage();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The distinct left edges of the registered sections — one per column
  /// the page spread itself across.
  Set<double> columnEdges(WidgetTester tester) {
    final edges = <double>{};
    for (var i = 0; i < 6; i++) {
      edges.add(
        tester
            .getTopLeft(find.byKey(ValueKey('section$i')))
            .dx
            .roundToDouble(),
      );
    }
    return edges;
  }

  testWidgets('800 logical (the tour tablet leg): the hub is granted TWO '
      'planes and spreads over two columns (1f / 7d)', (tester) async {
    Planes? planes;
    await pumpHub(tester, 800, onPlanes: (p) => planes = p);
    expect(planes!.count, 2);
    expect(planes!.span, 2);
    expect(planes!.index, 0);
    expect(columnEdges(tester), hasLength(2));
    // A top-level page: full nav, no corner back pill.
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets('three planes: the hub keeps the two-plane cap, the third '
      'plane trails bare at the end (7e)', (tester) async {
    Planes? planes;
    await pumpHub(tester, 1280, onPlanes: (p) => planes = p);
    expect(planes!.count, 3);
    expect(planes!.span, 2);
    expect(planes!.index, 0);
    expect(planes!.isLast, isFalse);
    expect(columnEdges(tester), hasLength(2));
    // Both columns sit inside the first two planes: right of the second
    // column's left edge there is still the bare third plane.
    final planeWidth = (1280 - 2 * 14) / 3;
    for (final edge in columnEdges(tester)) {
      expect(edge, lessThan(2 * planeWidth + 14));
    }
  });

  testWidgets('one plane (phone): the hub renders its one-column list',
      (tester) async {
    Planes? planes;
    await pumpHub(tester, 390, onPlanes: (p) => planes = p);
    expect(planes!.count, 1);
    expect(planes!.span, 1);
    expect(columnEdges(tester), hasLength(1));
  });
}
