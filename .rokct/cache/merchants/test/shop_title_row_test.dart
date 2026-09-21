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


// The restaurant hub's shop title row at the two geometries the
// paas_manager guided tour (run 33952102598) walks: the 240 dpi tablet
// (1280x800 logical at dpr 1.5 — three planes, the hub capped at two, so
// the narrowest section column of any leg) where the old bare Row
// overflowed its column by 22 px, and the phone. The row is pumped where
// the template mounts it — a ProfileSection inside GenericProfilePage
// under RestaurantHubPlaneFlow — so the column width is the real one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:merchants_sdk/src/manager/presentation/restaurant/restaurant_hub_plane_flow.dart';
import 'package:merchants_sdk/src/manager/presentation/restaurant/shop_title_row.dart';

class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

// Sixteen characters — the most RestaurantHelpers.truncate lets through.
const String _title = 'Mokoena Kitchens';

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

  var edits = 0;

  setUp(() {
    edits = 0;
    ProfileSectionRegistry.I.reset();
    ProfileSectionRegistry.I.register(
      ProfileSection(
        id: 'merchants.shop_info',
        order: 10,
        builder: (_) => ShopTitleRow(
          title: _title,
          rating: '4.8',
          onEdit: () => edits++,
        ),
      ),
    );
  });

  /// [logical] is the window in logical px; [dpr] its density. Wide
  /// windows take their logical size as the design size and compact ones
  /// the 375x812 phone design, exactly as base_sdk's app_widget does.
  Future<void> pumpAt(
    WidgetTester tester, {
    required Size logical,
    required double dpr,
  }) async {
    tester.view.physicalSize = logical * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: logical.width < 600 ? const Size(375, 812) : logical,
          builder: (context, _) => MaterialApp(
            home: RestaurantHubPlaneFlow(
              hubBuilder: (context) => const GenericProfilePage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void expectRowIntact(WidgetTester tester) {
    // No RenderFlex overflow was reported while laying the row out.
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.byKey(const Key('shopTitleRowTitle')));
    final rating =
        tester.getRect(find.byKey(const Key('shopTitleRowRating')));
    final promo =
        tester.getRect(find.byKey(const Key('shopTitleRowPromoBadge')));
    final edit = tester.getRect(find.byKey(const Key('shopTitleRowEdit')));
    final row = tester.getRect(find.byType(ShopTitleRow));
    // Reading order holds: title, rating, badges, pencil — and the pencil
    // is still inside the row, at its end edge.
    expect(title.right, lessThanOrEqualTo(rating.left));
    expect(rating.right, lessThanOrEqualTo(promo.left));
    expect(promo.right, lessThan(edit.left));
    expect(edit.right, lessThanOrEqualTo(row.right + 0.5));
    expect(edit.right, greaterThan(row.right - 1.5));
  }

  testWidgets(
      '240 dpi tablet (1280x800 logical, dpr 1.5): the row renders with '
      'no overflow and the pencil stays on the end edge', (tester) async {
    await pumpAt(tester, logical: const Size(1280, 800), dpr: 1.5);
    expect(find.byType(ShopTitleRow), findsOneWidget);
    expectRowIntact(tester);
  });

  testWidgets('phone (390x844 logical, dpr 3): the same row, no overflow',
      (tester) async {
    await pumpAt(tester, logical: const Size(390, 844), dpr: 3);
    expect(find.byType(ShopTitleRow), findsOneWidget);
    expectRowIntact(tester);
    await tester.tap(find.byKey(const Key('shopTitleRowEdit')));
    expect(edits, 1);
  });
}
