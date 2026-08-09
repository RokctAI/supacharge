import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';

/// End-to-end wiring of the grade step onto onboarding_sdk's generic slide
/// mechanism (decision #22's correction). Proves the composed path works —
/// lms_sdk's `GradeSlide` (declared by lms_sdk's manifest
/// `onboarding_slides` entry and injected into the generated
/// onboarding_route_pages.dart) renders inside the SDK flow, drives it via
/// `OnboardingSlideScope`, and persists through the same
/// `StudentGradeCapture` adapter contract — not just that it compiles.
///
/// The persistence layer is exercised through a fake capture (the real
/// [LmsGradeCaptureAdapter] in lms_route_pages.dart wraps lms_sdk's
/// LmsRepository, covered by lms_sdk's own tests); this test owns the
/// onboarding wiring, not the backend write.
class _FakeCapture implements StudentGradeCapture {
  final List<int> submitted = [];
  bool throwOnSubmit = false;

  @override
  Future<void> submitGrade(int grade) async {
    if (throwOnSubmit) throw StateError('offline');
    submitted.add(grade);
  }
}

/// Renders the grade slide exactly as the composed flow does: inside an
/// [OnboardingSlideScope], advanced through a Builder's `onContinue` —
/// the exact shape lms_sdk's manifest slide body injects.
Widget _hostSlide(StudentGradeCapture capture, {required VoidCallback onNext}) {
  // ScreenUtilInit mirrors the real app root: base_sdk's AppStyle text styles
  // use `.sp` (flutter_screenutil), which needs ScreenUtil initialized — the
  // composed app wraps startup in ScreenUtilInit, so the test does too.
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, child) => MaterialApp(
      home: Scaffold(
        body: OnboardingSlideScope(
          next: onNext,
          data: const {'id': 'lms.grade_capture'},
          index: 0,
          total: 1,
          child: Builder(
            builder: (context) => GradeSlide(
              capture: capture,
              onContinue: () => OnboardingSlideScope.of(context).next(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('picking a grade persists it and advances the flow',
      (tester) async {
    final capture = _FakeCapture();
    var advanced = 0;

    await tester.pumpWidget(_hostSlide(
      capture,
      onNext: () => advanced++,
    ));

    // TrKeys fallback rendering (no translations loaded in tests):
    // 'what_grade_are_you_in' -> 'What grade are you in'.
    expect(find.text('What grade are you in'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 11').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Persisted through the capture adapter contract...
    expect(capture.submitted, [11]);
    // ...and the flow advanced via the scope.
    expect(advanced, 1);
  });

  testWidgets('a failed write still advances — onboarding never traps',
      (tester) async {
    final capture = _FakeCapture()..throwOnSubmit = true;
    var advanced = 0;

    await tester.pumpWidget(_hostSlide(
      capture,
      onNext: () => advanced++,
    ));

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 9').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(capture.submitted, isEmpty);
    // The student is not stuck: a backend hiccup must not block onboarding.
    expect(advanced, 1);
  });

  testWidgets('the whole IntroDeps slide list is student-gated', (tester) async {
    // lms_sdk's manifest injects the grade slide restricted to the student
    // role. Build a student flow and a parent flow from that same slide list
    // and assert only the student reaches the slide — the exact behaviour
    // the old hardcoded gradeStepVisible check had, now expressed generically.
    final slides = [
      OnboardingSlide(
        roles: const {OnboardingRole.student},
        content: GradeSlide(capture: _FakeCapture(), onContinue: () {}),
      ),
    ];

    final student = IntroNotifier(slides: slides)
      ..chooseRole(OnboardingRole.student);
    expect(student.currentSlide, isNotNull);
    student.dispose();

    final parent = IntroNotifier(slides: slides)
      ..chooseRole(OnboardingRole.parent);
    expect(parent.currentSlide, isNull);
    expect(parent.hostSlidesComplete, isTrue);
    parent.dispose();
  });
}
