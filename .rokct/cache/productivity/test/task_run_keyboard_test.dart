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

// Tour run 34040758271, still 11 (productivity_maintenance_readings): on
// the phone, with the numeric keyboard raised, the readings step's amber
// block ("Out of spec … Re-test, or record why") and its actions scrolled
// off under the keyboard, so the user could not see why Continue was
// locked. The run seeded here is the tour's own — the softener template,
// nine stages done, the readings 175 / 212 / 8.4 / 1.9 with the permeate
// TDS out of spec — hosted the way both hosts host it: a resizing
// Scaffold, so the body ends where the keyboard begins.
//
// What a later edit could quietly undo:
//   * the pin is read from FOCUS. A resizing Scaffold strips the bottom
//     view inset from its body, so `MediaQuery.viewInsetsOf` reads 0 in
//     here while the keyboard is up.
//   * nothing is removed: the actions row exists exactly once at every
//     moment — in the card, or pinned — and returns to the card the
//     moment focus leaves. Finish "stays present and locked, never
//     hidden" (47h).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/run/maintenance_templates.dart';
import 'package:productivity_sdk/src/common/application/run/task_run.dart';
import 'package:productivity_sdk/src/common/presentation/run/task_run_view.dart';

const double _keyboard = 300;
final DateTime _clock = DateTime(2026, 9, 5, 15, 20);

class _Host extends StatefulWidget {
  const _Host({required this.task});

  final Map<String, dynamic> task;

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
      now: () => _clock,
    );
  }
}

/// The tour's run: the softener service with its nine stages done, opened
/// at the readings step.
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

/// A resizing Scaffold under a keyboard-sized inset: the body is
/// [size.height] - [_keyboard] tall, exactly as on the device.
Future<void> _pump(WidgetTester tester, Size size,
    {bool keyboard = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: size,
      builder: (BuildContext context, _) => MaterialApp(
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: EdgeInsets.only(bottom: keyboard ? _keyboard : 0),
            ),
            child: Scaffold(body: _Host(task: _softenerAtReadings())),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(TaskRunView.resumeKey));
  await tester.pump();
}

/// The tour's readings, typed in the tour's order; the last one leaves
/// the focus on the permeate pressure field.
Future<void> _typeReadings(WidgetTester tester) async {
  const List<String> readings = <String>['175', '212', '8.4', '1.9'];
  for (int i = 0; i < readings.length; i++) {
    await tester.enterText(find.byKey(TaskRunView.readingKey(i)), readings[i]);
    await tester.pumpAndSettle();
  }
}

void _expectAbove(
    WidgetTester tester, Finder finder, double edge, String what) {
  expect(finder, findsOneWidget, reason: what);
  final Rect rect = tester.getRect(finder);
  expect(rect.bottom, lessThanOrEqualTo(edge),
      reason: '$what is under the keyboard');
  expect(rect.top, greaterThanOrEqualTo(0),
      reason: '$what is above the screen');
}

void main() {
  for (final (String name, Size size) in <(String, Size)>[
    ('phone 390x844', const Size(390, 844)),
    ('tablet 1280x800', const Size(1280, 800)),
  ]) {
    final double visible = size.height - _keyboard;

    group(name, () {
      testWidgets('the amber block and the actions stay above the keyboard', (
        WidgetTester tester,
      ) async {
        await _pump(tester, size);
        await _typeReadings(tester);

        expect(find.text('Out of spec'), findsOneWidget);
        expect(
          find.text('TDS — permeate 212 ppm is outside ≤ 50 ppm'),
          findsOneWidget,
        );
        _expectAbove(
          tester,
          find.text('Re-test, or record why it is out of spec, to continue.'),
          visible,
          'the route out (858)',
        );
        _expectAbove(
            tester, find.byKey(TaskRunView.continueKey), visible, 'Continue');
        _expectAbove(tester, find.byKey(TaskRunView.backKey), visible, 'Back');
        expect(
          tester
              .widget<ElevatedButton>(find.byKey(TaskRunView.continueKey))
              .enabled,
          isFalse,
          reason: 'locked until re-tested or explained',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'the field being typed in stays in view above the pinned foot', (
        WidgetTester tester,
      ) async {
        await _pump(tester, size);
        await _typeReadings(tester);

        final Finder foot = find.byKey(TaskRunView.pinnedFooterKey);
        expect(foot, findsOneWidget);
        double footTop() => tester.getTopLeft(foot).dy;
        expect(footTop(), lessThanOrEqualTo(visible));
        _expectAbove(tester, find.byKey(TaskRunView.readingKey(3)), footTop(),
            'the focused field');

        // Back to the first reading: it is pulled down into view the same way.
        await tester.enterText(find.byKey(TaskRunView.readingKey(0)), '180');
        await tester.pumpAndSettle();
        _expectAbove(tester, find.byKey(TaskRunView.readingKey(0)), footTop(),
            'the first field');

        // And the note that unlocks Continue is typed in with the lock in
        // sight. Once it is written the amber block leaves the foot (the
        // gate is open), so the foot's edge is read again.
        await tester.enterText(
            find.byKey(TaskRunView.noteKey), 'Resin bed exhausted');
        await tester.pumpAndSettle();
        _expectAbove(
            tester, find.byKey(TaskRunView.noteKey), footTop(), 'the note');
        _expectAbove(
            tester, find.byKey(TaskRunView.continueKey), visible, 'Continue');
        expect(
          tester
              .widget<ElevatedButton>(find.byKey(TaskRunView.continueKey))
              .enabled,
          isTrue,
          reason: 'the note opens it',
        );
      });

      testWidgets(
          'nothing is removed, and the foot returns to the card when focus leaves',
          (
        WidgetTester tester,
      ) async {
        await _pump(tester, size);
        await _typeReadings(tester);
        expect(find.byKey(TaskRunView.pinnedFooterKey), findsOneWidget);
        expect(find.byKey(TaskRunView.continueKey), findsOneWidget);
        expect(find.byKey(TaskRunView.backKey), findsOneWidget);
        expect(find.text('Out of spec'), findsOneWidget);

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.byKey(TaskRunView.pinnedFooterKey), findsNothing);
        expect(find.byKey(TaskRunView.continueKey), findsOneWidget);
        expect(find.byKey(TaskRunView.backKey), findsOneWidget);
        expect(find.text('Out of spec'), findsOneWidget);
        // The values typed are still on the map.
        final _HostState host = tester.state<_HostState>(find.byType(_Host));
        final TaskRunStep step = TaskRun.fromTask(host.task).steps[9];
        expect(step.readings.map((ReadingSpec r) => r.value),
            <String>['175', '212', '8.4', '1.9']);
      });

      testWidgets('with no field focused the layout is the card as it was', (
        WidgetTester tester,
      ) async {
        await _pump(tester, size, keyboard: false);
        expect(find.byKey(TaskRunView.pinnedFooterKey), findsNothing);
        expect(find.byKey(TaskRunView.continueKey), findsOneWidget);
        expect(find.text('Reading missing'), findsOneWidget);
      });
    });
  }
}
