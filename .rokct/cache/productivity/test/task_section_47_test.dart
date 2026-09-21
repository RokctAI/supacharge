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

// Design strip section 47, the visible half — pinned where it can be
// pinned without a store: the snooze arithmetic (47l), the sync-state
// derivation (47n), the two-clock row (47k) and the run badge (859) on
// the card.
//
// Like tasks_workspace_test.dart these import only the presentation and
// application layers, never the repository or the database, so the suite
// loads on a bare checkout.
//
// What a later edit could quietly undo:
//   * the snooze sheet returns a reminder time and NOTHING else — there
//     is no deadline in its result type to move;
//   * "synced" is earned from two facts (no outbox row, a remote id) and
//     never from a flag;
//   * the long-term band keys off `isLongTerm`, which is now DERIVED
//     from the end date rather than picked on the form — the rule and
//     its cut-off are pinned in test/long_term_rule_test.dart. The
//     card and the band still read the FIELD, and must keep doing so.

import 'package:base_sdk/base_sdk.dart' show OutboxStatus;
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/sync/task_sync_state.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_card.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_reminder_controls.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_view_model.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 900),
      builder: (context, _) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

String _text(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

const _seed = <String, dynamic>{
  'id': 'task-1',
  'title': 'Weekend job',
  'isDone': false,
  'deadline': '2026-09-06T18:00:00.000',
  'reminder': true,
  'priority': 'High',
  'createdAt': '2026-09-01T08:00:00.000',
  'subtasks': [
    {'title': 'One', 'isDone': true, 'completedAt': '2026-09-05T09:00:00.000'},
    {'title': 'Two', 'isDone': false, 'durationSeconds': 600},
    {'title': 'Three', 'isDone': false},
  ],
};

void main() {
  group('47l — the snooze options', () {
    final now = DateTime(2026, 9, 5, 16, 30); // a Saturday afternoon

    test('three fixed offsets, computed from now', () {
      final options = snoozeOptions(now);
      expect(options, hasLength(3));
      expect(options[0].remindAt, DateTime(2026, 9, 5, 17, 30));
      expect(options[1].remindAt, DateTime(2026, 9, 6, 7, 0));
      expect(options[2].remindAt, DateTime(2026, 9, 12, 7, 0));
    });

    test('tomorrow morning is the pre-selected one — the weekend case', () {
      expect(snoozeOptions(now)[kSnoozeDefaultOption].label, 'Tomorrow morning');
    });

    test('an option carries a reminder time and no deadline at all', () {
      // The invariant is structural: the type has no field for one.
      final option = snoozeOptions(now).first;
      expect(option.remindAt, isA<DateTime>());
      expect(option.toString(), isNot(contains('deadline')));
    });
  });

  group('47n — the sync-state derivation', () {
    test('no outbox row and no remote id: this device', () {
      expect(
        taskSyncStateFor(hasRemoteId: false, queued: null),
        TaskSyncState.thisDevice,
      );
    });

    test('no outbox row and a remote id: synced — earned, not flagged', () {
      expect(
        taskSyncStateFor(hasRemoteId: true, queued: null),
        TaskSyncState.synced,
      );
    });

    test('a pending row is still this device, whatever the remote id says', () {
      expect(
        taskSyncStateFor(hasRemoteId: true, queued: OutboxStatus.pending),
        TaskSyncState.thisDevice,
        reason: 'a queued edit has not reached the server; the promise is unchanged',
      );
    });

    test('in flight is syncing', () {
      expect(
        taskSyncStateFor(hasRemoteId: false, queued: OutboxStatus.inFlight),
        TaskSyncState.syncing,
      );
    });

    test('failed and dead are parked failures, drawn rather than dropped', () {
      expect(
        taskSyncStateFor(hasRemoteId: true, queued: OutboxStatus.failed),
        TaskSyncState.failed,
      );
      expect(
        taskSyncStateFor(hasRemoteId: false, queued: OutboxStatus.dead),
        TaskSyncState.failed,
      );
    });

    test('the status column parses by name and an unknown name reads pending', () {
      expect(parseOutboxStatus('inFlight'), OutboxStatus.inFlight);
      expect(parseOutboxStatus(null), isNull);
      expect(parseOutboxStatus(''), isNull);
      expect(parseOutboxStatus('someFutureState'), OutboxStatus.pending);
    });

    test('every state has words, a glyph and a tint', () {
      for (final state in TaskSyncState.values) {
        expect(TaskSyncBadge.labelFor(state), isNotEmpty);
        expect(TaskSyncBadge.iconFor(state), isA<IconData>());
        expect(TaskSyncBadge.tintFor(state), isA<Color>());
      }
      expect(TaskSyncBadge.labelFor(TaskSyncState.thisDevice), 'This device');
      expect(TaskSyncBadge.labelFor(TaskSyncState.synced), 'Synced');
      expect(TaskSyncBadge.tintFor(TaskSyncState.failed), AppStyle.red);
    });
  });

  group('47k — the two-clock row', () {
    testWidgets('REMIND and DUE are both drawn, and the invariant in words', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskReminderRow(task: TaskViewModel.fromMap(_seed), onSnooze: () {}),
      );
      final rendered = _text(tester);
      expect(rendered, contains('REMIND'));
      expect(rendered, contains('DUE'));
      expect(rendered, contains('never the deadline'));
    });

    testWidgets('an un-snoozed reminder reads at the deadline', (tester) async {
      await _pump(tester, TaskReminderRow(task: TaskViewModel.fromMap(_seed)));
      expect(
        _text(tester).split('Sun 06 Sep, 06:00 PM').length,
        3,
        reason: 'both clocks show the deadline until a snooze moves one',
      );
    });

    testWidgets('a snoozed reminder moves REMIND and leaves DUE alone', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskReminderRow(
          task: TaskViewModel.fromMap({
            ..._seed,
            'remindAt': '2026-09-06T07:00:00.000',
            'snoozeCount': 1,
          }),
          onSnooze: () {},
        ),
      );
      final rendered = _text(tester);
      expect(rendered, contains('Sun 06 Sep, 07:00 AM'));
      expect(rendered, contains('Sun 06 Sep, 06:00 PM'));
      expect(rendered, contains('Snoozed ×1'), reason: 'chip 1060 counts itself');
    });

    testWidgets('the control is hidden when nobody offers a snooze', (
      tester,
    ) async {
      await _pump(tester, TaskReminderRow(task: TaskViewModel.fromMap(_seed)));
      expect(find.byKey(TaskReminderRow.snoozeKey), findsNothing);
    });

    testWidgets('tapping the control reports it', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        TaskReminderRow(
          task: TaskViewModel.fromMap(_seed),
          onSnooze: () => tapped = true,
        ),
      );
      await tester.tap(find.byKey(TaskReminderRow.snoozeKey));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('859 and the badges on the card', () {
    testWidgets('a task with steps and a run offered draws the run pill', (
      tester,
    ) async {
      var opened = false;
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () {},
          onRun: () => opened = true,
          runLabel: 'Resume · Step 2 of 3',
        ),
      );
      expect(_text(tester), contains('Resume · Step 2 of 3'));
      expect(_text(tester), contains('1 of 3 · Step 2 of 3'));
      await tester.tap(find.byKey(TaskCard.runKey));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('no run pill without a host to open one', (tester) async {
      await _pump(
        tester,
        TaskCard(task: TaskViewModel.fromMap(_seed), onToggleDone: () {}),
      );
      expect(find.byKey(TaskCard.runKey), findsNothing);
    });

    testWidgets('the sync badge is drawn only when a state is handed in', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskCard(task: TaskViewModel.fromMap(_seed), onToggleDone: () {}),
      );
      expect(find.byType(TaskSyncBadge), findsNothing);
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () {},
          syncState: TaskSyncState.synced,
        ),
      );
      expect(find.byType(TaskSyncBadge), findsOneWidget);
      expect(_text(tester), contains('Synced'));
    });

    testWidgets('the long-term marker follows the flag and nothing else', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap({..._seed, 'recurrence': 'Monthly'}),
          onToggleDone: () {},
        ),
      );
      expect(
        _text(tester),
        isNot(contains('Long term')),
        reason: 'a long cycle alone does not band a task; the rule awaits a ruling',
      );
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap({..._seed, 'isLongTerm': true}),
          onToggleDone: () {},
        ),
      );
      expect(_text(tester), contains('Long term'));
    });

    testWidgets('expanded on the fold, the two-clock row rides the card', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () {},
          expanded: true,
          onSnooze: () {},
        ),
      );
      expect(find.byType(TaskReminderRow), findsOneWidget);
      expect(find.byKey(TaskReminderRow.snoozeKey), findsOneWidget);
    });

    testWidgets('a step line shows its duration and instruction', (tester) async {
      await _pump(
        tester,
        SubtaskCheckLine(
          subtask: SubtaskViewModel.fromMap(const {
            'title': 'Rinse',
            'durationSeconds': 1800,
            'instruction': 'Open the valve fully.',
          }),
        ),
      );
      expect(_text(tester), contains('30 min · Open the valve fully.'));
    });
  });

  group('the view model reads the section 46 / 47 fields off the map', () {
    test('every new field comes off the map, none is invented', () {
      final task = TaskViewModel.fromMap({
        ..._seed,
        'remindAt': '2026-09-06T07:00:00.000',
        'reminderFired': true,
        'snoozeCount': 2,
        'isLongTerm': true,
        'stepsAreSequential': true,
        'clientId': 'c-1',
        'remoteId': 'TASK-2026-00001',
      });
      expect(task.remindAt, DateTime.parse('2026-09-06T07:00:00.000'));
      expect(task.effectiveRemindAt, task.remindAt);
      expect(task.reminderFired, isTrue);
      expect(task.snoozeCount, 2);
      expect(task.isLongTerm, isTrue);
      expect(task.stepsAreSequential, isTrue);
      expect(task.clientId, 'c-1');
      expect(task.remoteId, 'TASK-2026-00001');
      expect(task.run.sequential, isTrue);
      expect(task.run.positionLabel, 'Step 2 of 3');
      expect(task.subtasks[1].isTimed, isTrue);
    });

    test('a bare map degrades to defaults', () {
      final task = TaskViewModel.fromMap(const {'title': 'x'});
      expect(task.remindAt, isNull);
      expect(task.effectiveRemindAt, isNull);
      expect(task.snoozeCount, 0);
      expect(task.isLongTerm, isFalse);
      expect(task.stepsAreSequential, isFalse);
      expect(task.clientId, isNull);
      expect(task.remoteId, isNull);
      expect(task.run.hasSteps, isFalse);
    });
  });
}
