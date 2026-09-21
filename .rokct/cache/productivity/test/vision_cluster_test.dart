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

// Design strip section 41 — the M2 vision cluster: chips 785 / 786 /
// 787 / 788 (the board), 789 / 790 / 791 (the drill), 792 / 793 / 794
// (personal mastery) and canonical 700.
//
// Presentation only, no generated code, like tasks_workspace_test.dart.
// The board is pumped inside a real PlaneHost so the plane fold is the
// mechanism's own answer to the window width, not a flag.
//
// What a later edit could quietly undo:
//   * the board DECLARES ALL: three pillar columns at three planes, and
//     stacked sections at one — the same components, nothing scaled;
//   * the KPI count is DERIVED by counting; no count read means no pill,
//     which is not the same as "0 KPIs";
//   * mastery progress is DERIVED from the todos table, and a goal whose
//     rows were not sent draws NO progress rather than "0 of 0";
//   * nothing writes: there is no compose or edit control on any surface.

import 'dart:convert';
import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/models/data/objective_data.dart';
import 'package:productivity_sdk/src/common/models/data/vision_data.dart';
import 'package:productivity_sdk/src/common/presentation/vision/mastery_goal_card.dart';
import 'package:productivity_sdk/src/common/presentation/vision/objective_detail_pane.dart';
import 'package:productivity_sdk/src/common/presentation/vision/plan_board.dart';

/// The design size matches the window so ScreenUtil scales by one.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: Size(width, 900),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

/// The board inside a real PlaneHost, declaring ALL, exactly as the
/// installed page hosts it — so the span the board sees is what the
/// mechanism grants at that width.
Widget _hosted(Widget board, {List<PlanePage> deeper = const <PlanePage>[]}) {
  return PlaneHost(
    stack: <PlanePage>[
      PlanePage(name: 'plan-board', span: PlaneSpan.all, builder: (_) => board),
      ...deeper,
    ],
  );
}

String _text(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

const Vision _vision = Vision(
  name: 'VIS-1',
  title: 'Vision 2028',
  description:
      "Limpopo's most trusted purified-water brand — a refill within reach of every household.",
);

const List<Pillar> _pillars = <Pillar>[
  Pillar(
    name: 'PIL-CUS',
    title: 'Customers',
    description: 'Customers who refill with us first.',
    vision: 'VIS-1',
  ),
  Pillar(
    name: 'PIL-OPS',
    title: 'Operations',
    description: 'Lean shops, zero wasted litres.',
    vision: 'VIS-1',
  ),
  Pillar(
    name: 'PIL-GRW',
    title: 'Growth',
    description: 'New shops and new lines of revenue.',
    vision: 'VIS-1',
  ),
];

const List<StrategicObjective> _objectives = <StrategicObjective>[
  StrategicObjective(
    name: 'OBJ-1',
    title: 'Launch refill loyalty cards',
    description: 'Stamped refills — the tenth one free — at all three shops.',
    pillar: 'PIL-CUS',
  ),
  StrategicObjective(
    name: 'OBJ-2',
    title: 'Halve delivery complaints',
    description: 'Route and driver fixes on the repeat problem areas.',
    pillar: 'PIL-CUS',
  ),
  StrategicObjective(
    name: 'OBJ-3',
    title: 'RO uptime above 95%',
    description: 'Preventive maintenance on schedule at all three shops.',
    pillar: 'PIL-OPS',
  ),
  StrategicObjective(
    name: 'OBJ-4',
    title: 'Digitise the maintenance log',
    description: 'Paper log retired; every service captured on the day.',
    pillar: 'PIL-OPS',
  ),
  StrategicObjective(
    name: 'OBJ-5',
    title: 'Open the Seshego shop',
    description: 'Site, fit-out and launch before December.',
    pillar: 'PIL-GRW',
  ),
  StrategicObjective(
    name: 'OBJ-6',
    title: 'Wholesale to 15 accounts',
    description: 'Spazas and schools on standing weekly orders.',
    pillar: 'PIL-GRW',
  ),
];

const List<Kpi> _kpis = <Kpi>[
  Kpi(
    name: 'KPI-1',
    title: 'Cards in circulation',
    strategicObjective: 'OBJ-1',
  ),
  Kpi(
    name: 'KPI-2',
    title: 'Tenth-refill redemptions',
    strategicObjective: 'OBJ-1',
  ),
  Kpi(
    name: 'KPI-3',
    title: 'Complaints per 100 deliveries',
    strategicObjective: 'OBJ-2',
  ),
  Kpi(
    name: 'KPI-4',
    title: 'Uptime hours logged',
    description:
        'Weekly logged RO running hours against open hours — target 95% by December.',
    strategicObjective: 'OBJ-3',
  ),
  Kpi(
    name: 'KPI-5',
    title: 'Services on schedule',
    description:
        'Preventive services completed within 7 days of falling due — target every service.',
    strategicObjective: 'OBJ-3',
  ),
  Kpi(
    name: 'KPI-6',
    title: 'Services captured same day',
    strategicObjective: 'OBJ-4',
  ),
  Kpi(name: 'KPI-7', title: 'Shop open', strategicObjective: 'OBJ-5'),
  Kpi(name: 'KPI-8', title: 'Launch on budget', strategicObjective: 'OBJ-5'),
  Kpi(name: 'KPI-9', title: 'Standing accounts', strategicObjective: 'OBJ-6'),
];

const PlanBoard _board = PlanBoard(
  vision: _vision,
  pillars: _pillars,
  objectives: _objectives,
  kpis: _kpis,
);

const MasteryGoal _numbers = MasteryGoal(
  name: 'PMG-1',
  title: 'Master the numbers',
  description: 'Read the monthly P&L without the accountant.',
  todos: <MasteryTodo>[
    MasteryTodo(
      description: 'Finish the bookkeeping short course',
      status: 'Closed',
    ),
    MasteryTodo(description: 'Build the shop P&L template', status: 'Closed'),
    MasteryTodo(description: 'Run the August close solo', status: 'Open'),
  ],
);

void main() {
  group('the models read the endpoints, never reshape them', () {
    test('every drawn field comes off the endpoint rows', () {
      final Vision vision = Vision.fromMap(const <String, dynamic>{
        'name': 'VIS-1',
        'title': 'Vision 2028',
        'description': '<div>Limpopo&#39;s most trusted brand.</div>',
      });
      expect(vision.title, 'Vision 2028');
      expect(
        vision.description,
        "Limpopo's most trusted brand.",
        reason: 'a Text Editor field is HTML and is drawn as one line',
      );

      final Kpi kpi = Kpi.fromMap(const <String, dynamic>{
        'name': 'KPI-1',
        'title': 'Uptime',
        'description': '<p>target 95%</p>',
        'strategic_objective': 'OBJ-3',
      });
      expect(kpi.strategicObjective, 'OBJ-3');
      expect(kpi.description, 'target 95%');
    });

    test('THE KPI COUNT IS DERIVED by counting, and unread is not zero', () {
      expect(_board.kpiCountFor('OBJ-3'), 2);
      expect(_board.kpiCountFor('OBJ-2'), 1);
      const PlanBoard unread = PlanBoard(
        vision: _vision,
        pillars: _pillars,
        objectives: _objectives,
        kpisRead: false,
      );
      expect(unread.kpiCountFor('OBJ-3'), isNull);
    });

    test('the count pill is worded as the frames draw it', () {
      expect(_board.countLabel(), '3 pillars · 6 objectives');
      expect(_board.countLabel(withObjectives: false), '3 pillars');
      expect(MasteryGoalList.countLabel(4), '4 goals');
      expect(MasteryGoalList.countLabel(1), '1 goal');
    });

    test('the pillar accent is positional, agreeing with the 44c picker', () {
      expect(_board.accentIndexOf('PIL-OPS'), 1);
      expect(_board.accentIndexOf('missing'), 0);
    });

    test('MASTERY PROGRESS IS DERIVED from the todos table', () {
      expect(_numbers.todosDone, 2);
      expect(_numbers.todosTotal, 3);
      expect(_numbers.progress, closeTo(2 / 3, 1e-9));
      expect(_numbers.isComplete, isFalse);
    });

    test('a goal whose rows were not sent has NO progress, not 0 of 0', () {
      final MasteryGoal goal = MasteryGoal.fromMap(const <String, dynamic>{
        'name': 'PMG-9',
        'title': 'Pitch without notes',
      });
      expect(goal.todos, isNull);
      expect(goal.hasTodos, isFalse);
      expect(goal.progress, isNull);
    });

    test('todo rows are read when the row carries them', () {
      final MasteryGoal goal = MasteryGoal.fromMap(const <String, dynamic>{
        'name': 'PMG-2',
        'title': 'Coach',
        'todos': <Map<String, dynamic>>[
          {'description': 'Block the slots', 'status': 'Closed'},
          {
            'description': 'Run four weeks',
            'status': 'Open',
            'date': '2026-09-26',
          },
        ],
      });
      expect(goal.todos, hasLength(2));
      expect(goal.todos![0].isClosed, isTrue);
      expect(goal.todos![1].date, DateTime(2026, 9, 26));
      expect(goal.todosDone, 1);
    });

    test('the column count follows the granted span', () {
      expect(PlanBoardView.columnsFor(span: 3, pillarCount: 3), 3);
      expect(
        PlanBoardView.columnsFor(span: 2, pillarCount: 3),
        3,
        reason: '41b: same three columns, tighter dress',
      );
      expect(
        PlanBoardView.columnsFor(span: 1, pillarCount: 3),
        1,
        reason: '41d: stacked sections',
      );
      expect(PlanBoardView.columnsFor(span: 3, pillarCount: 5), 3);
      expect(PlanBoardView.columnsFor(span: 3, pillarCount: 0), 1);
    });
  });

  group('frame 41a - the plan board declares all', () {
    testWidgets('three pillar columns on three planes, masthead across', (
      tester,
    ) async {
      await _pump(tester, _hosted(const PlanBoardView(board: _board)));
      expect(find.byKey(PlanBoardView.layoutKey(3)), findsOneWidget);
      expect(find.byType(PillarColumn), findsNWidgets(3));
      expect(find.byType(VisionMasthead), findsOneWidget);
      final String text = _text(tester);
      expect(text, contains('Vision 2028'));
      expect(text, contains('Vision'));
      expect(text, contains('Customers'));
      expect(text, contains('Operations'));
      expect(text, contains('Growth'));
      for (final StrategicObjective o in _objectives) {
        expect(find.text(o.title), findsOneWidget);
      }
    });

    testWidgets('the objective card carries the derived KPI pill', (
      tester,
    ) async {
      await _pump(tester, _hosted(const PlanBoardView(board: _board)));
      expect(find.text('2 KPIs'), findsNWidgets(3));
      expect(find.text('1 KPI'), findsNWidgets(3));
    });

    testWidgets('an unread KPI count draws no pill', (tester) async {
      await _pump(
        tester,
        _hosted(
          const PlanBoardView(
            board: PlanBoard(
              vision: _vision,
              pillars: _pillars,
              objectives: _objectives,
              kpisRead: false,
            ),
          ),
        ),
      );
      expect(find.textContaining('KPI'), findsNothing);
    });

    testWidgets('the header carries the count pill (canonical 700)', (
      tester,
    ) async {
      await _pump(
        tester,
        PlanHeader(title: 'Plan on a page', count: _board.countLabel()),
      );
      expect(find.text('Plan on a page'), findsOneWidget);
      expect(find.text('3 pillars · 6 objectives'), findsOneWidget);
    });

    testWidgets('VIEW-FIRST: no compose or edit chrome anywhere', (
      tester,
    ) async {
      await _pump(tester, _hosted(const PlanBoardView(board: _board)));
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('an empty plan says so', (tester) async {
      await _pump(tester, _hosted(const PlanBoardView(board: PlanBoard.empty)));
      expect(find.text(PlanBoardView.emptyLabel), findsOneWidget);
      expect(find.byType(PillarColumn), findsNothing);
    });

    testWidgets('a vision with no pillars keeps the masthead', (tester) async {
      await _pump(
        tester,
        _hosted(const PlanBoardView(board: PlanBoard(vision: _vision))),
      );
      expect(find.byType(VisionMasthead), findsOneWidget);
      expect(find.text(PlanBoardView.noPillarsLabel), findsOneWidget);
    });

    testWidgets('the state view: spinner, then the backend\'s own words', (
      tester,
    ) async {
      await _pump(
        tester,
        const PlanStateView(loading: true, child: SizedBox.shrink()),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      var retried = false;
      await _pump(
        tester,
        PlanStateView(
          loading: false,
          error: 'Not permitted',
          onRetry: () => retried = true,
          child: const SizedBox.shrink(),
        ),
      );
      expect(find.text('Not permitted'), findsOneWidget);
      await tester.tap(find.byKey(PlanStateView.retryKey));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('frame 41d - the phone fold', () {
    testWidgets('one plane: the pillar columns become stacked sections', (
      tester,
    ) async {
      await _pump(
        tester,
        _hosted(const PlanBoardView(board: _board)),
        width: 390,
      );
      expect(find.byKey(PlanBoardView.layoutKey(1)), findsOneWidget);
      expect(find.byKey(PlanBoardView.layoutKey(3)), findsNothing);
      // The same components at one plane, nothing lost but the spread.
      expect(find.byType(PillarColumn), findsNWidgets(3));
      expect(find.byType(VisionMasthead), findsOneWidget);
      expect(find.text('Launch refill loyalty cards'), findsOneWidget);
    });
  });

  group('frame 41b - the drill', () {
    testWidgets('tapping a card reports the objective', (tester) async {
      StrategicObjective? picked;
      await _pump(
        tester,
        _hosted(PlanBoardView(board: _board, onSelect: (o) => picked = o)),
      );
      await tester.tap(find.byKey(PlanObjectiveCard.cardKey('OBJ-3')));
      await tester.pump();
      expect(picked?.name, 'OBJ-3');
    });

    testWidgets('788: the tapped card is lit primary and tagged Selected', (
      tester,
    ) async {
      await _pump(
        tester,
        _hosted(const PlanBoardView(board: _board, selectedObjective: 'OBJ-3')),
      );
      expect(find.text(PlanObjectiveCard.selectedLabel), findsOneWidget);
      final Container container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(PlanObjectiveCard.cardKey('OBJ-3')),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect((decoration.border as Border).top.color, AppStyle.primary);
    });

    testWidgets(
      'the detail takes the LAST plane and the board compresses onto two',
      (tester) async {
        await _pump(
          tester,
          _hosted(
            const PlanBoardView(board: _board, selectedObjective: 'OBJ-3'),
            deeper: <PlanePage>[
              PlanePage(
                name: 'objective-OBJ-3',
                builder: (_) => const ObjectiveDetailPane(
                  board: _board,
                  objective: StrategicObjective(
                    name: 'OBJ-3',
                    title: 'RO uptime above 95%',
                    pillar: 'PIL-OPS',
                  ),
                ),
              ),
            ],
          ),
        );
        // Same three columns, on the two planes the board kept.
        expect(find.byKey(PlanBoardView.layoutKey(3)), findsOneWidget);
        expect(find.byType(ObjectiveDetailPane), findsOneWidget);
        final Planes planes = tester.widget<Planes>(
          find
              .ancestor(
                of: find.byType(PlanBoardView),
                matching: find.byType(Planes),
              )
              .first,
        );
        expect(planes.count, 3);
        expect(planes.span, 2);
      },
    );

    testWidgets('789 / 790 / 791: breadcrumb, title, and the honest KPI set', (
      tester,
    ) async {
      await _pump(
        tester,
        ObjectiveDetailPane(board: _board, objective: _objectives[2]),
      );
      final String text = _text(tester);
      expect(text, contains('Vision 2028'));
      expect(text, contains('Operations'));
      expect(text, contains('RO uptime above 95%'));
      expect(text, contains(ObjectiveDetailPane.kpisLabel));
      expect(find.byType(KpiCard), findsNWidgets(2));
      expect(text, contains('Uptime hours logged'));
      expect(text, contains('target 95% by December'));
      // No gauge to draw: the KPI doctype has no metric / target / current.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // No edit verb on the pane.
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('an objective with no KPIs says so', (tester) async {
      await _pump(
        tester,
        const ObjectiveDetailPane(
          board: PlanBoard(vision: _vision, pillars: _pillars),
          objective: StrategicObjective(
            name: 'OBJ-X',
            title: 'x',
            pillar: 'PIL-OPS',
          ),
        ),
      );
      expect(find.text(ObjectiveDetailPane.noKpisLabel), findsOneWidget);
    });
  });

  group('frame 41c - personal mastery', () {
    testWidgets('794: the two shipped schedulers as page facts', (
      tester,
    ) async {
      await _pump(tester, const WeeklyCheckInStrip());
      final String text = _text(tester);
      expect(text, contains(WeeklyCheckInStrip.mondayLabel));
      expect(text, contains(WeeklyCheckInStrip.mondayFact));
      expect(text, contains(WeeklyCheckInStrip.fridayLabel));
      expect(text, contains(WeeklyCheckInStrip.fridayFact));
    });

    testWidgets('792: the derived progress reads N of M over a thin bar', (
      tester,
    ) async {
      await _pump(tester, const MasteryGoalCard(goal: _numbers));
      expect(find.text('2 of 3'), findsOneWidget);
      final LinearProgressIndicator bar = tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
      expect(bar.value, closeTo(2 / 3, 1e-9));
      expect(find.byType(TodoCheckLine), findsNWidgets(3));
    });

    testWidgets('a complete goal goes green', (tester) async {
      const MasteryGoal done = MasteryGoal(
        name: 'PMG-4',
        title: 'Conversational Sepedi',
        todos: <MasteryTodo>[
          MasteryTodo(description: 'Finish the audio course', status: 'Closed'),
          MasteryTodo(
            description: 'One full counter shift in Sepedi',
            status: 'Closed',
          ),
        ],
      );
      await _pump(tester, const MasteryGoalCard(goal: done));
      expect(find.text('2 of 2'), findsOneWidget);
      final LinearProgressIndicator bar = tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
      expect(
        (bar.valueColor as AlwaysStoppedAnimation<Color>).value,
        AppStyle.green,
      );
    });

    testWidgets('a goal with no rows sent draws no progress at all', (
      tester,
    ) async {
      await _pump(
        tester,
        const MasteryGoalCard(
          goal: MasteryGoal(name: 'PMG-9', title: 'Pitch without notes'),
        ),
      );
      expect(find.text('Pitch without notes'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining(' of '), findsNothing);
    });

    testWidgets('793: a closed row is dim with a check, an open one hollow', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: const <Widget>[
            TodoCheckLine(
              todo: MasteryTodo(description: 'Closed one', status: 'Closed'),
            ),
            TodoCheckLine(
              todo: MasteryTodo(
                description: 'Open one',
                status: 'Open',
                date: null,
              ),
            ),
          ],
        ),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      final Text closed = tester.widget<Text>(find.text('Closed one'));
      final Text open = tester.widget<Text>(find.text('Open one'));
      expect(closed.style?.color, AppStyle.textDarkFaint);
      expect(open.style?.color, AppStyle.textDarkSecondary);
    });

    testWidgets('the due date sits faint at the end', (tester) async {
      await _pump(
        tester,
        TodoCheckLine(
          todo: MasteryTodo(
            description: 'Run the August close solo',
            date: DateTime(2026, 9, 5),
          ),
        ),
      );
      expect(find.text('5 Sep'), findsOneWidget);
    });

    testWidgets('no status tabs: the goal has no status field', (tester) async {
      await _pump(
        tester,
        PlaneHost(
          stack: <PlanePage>[
            PlanePage(
              name: 'mastery-list',
              span: PlaneSpan.two,
              builder: (_) =>
                  const MasteryGoalList(goals: <MasteryGoal>[_numbers]),
            ),
          ],
        ),
      );
      expect(find.text('All'), findsNothing);
      expect(find.text('Pending'), findsNothing);
      expect(find.text('Completed'), findsNothing);
      expect(find.byType(MasteryGoalCard), findsOneWidget);
    });

    testWidgets('the list folds: two columns at the fold, one on the phone', (
      tester,
    ) async {
      Widget hosted() => PlaneHost(
        stack: <PlanePage>[
          PlanePage(
            name: 'mastery-list',
            span: PlaneSpan.two,
            builder: (_) => const MasteryGoalList(
              goals: <MasteryGoal>[_numbers, _numbers, _numbers],
            ),
          ),
        ],
      );
      await _pump(tester, hosted(), width: 673);
      expect(
        ListPlaneColumns.columnsOf(
          tester.element(find.byType(MasteryGoalList)),
        ),
        2,
      );
      expect(find.byType(MasteryGoalCard), findsNWidgets(3));

      await _pump(tester, hosted(), width: 390);
      expect(
        ListPlaneColumns.columnsOf(
          tester.element(find.byType(MasteryGoalList)),
        ),
        1,
      );
      expect(find.byType(MasteryGoalCard), findsNWidgets(3));
    });

    testWidgets('an empty list says so', (tester) async {
      await _pump(tester, const MasteryGoalList(goals: <MasteryGoal>[]));
      expect(find.text(MasteryGoalList.emptyLabel), findsOneWidget);
      expect(find.byType(MasteryGoalCard), findsNothing);
    });
  });

  group('the manifest wires the two pages', () {
    test(
      'declares /vision and /vision/mastery against installed templates',
      () {
        final Map<String, dynamic> manifest =
            jsonDecode(File('manifest.json').readAsStringSync())
                as Map<String, dynamic>;
        final List<Map<String, dynamic>> routes = (manifest['routes'] as List)
            .cast<Map<String, dynamic>>();
        final Map<String, Map<String, dynamic>> byPath =
            <String, Map<String, dynamic>>{
              for (final Map<String, dynamic> r in routes)
                r['path'] as String: r,
            };
        expect(
          byPath.keys,
          containsAll(<String>['/vision', '/vision/mastery']),
        );
        expect(byPath['/vision']!['page'], 'PlanOnAPageRoute.page');
        expect(byPath['/vision/mastery']!['page'], 'PersonalMasteryRoute.page');
        for (final String path in <String>['/vision', '/vision/mastery']) {
          final String import = byPath[path]!['import'] as String;
          final String template = import
              .replaceFirst('package:\${package}/', '')
              .replaceFirst(
                'presentation/pages/vision/',
                'templates/pages/vision/',
              );
          expect(
            File(template).existsSync(),
            isTrue,
            reason: '$path -> $template',
          );
        }
      },
    );
  });
}
