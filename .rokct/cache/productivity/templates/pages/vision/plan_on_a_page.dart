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

// DESIGN STRIP SECTION 41 — the M2 vision cluster, frames 41a (plan on
// a page), 41b (the objective drill) and 41d (the phone fold), at
// `/vision`. Chips 785 / 786 / 787 / 788 / 789 / 790 / 791 and canonical
// 700 / 347.
//
// THE BOARD DECLARES ALL (the kitchen / 34a claim class): the whole
// strategy on one surface is the point of the page, so it fills every
// plane the screen has — vision masthead across the claim, one pillar
// per plane-aligned column, objectives as cards (41a). Tapping an
// objective pushes its detail with the DEFAULT one-plane claim: newest
// wins, the detail takes the LAST plane and the board compresses onto
// the leftover planes beside it — same columns, tighter dress (41b).
// At one plane the board falls back to stacked sections (41d) and the
// drill takes the whole screen; nothing is lost but the spread.
//
// THE CORNER PILL (canonical 347, the 12:36Z two-state nav) is drawn by
// this page at the bottom-END on every state, because /vision is a
// PUSHED page from the productivity gate (approved 7e) and the full nav
// is folded: it pops the NEWEST step — the drill while one is open, else
// the page itself.
//
// VIEW-FIRST (flag (a)): no compose or edit chrome. The backend is
// read-only `get_*` today; the legacy add/edit dialogs become write
// endpoints at build time. ONLY THE FIELDS THAT EXIST ARE DRAWN (flag
// (b)): title, description and the link chain — no dates, no status, no
// KPI gauges. The legacy 90-Days view (flag (c)) cannot be rendered
// honestly until Strategic Objective carries is_90_day_priority +
// status, and is not drawn.

import 'package:auto_route/auto_route.dart';
import 'package:base_sdk/base_sdk.dart';
// The base barrel does not re-export the theme tokens, and section 41
// is drawn in them explicitly (dark base tokens transcribed from
// app_style.dart) rather than in Theme.of(context).colorScheme.
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

@RoutePage(name: 'PlanOnAPageRoute')
class PlanOnAPagePage extends StatefulWidget {
  const PlanOnAPagePage({super.key});

  @override
  State<PlanOnAPagePage> createState() => _PlanOnAPagePageState();
}

class _PlanOnAPagePageState extends State<PlanOnAPagePage> {
  /// The plan, read once per page through the productivity module's own
  /// `get_plan_on_a_page` / `get_visions` / `get_pillars` /
  /// `get_strategic_objectives` / `get_kpis`. The page draws a spinner,
  /// then the board or the backend's own error.
  late final VisionRepositoryFacade _repository;

  PlanBoard? _board;
  bool _loading = true;
  String? _error;

  /// FRAME 41b — the objective whose detail holds the last plane, if any.
  String? _selected;

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
    final ApiResult<PlanBoard> result = await _repository.loadPlan();
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Success<PlanBoard>(:final data):
          _board = data;
        case Failure<PlanBoard>(:final error):
          _error = error;
      }
    });
  }

  /// Canonical 347 — back pops the NEWEST step: the drill while it is
  /// open, else this page.
  void _popPlane() {
    if (_selected != null) {
      setState(() => _selected = null);
      return;
    }
    context.router.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final PlanBoard? board = _board;
    final StrategicObjective? selected = board?.objectiveNamed(_selected);
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
              // The board DECLARES ALL.
              PlanePage(
                name: 'plan-board',
                span: PlaneSpan.all,
                builder: _boardPlane,
              ),
              // The drill: the default one-plane claim, the LAST plane.
              if (selected != null)
                PlanePage(
                  name: 'objective-${selected.name}',
                  builder: (BuildContext context) =>
                      _detailPlane(context, board!, selected),
                ),
            ],
          ),
          // Canonical 347 — the corner pill, bottom-END, 16 logical in
          // from both edges, inside the SafeArea: the same placement
          // PlaneHost gives its own pill while a flow is deeper than its
          // root, drawn here on every state because the page itself is
          // the pushed step. Content stops short of it (the 88px foot on
          // the board) so the pill owns the corner.
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingBackPill(
                back: FloatingNavBack(
                  icon: Icons.arrow_back,
                  label: AppHelpers.getTranslation(TrKeys.back),
                  onTap: _popPlane,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PLANES 1..N — the board: header + count pill (700), then the
  /// masthead (785), the pillar columns (786) and their cards (787).
  Widget _boardPlane(BuildContext context) {
    final PlanBoard? board = _board;
    // The count pill's words: "3 pillars · 6 objectives" on the board,
    // "3 pillars" on the phone fold (41d).
    final int span = Planes.maybeOf(context)?.span ?? 1;
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
                title: 'Plan on a page',
                count: board == null
                    ? null
                    : board.countLabel(withObjectives: span > 1),
              ),
              12.verticalSpace,
              Expanded(
                child: PlanStateView(
                  loading: _loading,
                  error: _error,
                  onRetry: _load,
                  child: PlanBoardView(
                    board: board ?? PlanBoard.empty,
                    selectedObjective: _selected,
                    onSelect: (StrategicObjective objective) =>
                        setState(() => _selected = objective.name),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// THE LAST PLANE — chip 789, the objective detail.
  Widget _detailPlane(
    BuildContext context,
    PlanBoard board,
    StrategicObjective objective,
  ) {
    return Scaffold(
      backgroundColor: AppStyle.transparent,
      body: SafeArea(
        child: ObjectiveDetailPane(
          key: ValueKey<String>('objective-detail-${objective.name}'),
          board: board,
          objective: objective,
        ),
      ),
    );
  }
}
