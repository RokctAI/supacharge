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
// Three planes land with the Subjects thread OPEN (Ray 2026-09-07, "on a
// tablet the generic profile host must not leave the third plane empty"):
// with [LmsProfilePlaneFlow.subjectsDefault] the Subjects list is the last
// plane's landing state — shown without a push, so no corner pill at the
// list level; the pill appears only at the subject detail and pops it
// back to the list. Without the flag, and on a phone, the flow is exactly
// as before.

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Transitive via base_sdk; test-only use, same as profile_plane_flow_test.
// ignore: depend_on_referenced_packages
import 'package:flutter_screenutil/flutter_screenutil.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const {});
    await LocalStorage.init();
  });

  Widget host({
    required Size size,
    required bool subjectsOpen,
    required bool subjectsDefault,
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
          subjectsDefault: subjectsDefault,
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
      'three planes, subjectsDefault: the list is open in the LAST plane '
      'on the first frame with nothing pushed — the profile keeps two, '
      'no corner pill', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? profilePlanes;
    Planes? threadPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        subjectsOpen: false,
        subjectsDefault: true,
        onBack: () {},
        onProfilePlanes: (p) => profilePlanes = p,
        onThreadPlanes: (p) => threadPlanes = p,
      ),
    );
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('SUBJECTS-340'), findsOneWidget);
    expect(profilePlanes!.count, 3);
    expect(profilePlanes!.span, 2);
    expect(profilePlanes!.index, 0);
    expect(threadPlanes!.span, 1);
    expect(threadPlanes!.index, 2);
    expect(threadPlanes!.isLast, isTrue);
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets(
      'three planes, subjectsDefault: a subject on top of the landing list '
      'is a pushed level — the pill shows and pops it', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var popped = false;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        subjectsOpen: false,
        subjectsDefault: true,
        selectedSubject: 'Mathematics',
        onBack: () => popped = true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DETAIL-Mathematics'), findsOneWidget);
    expect(find.text('SUBJECTS-340'), findsNothing);
    expect(find.byType(FloatingBackPill), findsOneWidget);

    await tester.tap(find.byType(FloatingBackPill));
    expect(popped, isTrue);
  });

  testWidgets(
      'without subjectsDefault the flow is as before: three planes, thread '
      'closed, the third plane stays the bare stage', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        subjectsOpen: false,
        subjectsDefault: false,
        onBack: () {},
      ),
    );
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('SUBJECTS-340'), findsNothing);
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets(
      'phone: subjectsDefault is ignored — the profile alone, no thread, '
      'no pill', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? profilePlanes;
    await tester.pumpWidget(
      host(
        size: const Size(390, 844),
        subjectsOpen: false,
        subjectsDefault: true,
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
