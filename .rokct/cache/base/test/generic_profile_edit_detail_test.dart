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


// The profile's edit form as a DETAIL PANE (Ray 2026-09-08, the sheet fork
// ruling: "sheet = PHONE, plane widths get a pane"): with an
// editProfileDetailBuilder registered, the identity-card pencil opens it
// in the host's last plane on planes and runs onEditProfile (the sheet)
// on a phone; the corner pill returns to the default detail; an embedded
// detail leaves through ProfileSectionNavigator.close; and outside a
// Planes scope every seam answers false so the caller keeps its own
// surface.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_route_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_navigator.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';

class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

/// The seam PlaneHost puts between planes (its default gap).
const _gap = 14.0;

const _subjectsId = 'subjects';
const _editKey = ValueKey('edit-profile-detail');
const _doneKey = ValueKey('edit-profile-done');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt
        .registerSingleton<GalleryRepositoryFacade>(_FakeGalleryRepository());
  });

  /// How often the sheet fallback (onEditProfile) ran — the phone path.
  var sheets = 0;

  /// The planes the edit detail was granted, once open.
  Planes? editPlanes;

  /// The embedded edit form: records its planes and offers a Done that
  /// leaves through the host seam, keeping a counted fallback.
  var closeFallbacks = 0;
  Widget editDetail(BuildContext context) {
    editPlanes = Planes.of(context);
    return SizedBox.expand(
      key: _editKey,
      child: TextButton(
        key: _doneKey,
        onPressed: () {
          if (ProfileSectionNavigator.close(context)) return;
          closeFallbacks++;
        },
        child: const SizedBox(),
      ),
    );
  }

  setUp(() {
    sheets = 0;
    closeFallbacks = 0;
    editPlanes = null;
    ProfileSectionRegistry.I.reset();
    ProfileSectionRegistry.I.register(ProfileSection(
      id: _subjectsId,
      order: 10,
      builder: (context) => const SizedBox(height: 40),
      detailBuilder: (context) =>
          const SizedBox.expand(key: ValueKey('detail-$_subjectsId')),
    ));
    ProfileSectionRegistry.I.defaultSectionId = _subjectsId;
    ProfileSectionRegistry.I.onEditProfile = (_) => sheets++;
    ProfileSectionRegistry.I.editProfileDetailBuilder = editDetail;
  });

  Future<void> pumpRoutedProfile(
    WidgetTester tester, {
    required double width,
    required double height,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: Size(width, height),
          builder: (context, _) => const MaterialApp(
            home: GenericProfileRoutePage(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder profilePlanes() => find.byKey(
        ValueKey('plane-page-${GenericProfileRoutePage.planePageName}'),
      );

  Finder pencil() => find.byIcon(Remix.pencil_line);

  Finder subjectsDetail() => find.byKey(const ValueKey('detail-$_subjectsId'));

  testWidgets(
      'three planes (1066 dp): the pencil opens the edit form in the third '
      'plane in place of the default; the corner Back returns to the '
      'default', (tester) async {
    await pumpRoutedProfile(tester, width: 1066, height: 800);
    expect(subjectsDetail(), findsOneWidget);
    expect(find.byKey(_editKey), findsNothing);

    await tester.tap(pencil());
    await tester.pump();
    expect(find.byKey(_editKey), findsOneWidget);
    expect(subjectsDetail(), findsNothing);
    expect(sheets, 0);

    // The LAST plane, with the default one-plane claim.
    final planes = editPlanes!;
    expect(planes.count, 3);
    expect(planes.index, 2);
    expect(planes.span, 1);
    final planeWidth = (1066 - 2 * _gap) / 3;
    final twoPlanes = 2 * planeWidth + _gap;
    expect(
      tester.getRect(profilePlanes()).right,
      moreOrLessEquals(twoPlanes, epsilon: 0.5),
    );
    expect(
      tester.getRect(find.byKey(_editKey)).left,
      moreOrLessEquals(twoPlanes + _gap, epsilon: 0.5),
    );

    // The pill pops the detail back to the default, not the route.
    expect(find.byType(FloatingBackPill), findsOneWidget);
    await tester.tap(find.byType(FloatingBackPill));
    await tester.pump();
    expect(subjectsDetail(), findsOneWidget);
    expect(find.byKey(_editKey), findsNothing);
    expect(find.byType(FloatingBackPill), findsNothing);
    expect(sheets, 0);
  });

  testWidgets(
      'two planes (800 dp): the pencil opens the edit form beside the '
      'compressed profile; the form\'s own Done closes it through the seam',
      (tester) async {
    await pumpRoutedProfile(tester, width: 800, height: 1280);
    expect(find.byKey(_editKey), findsNothing);
    expect(tester.getRect(profilePlanes()).right, 800);

    await tester.tap(pencil());
    await tester.pump();
    expect(find.byKey(_editKey), findsOneWidget);
    expect(sheets, 0);
    final planes = editPlanes!;
    expect(planes.count, 2);
    expect(planes.index, 1);
    expect(planes.isLast, isTrue);
    expect(
      tester.getRect(profilePlanes()).right,
      moreOrLessEquals((800 - _gap) / 2, epsilon: 0.5),
    );
    expect(find.byType(FloatingBackPill), findsOneWidget);

    await tester.tap(find.byKey(_doneKey));
    await tester.pump();
    expect(closeFallbacks, 0);
    expect(find.byKey(_editKey), findsNothing);
    expect(tester.getRect(profilePlanes()).right, 800);
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets('phone (390 dp): no seam — the pencil runs onEditProfile (the '
      'sheet) exactly as before', (tester) async {
    await pumpRoutedProfile(tester, width: 390, height: 844);
    expect(find.byType(PlaneHost), findsNothing);

    await tester.tap(pencil());
    await tester.pump();
    expect(sheets, 1);
    expect(find.byKey(_editKey), findsNothing);
  });

  testWidgets(
      'a detail alone (no onEditProfile): the pencil draws on planes and '
      'opens it; a phone draws no dead pencil', (tester) async {
    ProfileSectionRegistry.I.onEditProfile = null;

    await pumpRoutedProfile(tester, width: 1066, height: 800);
    expect(pencil(), findsOneWidget);
    await tester.tap(pencil());
    await tester.pump();
    expect(find.byKey(_editKey), findsOneWidget);

    await pumpRoutedProfile(tester, width: 390, height: 844);
    expect(pencil(), findsNothing);
  });

  testWidgets('outside a Planes scope every seam answers false',
      (tester) async {
    late BuildContext scope;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            scope = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      ProfileSectionNavigator.openDetail(
        scope,
        id: 'ad-hoc',
        detailBuilder: (_) => const SizedBox(),
      ),
      isFalse,
    );
    expect(ProfileSectionNavigator.openEditProfile(scope), isFalse);
    expect(ProfileSectionNavigator.canOpenEditProfile(scope), isFalse);
    expect(ProfileSectionNavigator.close(scope), isFalse);
    // Unregistered: nothing to open, whatever the scope.
    ProfileSectionRegistry.I.editProfileDetailBuilder = null;
    expect(ProfileSectionNavigator.openEditProfile(scope), isFalse);
  });

  test('reset clears the edit detail', () {
    expect(ProfileSectionRegistry.I.editProfileDetailBuilder, isNotNull);
    ProfileSectionRegistry.I.reset();
    expect(ProfileSectionRegistry.I.editProfileDetailBuilder, isNull);
    expect(ProfileSectionRegistry.editProfileDetailId, 'base.edit_profile');
  });
}
