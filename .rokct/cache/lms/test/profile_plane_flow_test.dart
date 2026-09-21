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
// The approved lms profile plane cascade (frames 1d/1e/1g, approval
// confirmed 2026-08-29 10:34Z "1d,e,g were approved with only fix being
// back button"): the profile declares TWO planes (the universal profile
// cap) and yields-but-spreads; the Subjects thread takes the LAST plane
// with the default one-plane claim; tapping a subject LEVEL-SWAPS the
// last plane 340 -> 341 without moving the planes beneath; the corner
// pill pops the NEWEST level, never the profile.

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Transitive via base_sdk; test-only use, same as the fleet's other plane
// flow tests (revenue_plane_flow_test).
// ignore: depend_on_referenced_packages
import 'package:flutter_screenutil/flutter_screenutil.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The corner pill's label goes through AppHelpers.getTranslation,
    // which reads LocalStorage — seed an empty store so the humanized-key
    // fallback answers.
    SharedPreferences.setMockInitialValues(const {});
    await LocalStorage.init();
  });

  Widget host({
    required Size size,
    required bool subjectsOpen,
    String? selectedSubject,
    required void Function() onBack,
    void Function(Planes)? onProfilePlanes,
    void Function(Planes)? onThreadPlanes,
  }) => ScreenUtilInit(
    designSize: size,
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: LmsProfilePlaneFlow(
          subjectsOpen: subjectsOpen,
          selectedSubject: selectedSubject,
          profileBuilder: (context) {
            onProfilePlanes?.call(Planes.of(context));
            return const Text('PROFILE');
          },
          subjectsBuilder: (context) {
            onThreadPlanes?.call(Planes.of(context));
            return const Text('SUBJECTS-340');
          },
          subjectDetailBuilder: (context, subject) {
            onThreadPlanes?.call(Planes.of(context));
            return Text('DETAIL-$subject');
          },
          onBack: onBack,
        ),
      ),
    ),
  );

  testWidgets(
      'profile cap: alone at three planes the profile claims TWO, never '
      'all — the third plane stays an empty stage, no pill', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? profilePlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        subjectsOpen: false,
        onBack: () {},
        onProfilePlanes: (p) => profilePlanes = p,
      ),
    );
    expect(find.text('PROFILE'), findsOneWidget);
    expect(profilePlanes!.count, 3);
    expect(profilePlanes!.span, 2);
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets(
      '1d: the Subjects list takes the LAST plane with the default '
      'one-plane claim; the profile yields but keeps spreading over the '
      'remaining two; the corner pill appears', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? profilePlanes;
    Planes? threadPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        subjectsOpen: true,
        onBack: () {},
        onProfilePlanes: (p) => profilePlanes = p,
        onThreadPlanes: (p) => threadPlanes = p,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('SUBJECTS-340'), findsOneWidget);
    expect(profilePlanes!.count, 3);
    expect(profilePlanes!.span, 2);
    expect(profilePlanes!.index, 0);
    expect(threadPlanes!.span, 1);
    expect(threadPlanes!.index, 2);
    expect(threadPlanes!.isLast, isTrue);
    expect(find.byType(FloatingBackPill), findsOneWidget);
  });

  testWidgets(
      '1g: selecting a subject LEVEL-SWAPS the last plane 340 -> 341; the '
      'profile keeps its two planes untouched; the pill pops the newest '
      'level', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool popped = false;
    Planes? profilePlanes;
    Planes? threadPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        subjectsOpen: true,
        selectedSubject: 'Mathematics',
        onBack: () => popped = true,
        onProfilePlanes: (p) => profilePlanes = p,
        onThreadPlanes: (p) => threadPlanes = p,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SUBJECTS-340'), findsNothing);
    expect(find.text('DETAIL-Mathematics'), findsOneWidget);
    expect(profilePlanes!.count, 3);
    expect(profilePlanes!.span, 2);
    expect(profilePlanes!.index, 0);
    expect(threadPlanes!.span, 1);
    expect(threadPlanes!.index, 2);
    expect(threadPlanes!.isLast, isTrue);
    expect(find.byType(FloatingBackPill), findsOneWidget);

    await tester.tap(find.byType(FloatingBackPill));
    expect(popped, isTrue);
  });

  testWidgets(
      '1e: two-plane fallback — the profile compresses to one plane (its '
      'phone layout) with the deepest level beside it', (tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? profilePlanes;
    Planes? threadPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(700, 800),
        subjectsOpen: true,
        selectedSubject: 'Mathematics',
        onBack: () {},
        onProfilePlanes: (p) => profilePlanes = p,
        onThreadPlanes: (p) => threadPlanes = p,
      ),
    );
    await tester.pumpAndSettle();
    expect(profilePlanes!.count, 2);
    expect(profilePlanes!.span, 1);
    expect(threadPlanes!.span, 1);
    expect(threadPlanes!.isLast, isTrue);
    expect(find.byType(FloatingBackPill), findsOneWidget);
  });

  testWidgets(
      'phone: the flow hosts the profile alone — the thread is ignored '
      '(Subjects is a REAL pushed route there) and no pill renders',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? profilePlanes;
    await tester.pumpWidget(
      host(
        size: const Size(393, 852),
        subjectsOpen: true,
        onBack: () {},
        onProfilePlanes: (p) => profilePlanes = p,
      ),
    );
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('SUBJECTS-340'), findsNothing);
    expect(profilePlanes!.count, 1);
    expect(profilePlanes!.span, 1);
    expect(find.byType(FloatingBackPill), findsNothing);
  });
}
