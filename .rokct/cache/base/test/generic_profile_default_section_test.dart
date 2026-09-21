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


// GenericProfileRoutePage's DETAIL PLANE (Ray 2026-09-07, "on a tablet the
// generic profile host must not leave the third plane empty"): on a
// three-plane screen the registry's default section has its detail open
// in the third plane from the FIRST frame, the profile keeping its two
// planes; on two planes nothing is seeded; a card opens its detail in the
// host through ProfileSectionNavigator.open instead of pushing, and on a
// phone the seam answers false so the card pushes exactly as before.

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
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_route_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_navigator.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';

// The page never touches the repositories in this test (no stored token,
// so fetchUser returns before its first repository call); the notifier
// only needs constructible instances.
class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

/// The seam PlaneHost puts between planes (its default gap).
const _gap = 14.0;

const _subjectsId = 'subjects';
const _downloadsId = 'downloads';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt
        .registerSingleton<GalleryRepositoryFacade>(_FakeGalleryRepository());
  });

  /// How often a card's fallback push ran — the phone path.
  var fallbacks = 0;

  /// The planes each detail was granted, by section id.
  final detailPlanes = <String, Planes>{};

  /// A card that adopts the seam: open in the host, else "push".
  Widget card(BuildContext context, String id) => TextButton(
        key: ValueKey('card-$id'),
        onPressed: () {
          if (ProfileSectionNavigator.open(context, id)) return;
          fallbacks++;
        },
        child: const SizedBox(height: 40, width: double.infinity),
      );

  Widget detail(BuildContext context, String id) {
    detailPlanes[id] = Planes.of(context);
    return SizedBox.expand(key: ValueKey('detail-$id'));
  }

  setUp(() {
    fallbacks = 0;
    detailPlanes.clear();
    ProfileSectionRegistry.I.reset();
    // Two sections with a detail (Subjects the default) and one without.
    ProfileSectionRegistry.I.register(ProfileSection(
      id: _subjectsId,
      order: 10,
      builder: (context) => card(context, _subjectsId),
      detailBuilder: (context) => detail(context, _subjectsId),
    ));
    ProfileSectionRegistry.I.register(ProfileSection(
      id: _downloadsId,
      order: 20,
      builder: (context) => card(context, _downloadsId),
      detailBuilder: (context) => detail(context, _downloadsId),
    ));
    ProfileSectionRegistry.I.register(ProfileSection(
      id: 'plain',
      order: 30,
      builder: (context) => card(context, 'plain'),
    ));
    ProfileSectionRegistry.I.defaultSectionId = _subjectsId;
  });

  /// The routed page as a composition's ROOT route (nothing to pop), pumped
  /// ONE frame — the first frame the profile lands with.
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

  /// The profile's own subtree in the host — its granted planes.
  Finder profilePlanes() => find.byKey(
        ValueKey('plane-page-${GenericProfileRoutePage.planePageName}'),
      );

  Finder detailOf(String id) => find.byKey(ValueKey('detail-$id'));

  testWidgets(
      'three planes (1066 dp): the default section\'s detail is open in '
      'the third plane on the first frame; the profile keeps two',
      (tester) async {
    await pumpRoutedProfile(tester, width: 1066, height: 800);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(find.byType(GenericProfilePage), findsOneWidget);
    expect(detailOf(_subjectsId), findsOneWidget);
    expect(detailOf(_downloadsId), findsNothing);

    // The detail took the LAST plane with the default one-plane claim.
    final planes = detailPlanes[_subjectsId]!;
    expect(planes.count, 3);
    expect(planes.index, 2);
    expect(planes.span, 1);
    expect(planes.isLast, isTrue);

    // The profile yielded but keeps its two planes — the cap, not less.
    final planeWidth = (1066 - 2 * _gap) / 3;
    final twoPlanes = 2 * planeWidth + _gap;
    expect(
      tester.getRect(profilePlanes()).right,
      moreOrLessEquals(twoPlanes, epsilon: 0.5),
    );
    expect(
      tester.getRect(detailOf(_subjectsId)).left,
      moreOrLessEquals(twoPlanes + _gap, epsilon: 0.5),
    );
    // The default is the landing state: nothing to go back to.
    expect(find.byType(FloatingBackPill), findsNothing);
    expect(fallbacks, 0);
  });

  testWidgets(
      'three planes: another card replaces the default in the third '
      'plane; the corner Back returns to the default', (tester) async {
    await pumpRoutedProfile(tester, width: 1066, height: 800);

    await tester.tap(find.byKey(const ValueKey('card-$_downloadsId')));
    await tester.pump();
    expect(detailOf(_downloadsId), findsOneWidget);
    expect(detailOf(_subjectsId), findsNothing);
    expect(detailPlanes[_downloadsId]!.index, 2);
    expect(find.byType(FloatingBackPill), findsOneWidget);

    await tester.tap(find.byType(FloatingBackPill));
    await tester.pump();
    expect(detailOf(_subjectsId), findsOneWidget);
    expect(detailOf(_downloadsId), findsNothing);
    expect(find.byType(FloatingBackPill), findsNothing);
    expect(fallbacks, 0);
  });

  testWidgets(
      'two planes (800 dp): nothing is seeded — the profile keeps both '
      'planes; a card then opens its detail beside the compressed profile',
      (tester) async {
    await pumpRoutedProfile(tester, width: 800, height: 1280);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(detailOf(_subjectsId), findsNothing);
    expect(tester.getRect(profilePlanes()).right, 800);
    expect(find.byType(FloatingBackPill), findsNothing);

    await tester.tap(find.byKey(const ValueKey('card-$_subjectsId')));
    await tester.pump();
    expect(detailOf(_subjectsId), findsOneWidget);
    final planes = detailPlanes[_subjectsId]!;
    expect(planes.count, 2);
    expect(planes.index, 1);
    expect(planes.span, 1);
    // The profile compressed to plane 1.
    expect(
      tester.getRect(profilePlanes()).right,
      moreOrLessEquals((800 - _gap) / 2, epsilon: 0.5),
    );
    expect(find.byType(FloatingBackPill), findsOneWidget);

    // Back pops the detail, not the route; two planes go back to bare.
    await tester.tap(find.byType(FloatingBackPill));
    await tester.pump();
    expect(detailOf(_subjectsId), findsNothing);
    expect(tester.getRect(profilePlanes()).right, 800);
    expect(find.byType(FloatingBackPill), findsNothing);
    expect(fallbacks, 0);
  });

  testWidgets('a section without a detail never opens in the host',
      (tester) async {
    await pumpRoutedProfile(tester, width: 1066, height: 800);

    await tester.tap(find.byKey(const ValueKey('card-plain')));
    await tester.pump();
    expect(fallbacks, 1);
    // The default stays where it was.
    expect(detailOf(_subjectsId), findsOneWidget);
  });

  testWidgets('phone (390 dp): no seam — the card pushes as before',
      (tester) async {
    await pumpRoutedProfile(tester, width: 390, height: 844);

    expect(find.byType(PlaneHost), findsNothing);
    expect(detailOf(_subjectsId), findsNothing);
    await tester.tap(find.byKey(const ValueKey('card-$_subjectsId')));
    await tester.pump();
    expect(fallbacks, 1);
    expect(detailOf(_subjectsId), findsNothing);
  });
}
