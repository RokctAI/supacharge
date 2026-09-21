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

// Design strip frame 44a ("/tasks DECLARES 2 — HUB YIELDS TO 1"), 44c
// (the picker wins the last plane) and 47a ("46's mechanism, unchanged —
// no new plane"), pinned as the ALLOCATION the workspace's claims produce
// on a real PlaneHost at the two tablet widths the guided tour captures:
// 1066 logical (three planes) and 800 (two).
//
// The installed pages are templates: analysis excludes them and they
// import the composed app's comms_sdk, so they cannot be pumped here. What
// CAN be pinned is the thing they declare — `TasksPlaneClaims` — on the
// same stack shape `tasks_page.dart` builds (list, pane, picker), which is
// what the tablet audit of 2026-09-07 found wrong: the list stretched
// over two planes beside its pane, and the standalone run claimed two.

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/run/maintenance_templates.dart';
import 'package:productivity_sdk/src/common/application/run/task_run.dart';
import 'package:productivity_sdk/src/common/presentation/run/task_run_view.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/tasks_plane_claims.dart';

const double _gap = 14;
final DateTime _clock = DateTime(2026, 9, 7, 10, 30);

/// What a page subtree was granted, read the way the pages read it.
final Map<String, Planes> _granted = <String, Planes>{};

Widget _probe(String name) => Builder(
  builder: (BuildContext context) {
    _granted[name] = Planes.of(context);
    return Text(name);
  },
);

/// The workspace's stack as `tasks_page.dart` builds it: the list, then
/// the open pane (detail, compose or run), then the objective picker.
List<PlanePage> _stack({Widget? pane, bool picker = false}) => <PlanePage>[
  PlanePage(
    name: 'list',
    span: TasksPlaneClaims.list,
    builder: (_) => _probe('list'),
  ),
  if (pane != null)
    PlanePage(
      name: 'list-detail-x',
      span: TasksPlaneClaims.pane,
      builder: (_) => pane,
    ),
  if (pane != null && picker)
    PlanePage(
      name: 'objective-picker',
      span: TasksPlaneClaims.pane,
      builder: (_) => _probe('objective-picker'),
    ),
];

Future<void> _pump(
  WidgetTester tester,
  double width,
  List<PlanePage> stack,
) async {
  _granted.clear();
  final Size size = Size(width, 1600);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: size,
      builder: (BuildContext context, _) => MaterialApp(
        home: Scaffold(body: PlaneHost(stack: stack)),
      ),
    ),
  );
  await tester.pump();
}

/// The rectangle PlaneHost gave a page (its KeyedSubtree).
Rect _rect(WidgetTester tester, String name) =>
    tester.getRect(find.byKey(ValueKey<String>('plane-page-$name')));

/// One plane's width on a window of [width] showing [count] planes.
double _planeWidth(double width, int count) =>
    (width - (count - 1) * _gap) / count;

/// The tour's run: the softener service through its nine stages, at the
/// readings step — the task 47a is drawn with.
Map<String, dynamic> _softenerAtReadings() {
  final Map<String, dynamic> task = MaintenanceTemplates.build(
    MaintenanceTemplate.softenerMaintenance,
    now: _clock,
  );
  task['id'] = 'tour-softener-sft-02';
  task['title'] = 'Softener SFT-02 · Polokwane plant';
  TaskRun run = TaskRun.fromTask(task);
  DateTime at = _clock.subtract(const Duration(hours: 1, minutes: 5));
  for (int i = 0; i < 9; i++) {
    run = run.start(i, at);
    at = at.add(Duration(seconds: run.steps[i].durationSeconds));
    run = run.complete(i, at);
  }
  return run.applyTo(task);
}

Widget _runPane() => TaskRunView(
  task: _softenerAtReadings(),
  onChanged: (_) {},
  now: () => _clock,
);

void main() {
  group('the claims themselves', () {
    test('the list grows only into a spare plane; every pane claims one', () {
      expect(TasksPlaneClaims.list, PlaneSpan.twoIfSpare);
      expect(TasksPlaneClaims.pane, PlaneSpan.one);
      expect(TasksPlaneClaims.run, PlaneSpan.one);
    });

    test('beside a pane the list is ONE plane on any window', () {
      for (final int count in <int>[1, 2, 3]) {
        expect(TasksPlaneClaims.list.claimFor(count), 1);
        expect(TasksPlaneClaims.pane.claimFor(count), 1);
        expect(TasksPlaneClaims.run.claimFor(count), 1);
      }
      // ...and at rest it may take a second, never a third.
      expect(TasksPlaneClaims.list.growthCapFor(3), 2);
      expect(TasksPlaneClaims.list.growthCapFor(2), 2);
      expect(TasksPlaneClaims.list.growthCapFor(1), 1);
    });
  });

  group('frame 44a at 1066 logical — three planes', () {
    testWidgets('a detail open: list | detail | bare, each one plane wide', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 1066, _stack(pane: _probe('detail')));
      final double plane = _planeWidth(1066, 3);

      final Planes list = _granted['list']!;
      expect(list.count, 3);
      expect(list.index, 0);
      expect(list.span, 1, reason: '44a: the list is a single column');
      final Planes detail = _granted['detail']!;
      expect(detail.index, 1);
      expect(detail.span, 1);

      expect(_rect(tester, 'list').width, closeTo(plane, 0.5));
      expect(_rect(tester, 'list-detail-x').width, closeTo(plane, 0.5));
      // The plane 44a gives the hub is not this stage's to fill: it
      // trails bare at the END, the ruled place for a leftover.
      expect(
        _rect(tester, 'list-detail-x').right,
        closeTo(2 * plane + _gap, 0.5),
      );
    });

    testWidgets('44c — the picker wins the last plane; list + detail slide', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 1066, _stack(pane: _probe('detail'), picker: true));
      expect(_granted['list']!.index, 0);
      expect(_granted['list']!.span, 1);
      expect(_granted['detail']!.index, 1);
      expect(_granted['detail']!.span, 1);
      expect(_granted['objective-picker']!.index, 2);
      expect(_granted['objective-picker']!.span, 1);
      expect(_rect(tester, 'objective-picker').right, closeTo(1066, 0.5));
    });

    testWidgets('at rest the list grows into the spare plane, never a third', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 1066, _stack());
      final Planes list = _granted['list']!;
      expect(list.count, 3);
      expect(list.span, 2, reason: 'a growing claim takes the leftover');
      expect(
        _rect(tester, 'list').width,
        closeTo(2 * _planeWidth(1066, 3) + _gap, 0.5),
      );
    });

    testWidgets('47a — a run in the detail plane keeps the full step rail', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 1066, _stack(pane: _runPane()));
      await tester.tap(find.byKey(TaskRunView.resumeKey));
      await tester.pump();
      // One plane, list beside it — and the rail lists every stage (the
      // fold's compact rail names only the current one and the next).
      expect(
        _rect(tester, 'list-detail-x').width,
        closeTo(_planeWidth(1066, 3), 0.5),
      );
      expect(_granted['list']!.span, 1);
      expect(find.text('Initial Check'), findsOneWidget);
      expect(find.textContaining('Next: '), findsNothing);
    });
  });

  group('frame 44a at 800 logical — two planes, the hub off the stage', () {
    testWidgets('a detail open: list | detail, half each', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 800, _stack(pane: _probe('detail')));
      final double plane = _planeWidth(800, 2);
      expect(_granted['list']!.count, 2);
      expect(_granted['list']!.span, 1);
      expect(_granted['detail']!.index, 1);
      expect(_rect(tester, 'list').width, closeTo(plane, 0.5));
      expect(_rect(tester, 'list-detail-x').width, closeTo(plane, 0.5));
      expect(_rect(tester, 'list-detail-x').right, closeTo(800, 0.5));
    });

    testWidgets('at rest the list fills both planes, as it always did', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 800, _stack());
      expect(_granted['list']!.span, 2);
      expect(_rect(tester, 'list').width, closeTo(800, 0.5));
    });

    testWidgets('47a — the run pane keeps the full rail at two planes too', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 800, _stack(pane: _runPane()));
      await tester.tap(find.byKey(TaskRunView.resumeKey));
      await tester.pump();
      expect(find.text('Initial Check'), findsOneWidget);
    });
  });

  group('the fold and the standalone run', () {
    testWidgets('one plane: the pane is the whole screen, the rail folds', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 390, _stack(pane: _runPane()));
      await tester.tap(find.byKey(TaskRunView.resumeKey));
      await tester.pump();
      expect(
        _granted.containsKey('list'),
        isFalse,
        reason: 'the list slid off: the pane takes the one plane',
      );
      expect(_rect(tester, 'list-detail-x').width, closeTo(390, 0.5));
      // 46f / 47f — the compact rail, the fold's one phone-only element.
      expect(find.textContaining('Next: '), findsOneWidget);
      expect(find.text('Initial Check'), findsNothing);
    });

    testWidgets('the standalone run claims ONE plane on a three-plane window', (
      WidgetTester tester,
    ) async {
      await _pump(tester, 1066, <PlanePage>[
        PlanePage(
          name: 'task-run-x',
          span: TasksPlaneClaims.run,
          builder: (_) => _probe('run'),
        ),
      ]);
      expect(_granted['run']!.span, 1, reason: '47a: no new plane');
      expect(
        _rect(tester, 'task-run-x').width,
        closeTo(_planeWidth(1066, 3), 0.5),
      );
    });
  });
}
