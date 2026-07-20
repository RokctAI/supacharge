// Host composition file (ADR-005 + decision #22's correction, 2026-07-20).
//
// onboarding_sdk owns only the generic onboarding shell (carousel
// sequencing, progress indicator, role choice) and exposes an
// `OnboardingSlide` extension point. EVERYTHING Supacharge-specific about
// onboarding lives here, in host composition code:
//
//   * the grade step's UI (`_GradeSlide`),
//   * the narrow `StudentGradeCapture` interface it persists through,
//   * the `LmsGradeCaptureAdapter` wrapping lms_sdk's `LmsRepository`.
//
// The persistence path is unchanged from how it was originally built —
// narrow interface + host adapter over lms_sdk's existing `setGrade()`,
// never duplicating that logic. What changed is only WHERE the step's UI
// and its interface live: they moved out of the shared SDK so
// onboarding_sdk never learns a domain concept (the coupling that made
// BetAssist bypass this SDK and build its own flow instead).
//
// The cross-SDK imports below are legitimate: this file is host
// composition code, not inside either SDK's `lib/` (sdk_validator.py scans
// `lib/` only).

import 'package:base_sdk/src/presentation/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lms_sdk/lms_sdk.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';

/// Consumer-owned interface for the one thing Supacharge's onboarding grade
/// step needs: persisting the chosen grade. The real grade-capture logic
/// (validation, backend write, local cache refresh) already lives in
/// lms_sdk's `LmsRepository.setGrade()` — this exists so the slide widget
/// depends on a narrow contract rather than the whole repository, and so a
/// test can substitute it.
///
/// Implementations should not throw for expected failures (e.g. offline):
/// onboarding always continues past this step regardless of outcome, so a
/// backend hiccup never blocks account creation.
abstract class StudentGradeCapture {
  Future<void> submitGrade(int grade);
}

/// Wraps lms_sdk's `LmsRepository.setGrade()` behind [StudentGradeCapture]
/// — the same adapter that backed the original hardcoded step, unchanged.
class LmsGradeCaptureAdapter implements StudentGradeCapture {
  LmsRepository get _repository {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    return getIt.get<LmsRepository>();
  }

  @override
  Future<void> submitGrade(int grade) async {
    await _repository.setGrade(grade);
  }
}

/// Supacharge's grade step, injected into the generic flow as ONE
/// [OnboardingSlide]. onboarding_sdk renders this without knowing what it
/// is; the slide advances the flow itself via [OnboardingSlideScope].
class GradeSlide extends StatefulWidget {
  final StudentGradeCapture capture;

  const GradeSlide({super.key, required this.capture});

  static const _grades = [8, 9, 10, 11, 12];

  @override
  State<GradeSlide> createState() => _GradeSlideState();
}

class _GradeSlideState extends State<GradeSlide> {
  bool _submitting = false;

  Future<void> _submit(int grade) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Capture the scope before the await — using context across an async
    // gap is only safe via a value read beforehand.
    final scope = OnboardingSlideScope.of(context);
    try {
      await widget.capture.submitGrade(grade);
    } catch (e) {
      // Onboarding proceeds regardless: a failed write must never trap a
      // new student in the flow. The student profile page offers the same
      // grade field later, so this is recoverable, not lost.
      debugPrint('==> GradeSlide: grade submit failed: $e');
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    scope.next();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What grade are you in?',
          textAlign: TextAlign.center,
          style: AppStyle.interBold(size: 26, color: AppStyle.white),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final g in GradeSlide._grades)
              ChoiceChip(
                label: Text('Grade $g'),
                selected: false,
                onSelected: _submitting ? null : (_) => _submit(g),
              ),
          ],
        ),
        if (_submitting) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

/// Host route shell for [IntroPage] (onboarding_sdk-resident page).
///
/// Stateful so [IntroDeps] — and the slide list inside it — is built ONCE:
/// it is the riverpod family key for the flow's notifier, so rebuilding it
/// per frame would reset onboarding mid-way.
class OnboardingIntroRouteView extends StatefulWidget {
  const OnboardingIntroRouteView({super.key});

  @override
  State<OnboardingIntroRouteView> createState() =>
      _OnboardingIntroRouteViewState();
}

class _OnboardingIntroRouteViewState extends State<OnboardingIntroRouteView> {
  late final IntroDeps _deps = IntroDeps(
    slides: [
      OnboardingSlide(
        data: const {'id': 'supacharge.grade'},
        // Students only — a parent setting the account up for their child
        // is not the one with a grade (same branch the old hardcoded
        // step applied).
        roles: const {OnboardingRole.student},
        content: GradeSlide(capture: LmsGradeCaptureAdapter()),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => IntroPage(deps: _deps);
}
