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
// LmsProfilePlaneHost's DETAIL PLANE for the partner profile (tablet audit
// 2026-09-07: supacharge still 17's partner_profile left the third plane
// empty; Ray, "on a tablet the generic profile host must not leave the
// third plane empty"). registerPartnerSections given a
// studentsDetailBuilder names the Students section the registry's default;
// the host, given that id, seeds its detail — the pay-toggle list — into
// the THIRD plane as the landing state (no pill, the tab's full nav stays)
// while the section's card in the profile folds to a summary row, so the
// list is never shown twice. A detail a card opens on top is a pushed step
// the corner pill pops back to the default. Two planes seed nothing and
// keep the list inline; a phone is the bare profile, unchanged.

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_navigator.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Transitive via base_sdk; test-only use, same as profile_plane_flow_test.
// ignore: depend_on_referenced_packages
import 'package:flutter_screenutil/flutter_screenutil.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

// The host reads base_sdk's profile capabilities before seeding (never the
// repositories themselves); the notifier only needs constructible
// instances — the same fakes base_sdk's own default-section test uses.
class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

class _FixedAccess implements AccessStatusSource {
  @override
  Future<AccessStatus> current() async => AccessStatus.partner;
}

/// Two linked students, one paid for — enough for a list with two rows.
class _TwoStudentSource implements PartnerReportSource {
  @override
  Future<List<LinkedStudent>> students() async => const [
        LinkedStudent(id: 'thabo', name: 'Thabo', paidByPartner: true),
        LinkedStudent(id: 'naledi', name: 'Naledi'),
      ];

  @override
  Future<PartnerReport> weeklyReport(DateTime weekStart,
          {String? studentId}) async =>
      PartnerReport(
          studentName: studentId == 'naledi' ? 'Naledi' : 'Thabo',
          weekStart: weekStart,
          sessionsAttended: 1);

  @override
  Future<List<PartnerAlert>> alerts() async => const [];
}

/// The seam PlaneHost puts between planes (its default gap).
const _gap = 14.0;

/// A second section with a detail — what "another card" opens on top of
/// the seeded default.
const _otherId = 'lms.test.other';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const {});
    await LocalStorage.init();
    getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt
        .registerSingleton<GalleryRepositoryFacade>(_FakeGalleryRepository());
  });

  final deps = PartnerDashboardDeps(
    source: _TwoStudentSource(),
    access: _FixedAccess(),
  );

  setUp(() {
    ProfileSectionRegistry.I.reset();
    // The shell's registration: the partner sections with the Students
    // detail over the SAME deps, the persona gate resolving true.
    LmsProfileSections.registerPartnerSections(
      visible: () async => true,
      deps: deps,
      studentsDetailBuilder: (context) => LmsPartnerStudentsPane(deps: deps),
    );
    ProfileSectionRegistry.I.register(ProfileSection(
      id: _otherId,
      order: 900,
      builder: (context) => TextButton(
        key: const ValueKey('card-other'),
        onPressed: () => ProfileSectionNavigator.open(context, _otherId),
        child: const SizedBox(height: 40, width: double.infinity),
      ),
      detailBuilder: (context) =>
          const SizedBox.expand(key: ValueKey('detail-other')),
    ));
  });

  /// The profile the way GenericProfilePage lays its sections out: the
  /// registered cards, top to bottom (the page's own chrome is base_sdk's
  /// concern, not this seam's).
  Widget profile(BuildContext context) => ListView(
        key: const ValueKey('profile-list'),
        children: [
          for (final id in [
            LmsProfileSections.partnerStudentsSectionId,
            _otherId,
          ])
            Builder(builder: ProfileSectionRegistry.I.section(id)!.builder),
        ],
      );

  /// The partner tab the way the route shell composes it: the host filling
  /// the screen with the FULL persona nav painted over it, bottom-centre.
  Widget tab({required Size size, String? defaultSectionId}) => ProviderScope(
        child: ScreenUtilInit(
          designSize: size,
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: LmsProfilePlaneHost(
                      defaultSectionId: defaultSectionId,
                      profileBuilder: profile,
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
    String? defaultSectionId = LmsProfileSections.partnerStudentsSectionId,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(tab(size: size, defaultSectionId: defaultSectionId));
    // The persona gate and the dashboard's student fetch both resolve
    // asynchronously — settle before looking.
    await tester.pumpAndSettle();
  }

  /// The profile's own subtree in the host — its granted planes.
  Finder profilePlanes() => find.byKey(
        const ValueKey('plane-page-${LmsProfilePlaneHost.planePageName}'),
      );

  /// The Students detail's subtree in the host.
  Finder studentsDetail() => find.byKey(ValueKey(
        'plane-page-${LmsProfilePlaneHost.detailPageName(LmsProfileSections.partnerStudentsSectionId)}',
      ));

  /// The nav the shell paints over the host: still there, still
  /// bottom-centre — never folded to a corner pill.
  void expectFullNav(WidgetTester tester, Size size) {
    final nav = tester.getRect(find.byKey(const ValueKey('partner-nav')));
    expect(nav.center.dx, size.width / 2);
    expect(nav.bottom, size.height);
    expect(find.byType(FloatingBackPill), findsNothing);
  }

  test('registering the Students detail names it the registry default',
      () {
    expect(ProfileSectionRegistry.I.defaultSectionId,
        LmsProfileSections.partnerStudentsSectionId);
    expect(ProfileSectionRegistry.I.defaultSection, isNotNull);
  });

  testWidgets(
      'three-plane tablet (1066 dp): the Students list is open in the '
      'THIRD plane as the landing state, the card in the profile folds to '
      'its row; the profile keeps two planes, full nav, no pill',
      (tester) async {
    const size = Size(1066, 800);
    await pumpTab(tester, size);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(studentsDetail(), findsOneWidget);

    // The list — both names, both toggles — is in the detail plane only.
    expect(find.text('Thabo'), findsOneWidget);
    expect(find.text('Naledi'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    final planeWidth = (size.width - 2 * _gap) / 3;
    final twoPlanes = 2 * planeWidth + _gap;
    expect(tester.getRect(profilePlanes()).right,
        moreOrLessEquals(twoPlanes, epsilon: 0.5));
    expect(tester.getRect(studentsDetail()).left,
        moreOrLessEquals(twoPlanes + _gap, epsilon: 0.5));
    expect(tester.getRect(find.text('Thabo')).left,
        greaterThan(twoPlanes + _gap));

    // The profile column shows the section's row, not the list twice.
    expect(find.byType(LmsSettingCard), findsOneWidget);
    expect(tester.getRect(find.byType(LmsSettingCard)).right,
        lessThan(twoPlanes + 1));

    // The landing state is not a pushed step.
    expectFullNav(tester, size);
  });

  testWidgets(
      'three planes: another card\'s detail replaces the default on top '
      '(the list returns to the profile inline); the corner pill pops it '
      'back to the seeded Students list', (tester) async {
    const size = Size(1066, 800);
    await pumpTab(tester, size);

    await tester.tap(find.byKey(const ValueKey('card-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-other')), findsOneWidget);
    expect(studentsDetail(), findsNothing);
    // Not open in the host any more: the card is the inline list again.
    expect(find.byType(LmsSettingCard), findsNothing);
    expect(find.text('Thabo'), findsOneWidget);
    expect(find.byType(FloatingBackPill), findsOneWidget);

    await tester.tap(find.byType(FloatingBackPill));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-other')), findsNothing);
    expect(studentsDetail(), findsOneWidget);
    expect(find.byType(LmsSettingCard), findsOneWidget);
    expectFullNav(tester, size);
  });

  testWidgets(
      'two-plane tablet (800 dp): nothing is seeded — the profile keeps '
      'both planes with the list inline; full nav, no pill', (tester) async {
    const size = Size(800, 1280);
    await pumpTab(tester, size);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(studentsDetail(), findsNothing);
    expect(tester.getRect(profilePlanes()).right, size.width);
    // The list, inline, exactly as before; no row.
    expect(find.text('Thabo'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.byType(LmsSettingCard), findsNothing);

    expectFullNav(tester, size);
  });

  testWidgets(
      'three planes, no defaultSectionId: the host as before — the third '
      'plane stays the bare stage, the list inline', (tester) async {
    const size = Size(1066, 800);
    await pumpTab(tester, size, defaultSectionId: null);

    expect(find.byType(PlaneHost), findsOneWidget);
    expect(studentsDetail(), findsNothing);
    expect(find.text('Thabo'), findsOneWidget);
    expect(find.byType(LmsSettingCard), findsNothing);
    expectFullNav(tester, size);
  });

  testWidgets('phone: the bare profile, no host — the list inline as before',
      (tester) async {
    const size = Size(393, 852);
    await pumpTab(tester, size);

    expect(find.byType(PlaneHost), findsNothing);
    expect(studentsDetail(), findsNothing);
    expect(find.text('Thabo'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.byType(LmsSettingCard), findsNothing);
    expectFullNav(tester, size);
  });
}
