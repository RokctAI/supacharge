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

// Design strip frames 47h and 47i on the drawn runner: the readings step
// blocks on a value out of spec with the frame's words and Finish locked;
// the photo step's Skip is live beside a working Finish; the picked photo
// is a path handed back on the map. The host below is the smallest
// honest one — it holds the map the view hands back and hands it in
// again, exactly as the tasks page does.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/run/task_run.dart';
import 'package:productivity_sdk/src/common/presentation/run/task_run_view.dart';

final DateTime clock = DateTime(2026, 9, 5, 10, 0);

class _Host extends StatefulWidget {
  const _Host({required this.task, this.pickPhoto});

  final Map<String, dynamic> task;
  final Future<String?> Function(BuildContext context)? pickPhoto;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Map<String, dynamic> task = widget.task;

  @override
  Widget build(BuildContext context) {
    return TaskRunView(
      task: task,
      onChanged: (Map<String, dynamic> next) => setState(() => task = next),
      now: () => clock,
      pickPhoto: widget.pickPhoto,
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 1200),
      builder: (BuildContext context, _) =>
          MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

String _text(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .join(' | ');

Map<String, dynamic> _task(List<Map<String, dynamic>> steps) => <String, dynamic>{
  'id': 'task-1',
  'title': 'Softener Maintenance',
  'stepsAreSequential': true,
  'subtasks': steps,
};

Map<String, dynamic> _readings() => TaskRunStep(
  title: 'Readings',
  instruction: 'Take TDS and pressure before returning to service.',
  kind: StepKind.reading,
  readings: const <ReadingSpec>[
    ReadingSpec(label: 'TDS — permeate', unit: 'ppm', max: 50),
  ],
).toMap();

Map<String, dynamic> _photo() => const TaskRunStep(
  title: 'Photo & notes',
  instruction: 'Optional. Skipping does not hold up the run.',
  kind: StepKind.photo,
  optional: true,
).toMap();

bool _forwardEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(TaskRunView.continueKey)).enabled;

void main() {
  group('47h — the readings step', () {
    testWidgets('draws the reading with its spec, REQUIRED, and Finish locked', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Host(task: _task(<Map<String, dynamic>>[_readings()])));
      final String rendered = _text(tester);
      expect(rendered, contains('REQUIRED'));
      expect(rendered, contains('TDS — permeate'));
      expect(rendered, contains('≤ 50'));
      expect(rendered, contains('ppm'));
      expect(rendered, contains('Reading missing'));
      expect(find.byKey(TaskRunView.readingKey(0)), findsOneWidget);
      expect(find.byKey(TaskRunView.skipStepKey), findsNothing, reason: 'required');
      expect(_forwardEnabled(tester), isFalse);
    });

    testWidgets('a value out of spec blocks in the frame\'s words; a note opens it', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Host(task: _task(<Map<String, dynamic>>[_readings()])));
      await tester.enterText(find.byKey(TaskRunView.readingKey(0)), '212');
      await tester.pump();
      String rendered = _text(tester);
      expect(rendered, contains('Out of spec'));
      expect(rendered, contains('TDS — permeate 212 ppm is outside ≤ 50 ppm'));
      expect(rendered, contains('Re-test, or record why it is out of spec, to continue.'));
      expect(_forwardEnabled(tester), isFalse);
      expect(find.byKey(TaskRunView.noteKey), findsOneWidget, reason: 'the route out');

      await tester.enterText(
        find.byKey(TaskRunView.noteKey),
        'Re-tested twice; brine tank was low.',
      );
      await tester.pump();
      expect(_forwardEnabled(tester), isTrue);
      rendered = _text(tester);
      expect(rendered, isNot(contains('Out of spec')));
    });

    testWidgets('a value in spec unlocks Finish, and Finish finishes', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Host(task: _task(<Map<String, dynamic>>[_readings()])));
      await tester.enterText(find.byKey(TaskRunView.readingKey(0)), '40');
      await tester.pump();
      expect(_forwardEnabled(tester), isTrue);
      expect(_text(tester), contains('Finish run'));
      await tester.tap(find.byKey(TaskRunView.continueKey));
      await tester.pump();
      expect(_text(tester), contains('All 1 steps done'));
    });

    testWidgets('the typed value is on the map the host holds', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Host(task: _task(<Map<String, dynamic>>[_readings()])));
      await tester.enterText(find.byKey(TaskRunView.readingKey(0)), '175');
      await tester.pump();
      final _HostState host = tester.state<_HostState>(find.byType(_Host));
      final TaskRun run = TaskRun.fromTask(host.task);
      expect(run.steps[0].readings[0].value, '175');
      expect(run.isStarted, isFalse, reason: 'recording is not starting');
    });
  });

  group('47i — the photo step', () {
    testWidgets('OPTIONAL, with a live Skip beside a working Finish', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Host(task: _task(<Map<String, dynamic>>[_photo()])));
      final String rendered = _text(tester);
      expect(rendered, contains('OPTIONAL'));
      expect(rendered, contains('Add a photo'));
      expect(rendered, contains('Skipping does not hold up the run.'));
      expect(find.byKey(TaskRunView.skipStepKey), findsOneWidget);
      expect(find.byKey(TaskRunView.noteKey), findsOneWidget);
      expect(_forwardEnabled(tester), isTrue);
      expect(rendered, contains('Finish run'));
    });

    testWidgets('Skip completes the step as skipped and finishes the run', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Host(task: _task(<Map<String, dynamic>>[_photo()])));
      await tester.tap(find.byKey(TaskRunView.skipStepKey));
      await tester.pump();
      expect(_text(tester), contains('All 1 steps done'));
      final _HostState host = tester.state<_HostState>(find.byType(_Host));
      expect(TaskRun.fromTask(host.task).steps[0].skipped, isTrue);
    });

    testWidgets('a picked photo lands on the map as a path, and can be removed', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _Host(
          task: _task(<Map<String, dynamic>>[_photo()]),
          pickPhoto: (BuildContext context) async => '/storage/pictures/vessel-head.jpg',
        ),
      );
      await tester.tap(find.byKey(TaskRunView.photoKey));
      await tester.pump();
      expect(_text(tester), contains('vessel-head.jpg'));
      final _HostState host = tester.state<_HostState>(find.byType(_Host));
      expect(
        TaskRun.fromTask(host.task).steps[0].value,
        '/storage/pictures/vessel-head.jpg',
      );
      await tester.tap(find.byKey(TaskRunView.removePhotoKey));
      await tester.pump();
      expect(TaskRun.fromTask(host.task).steps[0].hasValue, isFalse);
      expect(find.byKey(TaskRunView.photoKey), findsOneWidget);
    });

    testWidgets('the rail says skipped beside a skipped step', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final Map<String, dynamic> task = _task(<Map<String, dynamic>>[
        _photo(),
        <String, dynamic>{'title': 'After', 'isDone': false, 'durationSeconds': 0},
      ]);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(1280, 900),
          builder: (BuildContext context, _) =>
              MaterialApp(home: Scaffold(body: _Host(task: task))),
        ),
      );
      await tester.pump();
      expect(_text(tester), contains('optional'));
      await tester.tap(find.byKey(TaskRunView.skipStepKey));
      await tester.pump();
      expect(_text(tester), contains('skipped'));
    });
  });
}
