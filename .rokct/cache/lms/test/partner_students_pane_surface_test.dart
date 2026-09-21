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
// LmsPartnerStudentsPane paints its OWN surface (supacharge Guided Tour run
// 34162139847, tablet at 1066 dp / three planes: 25 exceptions in the
// partner_profile still). The route shell mounts LmsProfilePlaneHost in a
// bare Stack — no Scaffold — and a PlaneHost's detail plane is a sibling of
// the profile, not a descendant of the profile's Scaffold, so the seeded
// pane was the only content in the host with no Material above it: its
// search TextField and every per-student Switch asserted "No Material
// widget found" (13 exceptions), and each Switch's ErrorWidget stand-in — a
// 100000 px RenderErrorBox — made its row "overflow by 99715 pixels" (12
// more). The Subjects pane (a CourseCatalogPage, so a Scaffold) and the
// profile itself (GenericProfilePage, a Scaffold) never had the problem:
// under this seam a detail brings its own surface. The pane now does too.
// Fixture: the shell's composition exactly (host in a Stack, no Scaffold),
// with the demo's 12 linked students — over the search threshold, so the
// TextField shows, and one Switch per student.

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Transitive via base_sdk; test-only use, same as profile_plane_host_test.
// ignore: depend_on_referenced_packages
import 'package:flutter_screenutil/flutter_screenutil.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

class _FixedAccess implements AccessStatusSource {
  @override
  Future<AccessStatus> current() async => AccessStatus.partner;
}

/// The demo fixture's shape: twelve linked students (well over the list's
/// search threshold of eight), half of them paid for.
const _names = [
  'Thabo',
  'Naledi',
  'Sipho',
  'Lerato',
  'Kagiso',
  'Zanele',
  'Bongani',
  'Ayanda',
  'Tumelo',
  'Refilwe',
  'Mpho',
  'Nomvula',
];

class _TwelveStudentSource implements PartnerReportSource {
  @override
  Future<List<LinkedStudent>> students() async => [
        for (var i = 0; i < _names.length; i++)
          LinkedStudent(
            id: _names[i].toLowerCase(),
            name: _names[i],
            paidByPartner: i.isEven,
          ),
      ];

  @override
  Future<PartnerReport> weeklyReport(DateTime weekStart,
          {String? studentId}) async =>
      PartnerReport(
          studentName: studentId ?? _names.first,
          weekStart: weekStart,
          sessionsAttended: 1);

  @override
  Future<List<PartnerAlert>> alerts() async => const [];
}

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
    source: _TwelveStudentSource(),
    access: _FixedAccess(),
  );

  setUp(() {
    ProfileSectionRegistry.I.reset();
    LmsProfileSections.registerPartnerSections(
      visible: () async => true,
      deps: deps,
      studentsDetailBuilder: (context) => LmsPartnerStudentsPane(deps: deps),
    );
  });

  /// The profile the way GenericProfilePage lays its sections out — in
  /// its own Scaffold, as the page does. That Scaffold is the profile
  /// PLANE's; the detail plane beside it is a sibling and never sat under
  /// it, which is exactly what the seeded pane must survive.
  Widget profile(BuildContext context) => Scaffold(
        backgroundColor: AppStyle.surfaceDark,
        body: ListView(
          key: const ValueKey('profile-list'),
          children: [
            Builder(
                builder: ProfileSectionRegistry.I
                    .section(LmsProfileSections.partnerStudentsSectionId)!
                    .builder),
          ],
        ),
      );

  /// PartnerProfileRouteView's composition, verbatim in shape: the host
  /// filling a bare Stack with the persona nav painted over it — no
  /// Scaffold of its own anywhere above the host.
  Widget shell(Size size) => ProviderScope(
        child: ScreenUtilInit(
          designSize: size,
          builder: (_, __) => MaterialApp(
            home: Stack(
              children: [
                Positioned.fill(
                  child: LmsProfilePlaneHost(
                    defaultSectionId:
                        LmsProfileSections.partnerStudentsSectionId,
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
      );

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(shell(size));
    await tester.pumpAndSettle();
  }

  Finder studentsDetail() => find.byKey(ValueKey(
        'plane-page-${LmsProfilePlaneHost.detailPageName(LmsProfileSections.partnerStudentsSectionId)}',
      ));

  testWidgets(
      'three-plane tablet (1066 dp), the shell\'s bare Stack, 12 students: '
      'the seeded Students pane renders its search box and every pay '
      'toggle without a single framework exception or overflow',
      (tester) async {
    const size = Size(1066, 800);
    await pumpShell(tester, size);

    // The run's 25: 13x "No Material widget found" (the Search TextField
    // and 12 _MaterialSwitch) and 12x "A RenderFlex overflowed by 99715
    // pixels on the right" (each Switch's error box in its row).
    expect(tester.takeException(), isNull);

    expect(studentsDetail(), findsOneWidget);
    // The pane carries its own Material, so the framework's checks pass
    // for the search field and each of the 12 toggles.
    expect(
      find.descendant(of: studentsDetail(), matching: find.byType(Material)),
      findsWidgets,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(_names.length));
    for (final name in _names) {
      expect(find.text(name), findsOneWidget);
    }
    // Every row fits its plane: nothing overflowed, so no error box.
    expect(find.byType(ErrorWidget), findsNothing);
    final detail = tester.getRect(studentsDetail());
    for (final toggle in find.byType(Switch).evaluate()) {
      final rect = tester.getRect(find.byWidget(toggle.widget));
      expect(rect.right, lessThanOrEqualTo(detail.right + 0.5));
      expect(rect.left, greaterThanOrEqualTo(detail.left - 0.5));
    }
  });

  testWidgets(
      'two-plane tablet (800 dp), the same bare shell: nothing is seeded, '
      'the list is inline under the profile — no exception either',
      (tester) async {
    const size = Size(800, 1280);
    await pumpShell(tester, size);
    expect(tester.takeException(), isNull);
    expect(find.byType(PlaneHost), findsOneWidget);
    expect(studentsDetail(), findsNothing);
    // Inline, the card collapses to its first four rows (the search box
    // still shows over twelve); under the profile's own Scaffold both
    // were always fine — the seam is the detail plane's alone.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(4));
  });
}
