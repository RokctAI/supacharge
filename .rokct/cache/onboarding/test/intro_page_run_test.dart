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

import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Frames 46d (tablet) and 46h (phone) of the first-run guided run, on the
/// real [IntroPage]: the position rail, Back, the required/optional fork
/// and the Skip pill, and resuming at the same step on a cold relaunch.
void main() {
  /// A host slide as the installer injects them: its own card, its own
  /// Continue calling scope.next(); optionally reporting done first.
  Widget hostSlide(String id, {bool reportsDone = false}) => Builder(
        builder: (context) {
          final scope = OnboardingSlideScope.of(context);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Text('slide $id'),
            Text('typed:${scope.values['$id.text'] ?? ''}'),
            TextButton(
              key: Key('host.$id.next'),
              onPressed: scope.next,
              child: const Text('host next'),
            ),
            TextButton(
              key: Key('host.$id.type'),
              onPressed: () => scope.setValue('$id.text', 'Ridge'),
              child: const Text('type'),
            ),
            if (reportsDone)
              TextButton(
                key: Key('host.$id.done'),
                onPressed: () => scope.setDone(true),
                child: const Text('done'),
              ),
          ]);
        },
      );

  /// The page sizes its type through ScreenUtil (base_sdk's AppStyle), so
  /// the tree needs the same init a composed app's main.dart gives it.
  Future<void> pumpPage(WidgetTester tester, IntroDeps deps,
      {Size designSize = const Size(390, 844)}) async {
    await tester.pumpWidget(ProviderScope(
      child: ScreenUtilInit(
        designSize: designSize,
        builder: (_, __) => MaterialApp(home: IntroPage(deps: deps)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Frame 46h is PHONE 390; the test default (800x600) classes as a
  /// medium window and would draw the tablet layout.
  void phoneWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> toFirstHostSlide(WidgetTester tester) async {
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm the student"));
    await tester.pumpAndSettle();
  }

  group('46h — the phone fold', () {
    testWidgets('compact rail counts the whole run and names current/next',
        (tester) async {
      phoneWindow(tester);
      final deps = IntroDeps(
        slides: [
          OnboardingSlide(
              content: hostSlide('school'),
              data: const {'id': 'school'},
              title: 'Your school'),
          OnboardingSlide(
              content: hostSlide('grade'),
              data: const {'id': 'grade'},
              title: 'Your grade'),
        ],
        store: InMemoryOnboardingProgressStore(),
      );
      await pumpPage(tester, deps);

      expect(find.byKey(const Key('onboarding.rail.compact')), findsOneWidget);
      expect(find.byKey(const Key('onboarding.rail.full')), findsNothing);
      expect(find.text('STEP 1 OF 5'), findsOneWidget);
      expect(find.text('4 left'), findsOneWidget);
      expect(find.text('next · Who is setting this up?'), findsOneWidget);

      await toFirstHostSlide(tester);
      expect(find.text('STEP 3 OF 5'), findsOneWidget);
      expect(find.text('2 left'), findsOneWidget);
      expect(find.text('Your school'), findsOneWidget);
      expect(find.text('next · Your grade'), findsOneWidget);
    });

    testWidgets('first host slide has no Back; the second does, and it works',
        (tester) async {
      phoneWindow(tester);
      final deps = IntroDeps(
        slides: [
          OnboardingSlide(content: hostSlide('a'), data: const {'id': 'a'}),
          OnboardingSlide(content: hostSlide('b'), data: const {'id': 'b'}),
        ],
        store: InMemoryOnboardingProgressStore(),
      );
      await pumpPage(tester, deps);
      await toFirstHostSlide(tester);

      expect(find.text('slide a'), findsOneWidget);
      expect(find.byKey(const Key('onboarding.back')), findsNothing);

      await tester.tap(find.byKey(const Key('host.a.next')));
      await tester.pumpAndSettle();
      expect(find.text('slide b'), findsOneWidget);
      expect(find.byKey(const Key('onboarding.back')), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding.back')));
      await tester.pumpAndSettle();
      expect(find.text('slide a'), findsOneWidget);
      expect(find.text('STEP 3 OF 5'), findsOneWidget);
    });

    testWidgets('optional step: label + Skip pill; skipping passes unticked',
        (tester) async {
      phoneWindow(tester);
      final deps = IntroDeps(
        slides: [
          OnboardingSlide(content: hostSlide('a'), data: const {'id': 'a'}),
        ],
        store: InMemoryOnboardingProgressStore(),
      );
      await pumpPage(tester, deps);
      // Welcome carries no Skip (single card) and no step label.
      expect(find.byKey(const Key('onboarding.skip')), findsNothing);
      expect(find.byKey(const Key('onboarding.step_label')), findsNothing);

      await toFirstHostSlide(tester);
      expect(find.text('OPTIONAL STEP'), findsOneWidget);
      expect(find.byKey(const Key('onboarding.skip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding.skip')));
      await tester.pumpAndSettle();
      expect(find.text("You're all set!"), findsOneWidget);
      expect(find.byKey(const Key('onboarding.skip')), findsNothing);
    });

    testWidgets('required step: no Skip, Continue blocked until done',
        (tester) async {
      phoneWindow(tester);
      final deps = IntroDeps(
        slides: [
          OnboardingSlide(
            content: hostSlide('a', reportsDone: true),
            data: const {'id': 'a'},
            required: true,
            shellActions: true,
          ),
        ],
        store: InMemoryOnboardingProgressStore(),
      );
      await pumpPage(tester, deps);
      await toFirstHostSlide(tester);

      expect(find.text('REQUIRED STEP'), findsOneWidget);
      expect(find.byKey(const Key('onboarding.skip')), findsNothing);
      expect(find.byKey(const Key('onboarding.blocked')), findsOneWidget);
      final button = find.descendant(
        of: find.byKey(const Key('onboarding.continue')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(find.byKey(const Key('host.a.done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding.blocked')), findsNothing);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text("You're all set!"), findsOneWidget);
    });

    testWidgets('closing the app here costs nothing: relaunch resumes',
        (tester) async {
      phoneWindow(tester);
      final store = InMemoryOnboardingProgressStore();
      final slides = [
        OnboardingSlide(
            content: hostSlide('school'),
            data: const {'id': 'school'},
            title: 'Your school'),
        OnboardingSlide(
            content: hostSlide('grade'),
            data: const {'id': 'grade'},
            title: 'Your grade'),
      ];
      await pumpPage(tester, IntroDeps(slides: slides, store: store));
      await toFirstHostSlide(tester);
      await tester.tap(find.byKey(const Key('host.school.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('host.grade.type')));
      await tester.pumpAndSettle();
      expect(find.text('typed:Ridge'), findsOneWidget);
      expect(find.text('STEP 4 OF 5'), findsOneWidget);

      // Cold relaunch: a brand-new tree and provider scope, same store.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpPage(tester, IntroDeps(slides: slides, store: store));

      expect(find.text('slide grade'), findsOneWidget);
      expect(find.text('typed:Ridge'), findsOneWidget);
      expect(find.text('STEP 4 OF 5'), findsOneWidget);
      expect(find.byKey(const Key('onboarding.back')), findsOneWidget);
      // ...and the earlier steps are still ticked: a pass past the end
      // clears the record for the next first run.
      await tester.tap(find.byKey(const Key('host.grade.next')));
      await tester.pumpAndSettle();
      expect(find.text("You're all set!"), findsOneWidget);
      expect(store.record?.done, {'school', 'grade'});
    });

    testWidgets('no store given: base_sdk LocalStorage is the default store',
        (tester) async {
      phoneWindow(tester);
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      await pumpPage(tester, const IntroDeps(slides: []));
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hostRecord.onboardingRun'), isNotNull);
      expect(prefs.getString(LocalStorageOnboardingProgressStore.legacyKey),
          isNull);
      expect(LocalStorage.getOnboardingRun()?['roleStepVisible'], isTrue);
    });
  });

  group('46d — the tablet', () {
    testWidgets('the full rail moves into the start side', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final deps = IntroDeps(
        slides: [
          OnboardingSlide(
              content: hostSlide('school'),
              data: const {'id': 'school'},
              title: 'Your school'),
          OnboardingSlide(
              content: hostSlide('grade'),
              data: const {'id': 'grade'},
              title: 'Your grade'),
        ],
        store: InMemoryOnboardingProgressStore(),
      );
      await pumpPage(tester, deps, designSize: const Size(1280, 800));
      await toFirstHostSlide(tester);

      expect(find.byKey(const Key('onboarding.rail.full')), findsOneWidget);
      expect(find.byKey(const Key('onboarding.rail.compact')), findsNothing);
      expect(find.text('First run'), findsOneWidget);
      expect(find.text('STEP 3 OF 5'), findsOneWidget);
      expect(find.text('2 left'), findsOneWidget);
      // Every step named; the passed ones keep their outcome beside them.
      for (final title in [
        'Welcome',
        'Who is setting this up?',
        'Your school',
        'Your grade',
        "You're all set",
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('seen'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('OPTIONAL STEP'), findsOneWidget);
    });
  });
}
