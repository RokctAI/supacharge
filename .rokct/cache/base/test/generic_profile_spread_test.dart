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


// GenericProfilePage self-spread (the approved plane proposal, frame 1c,
// capped by the approved 4c ruling "will just let profile take two plane
// max"): granted planes by a PlaneHost above, the page spreads its
// registered sections across AT MOST TWO of them — two balanced columns
// at two or more planes, the untouched phone list at one.

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
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';

// The page never touches the repositories in this test (no stored token,
// so fetchUser returns before its first repository call); the notifier
// only needs constructible instances.
class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

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
    for (var i = 0; i < 5; i++) {
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

  // The profile's declaration per the approved 4c ruling ("will just let
  // profile take two plane max"): the page claims PlaneSpan.two, never
  // all — at a three-plane width the third plane follows normal rules
  // (bare stage or flow neighbor).
  Future<void> pumpProfile(
    WidgetTester tester,
    double width, {
    PlaneSpan span = PlaneSpan.two,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: Size(width, 1400),
          builder: (context, _) => MaterialApp(
            home: PlaneHost(
              stack: [
                PlanePage(
                  name: 'profile',
                  span: span,
                  builder: (_) => const GenericProfilePage(),
                ),
              ],
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
    for (var i = 0; i < 5; i++) {
      edges.add(
        tester
            .getTopLeft(find.byKey(ValueKey('section$i')))
            .dx
            .roundToDouble(),
      );
    }
    return edges;
  }

  testWidgets(
      'three-plane width: the profile takes two planes max — two columns',
      (tester) async {
    await pumpProfile(tester, 900);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('section$i')), findsOneWidget);
    }
    // The 4c cap: two balanced columns, and the page's surface stops at
    // its two granted planes — the third plane is not the profile's.
    expect(columnEdges(tester), hasLength(2));
    final pageRight = tester
        .getRect(find.byKey(const ValueKey('plane-page-profile')))
        .right;
    final twoPlanes = 2 * (900 - 2 * 14) / 3 + 14;
    expect(pageRight, moreOrLessEquals(twoPlanes, epsilon: 0.5));
  });

  testWidgets(
      'the cap is universal: even a host granting ALL planes gets two columns',
      (tester) async {
    // The ruling is for EVERY GenericProfilePage host: the cap lives in
    // the page itself, so a host that declares the profile PlaneSpan.all
    // at a three-plane width still gets a two-column spread — no
    // composition can produce a third.
    await pumpProfile(tester, 900, span: PlaneSpan.all);
    expect(columnEdges(tester), hasLength(2));
  });

  testWidgets('two planes: sections spread across two columns',
      (tester) async {
    await pumpProfile(tester, 700);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('section$i')), findsOneWidget);
    }
    expect(columnEdges(tester), hasLength(2));
  });

  testWidgets('one plane: the untouched phone list — one column',
      (tester) async {
    await pumpProfile(tester, 500);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('section$i')), findsOneWidget);
    }
    expect(columnEdges(tester), hasLength(1));
    // The phone layout is the plain ListView, not the spread body.
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('registry order reads down the columns left to right',
      (tester) async {
    await pumpProfile(tester, 900);
    // Contiguous balanced split preserves registry order: a later
    // section is never in an earlier column.
    double dxOf(int i) =>
        tester.getTopLeft(find.byKey(ValueKey('section$i'))).dx;
    for (var i = 0; i < 4; i++) {
      expect(dxOf(i + 1), greaterThanOrEqualTo(dxOf(i)));
    }
  });
}
