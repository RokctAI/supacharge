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

import 'package:auto_route/auto_route.dart';
import 'package:base_sdk/src/presentation/theme/theme.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
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
    // Offline-first: persist to the shared KV the profile reads back, so the
    // grade captured here survives even when the backend is unavailable
    // (dev/demo). The backend write is best-effort on top.
    try {
      await AppDbScheduleStore()
          .put('lms_grade', 'value', {'grade': grade});
    } catch (_) {/* best-effort local cache */}
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
  int? _selected;

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
    // UI #1: match the login screen's visual language — a rounded sheet card
    // on the dark surface with a titled header, a form field, and one primary
    // full-width action button. Positioning (bottom-anchored, padded) is owned
    // by the onboarding scaffold, so this returns just the card — no Center /
    // SingleChildScrollView of its own, which would fight the scaffold.
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppStyle.strokeDark, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
              Text(
                'What grade are you in?',
                textAlign: TextAlign.center,
                style: AppStyle.interBold(size: 22, color: AppStyle.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick your grade so we can match you with the right tutors '
                'and lessons.',
                textAlign: TextAlign.center,
                style: AppStyle.interNormal(
                    size: 13, color: AppStyle.textDarkSecondary),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<int>(
                value: _selected,
                isExpanded: true,
                dropdownColor: AppStyle.cardDarkAlt,
                borderRadius: BorderRadius.circular(14),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppStyle.textDarkSecondary),
                hint: Text('Select your grade',
                    style: TextStyle(
                        fontSize: 15, color: AppStyle.textDarkSecondary)),
                style: TextStyle(fontSize: 15, color: AppStyle.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppStyle.cardDarkAlt,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppStyle.strokeDark, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppStyle.primary, width: 1.5),
                  ),
                ),
                items: [
                  for (final g in GradeSlide._grades)
                    DropdownMenuItem<int>(
                      value: g,
                      child: Text('Grade $g',
                          style: TextStyle(color: AppStyle.textPrimary)),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _selected = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppStyle.primary,
                    foregroundColor: AppStyle.blackColor,
                    disabledBackgroundColor: AppStyle.primary.withOpacity(0.35),
                    disabledForegroundColor:
                        AppStyle.blackColor.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_selected == null || _submitting)
                      ? null
                      : () => _submit(_selected!),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        );
  }
}

/// Host route shell for [IntroPage] (onboarding_sdk-resident page).
///
/// Stateful so [IntroDeps] — and the slide list inside it — is built ONCE:
/// it is the riverpod family key for the flow's notifier, so rebuilding it
/// per frame would reset onboarding mid-way.
// AppRoutes.replaceLoginRoute lands here — this IS the app's login/intro
// entry point. Named OnboardingRoute (not LoginRoute) since auth_sdk now
// registers its own real LoginRoute (-> LoginPage) in its manifest — this
// is Supacharge's deliberate product choice to use the onboarding carousel
// as the entry surface instead of auth_sdk's stock login/register form,
// not a stand-in for a missing one. Host-declared because this page lives
// outside any SDK's lib/ (ADR-005) — see HOST_ROUTES in
// .rokct/sdk_installer_base.py.
@RoutePage(name: 'OnboardingRoute')
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
    onComplete: _onComplete,
  );

  /// Where each role lands after onboarding. In demo (`--dart-define=
  /// IS_DEMO=true`) a parent/guardian is dropped straight onto the partner
  /// side of the app so the reporting experience can be previewed without a
  /// real partner account — there is no backend to source the account role
  /// from. Students, and every path in production, keep the normal home
  /// entry (the real account role drives partner-vs-student routing there).
  void _onComplete(BuildContext context, OnboardingRole role) {
    const isDemo = bool.fromEnvironment('IS_DEMO', defaultValue: false);
    if (isDemo && role == OnboardingRole.parent) {
      context.router.replaceNamed('/partner-dashboard');
      return;
    }
    AppHelpers.goHome(context);
  }

  @override
  Widget build(BuildContext context) => IntroPage(deps: _deps);
}
