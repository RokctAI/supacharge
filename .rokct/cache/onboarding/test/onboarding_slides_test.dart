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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';

/// The generic slide mechanism (decision #22's correction): onboarding_sdk
/// owns sequencing/progress/role choice and NOTHING app-specific. These
/// tests pin the extension point's contract — including that the SDK never
/// needs to know what a slide does — and that role branching still gates
/// conditional steps the way the old hardcoded student-branch check did.
void main() {
  Widget slide(String label) => Text(label);

  group('slide visibility', () {
    test('invisible slides never take part in the flow', () {
      final n = IntroNotifier(slides: [
        OnboardingSlide(content: slide('a')),
        OnboardingSlide(content: slide('b'), visible: false),
        OnboardingSlide(content: slide('c')),
      ]);
      expect(n.visibleSlides, hasLength(2));
      n.dispose();
    });

    test('a role-restricted slide applies only to that role', () {
      final graded = OnboardingSlide(
        content: slide('grade'),
        roles: const {OnboardingRole.student},
      );
      expect(graded.appliesTo(OnboardingRole.student), isTrue);
      expect(graded.appliesTo(OnboardingRole.parent), isFalse);
      // The temporary admin shortcut is "someone else" to every restricted
      // slide — it must never pick up a student capture step.
      expect(graded.appliesTo(OnboardingRole.admin), isFalse);
      // Before any role is chosen a restricted slide does not apply.
      expect(graded.appliesTo(null), isFalse);
    });

    test('an unrestricted slide applies to every role', () {
      final any = OnboardingSlide(content: slide('any'));
      expect(any.appliesTo(OnboardingRole.student), isTrue);
      expect(any.appliesTo(OnboardingRole.parent), isTrue);
      expect(any.appliesTo(null), isTrue);
    });

    test('visible:false beats a matching role', () {
      final off = OnboardingSlide(
        content: slide('off'),
        visible: false,
        roles: const {OnboardingRole.student},
      );
      expect(off.appliesTo(OnboardingRole.student), isFalse);
    });
  });

  group('flow sequencing', () {
    test('student sees the restricted slide; parent skips straight to done',
        () {
      // Exactly the behaviour the old hardcoded gradeStepVisible check had.
      final studentFlow = IntroNotifier(slides: [
        OnboardingSlide(
          content: slide('grade'),
          roles: const {OnboardingRole.student},
        ),
      ]);
      studentFlow.chooseRole(OnboardingRole.student);
      expect(studentFlow.currentSlide, isNotNull);
      expect(studentFlow.hostSlidesComplete, isFalse);
      studentFlow.dispose();

      final parentFlow = IntroNotifier(slides: [
        OnboardingSlide(
          content: slide('grade'),
          roles: const {OnboardingRole.student},
        ),
      ]);
      parentFlow.chooseRole(OnboardingRole.parent);
      expect(parentFlow.currentSlide, isNull);
      expect(parentFlow.hostSlidesComplete, isTrue);
      parentFlow.dispose();
    });

    test('slides advance in order, then the flow completes', () {
      final n = IntroNotifier(slides: [
        OnboardingSlide(content: slide('one'), data: const {'id': 'one'}),
        OnboardingSlide(content: slide('two'), data: const {'id': 'two'}),
      ]);
      n.chooseRole(OnboardingRole.student);

      expect(n.currentSlide?.data['id'], 'one');
      n.nextHostSlide();
      expect(n.currentSlide?.data['id'], 'two');
      n.nextHostSlide();
      expect(n.currentSlide, isNull);
      expect(n.hostSlidesComplete, isTrue);
      n.dispose();
    });

    test('advancing past the end is safe and does not run away', () {
      final n = IntroNotifier(slides: [OnboardingSlide(content: slide('one'))]);
      n.chooseRole(OnboardingRole.student);
      n.nextHostSlide();
      n.nextHostSlide();
      n.nextHostSlide();
      expect(n.state.hostSlideIndex, 1);
      expect(n.hostSlidesComplete, isTrue);
      n.dispose();
    });

    test('no host slides: the flow is complete as soon as a role is chosen',
        () {
      final n = IntroNotifier();
      n.chooseRole(OnboardingRole.parent);
      expect(n.currentSlide, isNull);
      expect(n.hostSlidesComplete, isTrue);
      n.dispose();
    });

    test('role choice is recorded and the carousel step is idempotent', () {
      final n = IntroNotifier();
      expect(n.state.role, isNull);
      n.showRoleStep();
      n.showRoleStep();
      expect(n.state.roleStepVisible, isTrue);
      n.chooseRole(OnboardingRole.student);
      expect(n.state.role, OnboardingRole.student);
      n.dispose();
    });
  });

  group('OnboardingSlideScope (how a host slide drives the flow)', () {
    testWidgets('a slide advances the flow through the scope, and reads data',
        (tester) async {
      var advanced = 0;
      const data = {'id': 'supacharge.grade'};

      await tester.pumpWidget(MaterialApp(
        home: OnboardingSlideScope(
          next: () => advanced++,
          data: data,
          index: 0,
          total: 1,
          child: Builder(builder: (context) {
            final scope = OnboardingSlideScope.of(context);
            return TextButton(
              onPressed: scope.next,
              child: Text('${scope.data['id']} ${scope.index}/${scope.total}'),
            );
          }),
        ),
      ));

      // The slide can read its own metadata and position...
      expect(find.text('supacharge.grade 0/1'), findsOneWidget);
      // ...and advance the flow without onboarding_sdk exposing its notifier.
      await tester.tap(find.byType(TextButton));
      expect(advanced, 1);
    });

    testWidgets('maybeOf returns null outside a flow', (tester) async {
      OnboardingSlideScope? seen;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          seen = OnboardingSlideScope.maybeOf(context);
          return const SizedBox.shrink();
        }),
      ));
      expect(seen, isNull);
    });
  });
}
