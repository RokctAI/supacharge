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

// DESIGN STRIP SECTION 41 — the M2 vision cluster, frame 41c (personal
// mastery at the fold), at `/vision/mastery`. Chips 792 / 793 / 794 and
// canonical 700 / 347.
//
// THE STANDARD LIST LANGUAGE (sec-33/38, Ray 12:23Z): header + count
// pill, the weekly check-in strip, then the goal cards flowing in
// plane-aligned columns. A section-38 list DECLARES TWO planes: at the
// fold it fills the screen exactly, at three planes the leftover plane
// trails bare at the end, on the phone it is the whole screen.
//
// PROGRESS IS DERIVED FROM THE CHILD TABLE. The goal has no status
// field, so there are no status tabs (362/363 considered — nothing to
// tab on, flag (b)) and the only progress metric on show is the real
// `todos` table. Flag (d) rides this frame: the Monday reminder's
// shipped query filters on a `status` field the doctype does not have —
// a backend bug to fix at build time, outside this SDK.
//
// THE CORNER PILL (canonical 347) is drawn by this page at the
// bottom-END, because /vision/mastery is a PUSHED page from the
// productivity gate (approved 7e) and the full nav is folded.
// VIEW-FIRST (flag (a)): no compose or edit chrome.

import 'package:auto_route/auto_route.dart';
import 'package:base_sdk/base_sdk.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

@RoutePage(name: 'PersonalMasteryRoute')
class PersonalMasteryPage extends StatefulWidget {
  const PersonalMasteryPage({super.key});

  @override
  State<PersonalMasteryPage> createState() => _PersonalMasteryPageState();
}

class _PersonalMasteryPageState extends State<PersonalMasteryPage> {
  /// The goals, read once per page through the productivity module's own
  /// `get_personal_mastery_goals`.
  late final VisionRepositoryFacade _repository;

  List<MasteryGoal>? _goals;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = const VisionRepositoryImpl();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ApiResult<List<MasteryGoal>> result = await _repository
        .loadMasteryGoals();
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Success<List<MasteryGoal>>(:final data):
          _goals = data;
        case Failure<List<MasteryGoal>>(:final error):
          _error = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // A BuildContext lookup for the mode, not the app-wide AppStyle.isDark
    // static (Ray, 2026-09-19: "glance doesnt change test immediately
    // untill you come back if you switched theme mode" — the same defect,
    // found in this page by the audit that followed).
    //
    // THE GROUND IS RESOLVED AGAINST THE INHERITED THEME. AppStyle's
    // mode-resolving statics carry the right value but are not an
    // inherited widget, so reading one registers no dependency — and this
    // page is a pushed ModalRoute, which caches the widget it built, so an
    // ancestor rebuild provably never reaches it either. The ground kept
    // the previous mode's colour until the reader left the page and came
    // back. Reading the theme here makes this element a dependent, so the
    // mode change itself repaints the page while it is on screen.
    final Brightness brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppStyle.surfaceFor(brightness),
      body: Stack(
        children: <Widget>[
          PlaneHost(
            stack: <PlanePage>[
              // A section-38 list declares TWO.
              PlanePage(
                name: 'mastery-list',
                span: PlaneSpan.two,
                builder: _listPlane,
              ),
            ],
          ),
          // Canonical 347 — the corner pill, bottom-END; the page is the
          // pushed step, so the pill pops it.
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingBackPill(
                back: FloatingNavBack(
                  icon: Icons.arrow_back,
                  label: AppHelpers.getTranslation(TrKeys.back),
                  onTap: () => context.router.maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PLANES 1–2 — the list: header + count pill (700), the weekly
  /// check-in strip (794), the goal cards (792) with their check lines
  /// (793).
  Widget _listPlane(BuildContext context) {
    final List<MasteryGoal>? goals = _goals;
    return Scaffold(
      backgroundColor: AppStyle.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              12.verticalSpace,
              PlanHeader(
                title: 'Personal mastery',
                count: goals == null
                    ? null
                    : MasteryGoalList.countLabel(goals.length),
              ),
              12.verticalSpace,
              // CHIP 794 — the two shipped schedulers as page facts, above
              // the first card on every width.
              const WeeklyCheckInStrip(),
              12.verticalSpace,
              Expanded(
                child: PlanStateView(
                  loading: _loading,
                  error: _error,
                  onRetry: _load,
                  child: MasteryGoalList(goals: goals ?? const <MasteryGoal>[]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
