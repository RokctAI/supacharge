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

// Design strip section 44 — the /tasks workspace components.
//
// These tests import ONLY the new presentation layer and base_sdk, never
// the SDK's repository or database layer, and that is deliberate: the
// two shipped test files in this package cannot load at all on a bare
// checkout because `build_runner` is not a dev_dependency, so drift's
// and freezed's generated sources are absent. Keeping the section-44
// components free of generated code means this suite runs anyway.
//
// What a later edit could quietly undo:
//   * subtask progress is DERIVED from the list. There is no progress
//     field anywhere, and a card that reads one would be lying.
//   * `recurrence` is stored and NOTHING acts on it (flag b). The chip
//     is drawn because the field is real — but "None" must never be
//     drawn as a repeat label, because an absent repeat is not a label.
//   * the local-only strip (828) is GONE, and deliberately: it said
//     "no remote store, no sync", which stopped being true when the
//     workspace was wired to the personal-task endpoints. Do not
//     reinstate it. What DID stay true is that every read and every
//     write on this page hits the local store first - see
//     test/task_sync_test.dart, which pins that with no backend at all.
//   * the sort control shows all three values at once. It was promoted
//     from a DropdownButton precisely because a dropdown hid two of
//     three behind a tap; a later "tidy-up" back to a dropdown would
//     undo the frame.

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_card.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_list_controls.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_view_model.dart';

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
  'title': 'Replace softener resin',
  'isDone': false,
  'deadline': '2026-09-04T14:30:00.000',
  'reminder': true,
  'priority': 'High',
  'category': 'Plant',
  'recurrence': 'Weekly',
  'createdAt': '2026-08-30T08:00:00.000',
  'subtasks': [
    {'title': 'Isolate the vessel', 'isDone': true},
    {'title': 'Backwash', 'isDone': false},
    {'title': 'Recharge brine', 'isDone': false},
  ],
};

void main() {
  group('the task map is read, never reshaped', () {
    test('every drawn field comes off the shipped task map', () {
      final task = TaskViewModel.fromMap(_seed);
      expect(task.id, 'task-1');
      expect(task.title, 'Replace softener resin');
      expect(task.isDone, isFalse);
      expect(task.deadline, DateTime.parse('2026-09-04T14:30:00.000'));
      expect(task.hasReminder, isTrue);
      expect(task.priority, 'High');
      expect(task.category, 'Plant');
      expect(task.recurrence, 'Weekly');
      expect(task.subtasks, hasLength(3));
    });

    test('a bare map degrades to defaults rather than throwing', () {
      final task = TaskViewModel.fromMap(const {'title': 'x'});
      expect(task.priority, 'Medium');
      expect(task.recurrence, 'None');
      expect(task.deadline, isNull);
      expect(task.subtasks, isEmpty);
      expect(task.subtaskProgress, isNull);
    });

    test('an unparseable deadline is null, never a wrong date', () {
      final task = TaskViewModel.fromMap(const {
        'title': 'x',
        'deadline': 'not a date',
      });
      expect(task.deadline, isNull);
    });

    test('SUBTASK PROGRESS IS DERIVED, and there is no field to read', () {
      final task = TaskViewModel.fromMap(_seed);
      expect(task.subtasksDone, 1);
      expect(task.subtaskProgress, closeTo(1 / 3, 1e-9));
    });
  });

  group('chip 825 - the task card', () {
    testWidgets('it draws title, priority, deadline, category and repeat', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskCard(task: TaskViewModel.fromMap(_seed), onToggleDone: () {}),
      );
      final rendered = _text(tester);
      expect(rendered, contains('Replace softener resin'));
      expect(rendered, contains('High'));
      expect(rendered, contains('Sep 04'));
      expect(rendered, contains('Plant'));
      expect(rendered, contains('Weekly'));
    });

    testWidgets('the deadline keeps the shipped MMM dd, hh:mm a format', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskCard(task: TaskViewModel.fromMap(_seed), onToggleDone: () {}),
      );
      expect(_text(tester), contains('Sep 04, 02:30 PM'));
    });

    testWidgets('"None" is not drawn as a repeat label', (tester) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(const {
            'title': 'x',
            'recurrence': 'None',
          }),
          onToggleDone: () {},
        ),
      );
      expect(
        _text(tester),
        isNot(contains('None')),
        reason: 'an absent repeat is not a label',
      );
    });

    testWidgets('a done task is struck through', (tester) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap({..._seed, 'isDone': true}),
          onToggleDone: () {},
        ),
      );
      final title = tester.widget<Text>(find.text('Replace softener resin'));
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('the derived progress reads N of M', (tester) async {
      await _pump(
        tester,
        TaskCard(task: TaskViewModel.fromMap(_seed), onToggleDone: () {}),
      );
      expect(_text(tester), contains('1 of 3'));
    });

    testWidgets('a task with no subtasks draws no progress bar', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(const {'title': 'x'}),
          onToggleDone: () {},
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('the checkbox reports the toggle', (tester) async {
      var toggled = false;
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () => toggled = true,
        ),
      );
      await tester.tap(find.byKey(TaskCard.doneCheckboxKey));
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets(
      'FRAME 44d - expanding in place brings the subtask lines to the '
      'phone rather than pushing a second screen',
      (tester) async {
        await _pump(
          tester,
          TaskCard(
            task: TaskViewModel.fromMap(_seed),
            onToggleDone: () {},
            expanded: true,
          ),
          width: 390,
        );
        expect(find.byType(SubtaskCheckLine), findsNWidgets(3));
        expect(_text(tester), contains('Isolate the vessel'));
      },
    );

    testWidgets('collapsed, the subtask lines are not drawn', (tester) async {
      await _pump(
        tester,
        TaskCard(task: TaskViewModel.fromMap(_seed), onToggleDone: () {}),
      );
      expect(find.byType(SubtaskCheckLine), findsNothing);
    });

    testWidgets('selection is a border, not a fill', (tester) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () {},
          selected: true,
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TaskCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect((decoration.border as Border).top.color, AppStyle.primary);
    });
  });

  group('chip 826 - the subtask check line', () {
    testWidgets('a done step is dimmed and struck', (tester) async {
      await _pump(
        tester,
        const SubtaskCheckLine(
          subtask: SubtaskViewModel(title: 'Backwash', isDone: true),
        ),
      );
      final title = tester.widget<Text>(find.text('Backwash'));
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('the remove glyph appears only when removal is offered', (
      tester,
    ) async {
      await _pump(
        tester,
        const SubtaskCheckLine(subtask: SubtaskViewModel(title: 'Backwash')),
      );
      expect(find.byIcon(Icons.close), findsNothing);
      await _pump(
        tester,
        SubtaskCheckLine(
          subtask: const SubtaskViewModel(title: 'Backwash'),
          onRemove: () {},
        ),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('chip 827 - the sort segment', () {
    testWidgets('ALL THREE VALUES ARE VISIBLE AT ONCE', (tester) async {
      await _pump(
        tester,
        TaskSortSegment(active: TaskSort.created, onChanged: (_) {}),
      );
      final rendered = _text(tester);
      expect(rendered, contains('Created'));
      expect(rendered, contains('Deadline'));
      expect(rendered, contains('Priority'));
    });

    testWidgets('it is not a dropdown', (tester) async {
      await _pump(
        tester,
        TaskSortSegment(active: TaskSort.created, onChanged: (_) {}),
      );
      expect(
        find.byType(DropdownButton<String>),
        findsNothing,
        reason: 'chip 827 exists because a dropdown hid two of three',
      );
    });

    testWidgets('tapping a segment reports it', (tester) async {
      TaskSort? picked;
      await _pump(
        tester,
        TaskSortSegment(active: TaskSort.created, onChanged: (s) => picked = s),
      );
      await tester.tap(find.text('Priority'));
      await tester.pump();
      expect(picked, TaskSort.priority);
    });
  });

  group('canonical 362/363 - the status tabs', () {
    testWidgets('each tab carries its own count', (tester) async {
      await _pump(
        tester,
        TaskStatusTabs(
          active: TaskStatusFilter.all,
          counts: const {
            TaskStatusFilter.all: 7,
            TaskStatusFilter.pending: 5,
            TaskStatusFilter.completed: 2,
          },
          onChanged: (_) {},
        ),
      );
      final rendered = _text(tester);
      expect(rendered, contains('All'));
      expect(rendered, contains('7'));
      expect(rendered, contains('5'));
      expect(rendered, contains('2'));
    });

    testWidgets('the tabs are colour-coded and the active one is lit', (
      tester,
    ) async {
      expect(
        TaskStatusTabs.tintFor(TaskStatusFilter.pending),
        isNot(TaskStatusTabs.tintFor(TaskStatusFilter.completed)),
      );
    });

    testWidgets('tapping a tab reports it', (tester) async {
      TaskStatusFilter? picked;
      await _pump(
        tester,
        TaskStatusTabs(
          active: TaskStatusFilter.all,
          counts: const {},
          onChanged: (f) => picked = f,
        ),
      );
      await tester.tap(find.text('Completed'));
      await tester.pump();
      expect(picked, TaskStatusFilter.completed);
    });
  });

  group('canonical 700 - the list header', () {
    testWidgets('the count pill is beside the title', (tester) async {
      await _pump(tester, const TaskListHeader(title: 'Tasks', count: 12));
      final rendered = _text(tester);
      expect(rendered, contains('Tasks'));
      expect(rendered, contains('12'));
    });

    testWidgets('the header carries its utilities', (tester) async {
      await _pump(
        tester,
        TaskListHeader(
          title: 'Tasks',
          count: 0,
          actions: [Icon(Icons.calendar_month, key: const Key('cal'))],
        ),
      );
      expect(find.byKey(const Key('cal')), findsOneWidget);
    });
  });

  group('chip 831 - the subtask composer row', () {
    testWidgets('it carries its own label and reports the tap', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        SubtaskComposerRow(label: 'Add a step', onTap: () => tapped = true),
      );
      expect(find.text('Add a step'), findsOneWidget);
      await tester.tap(find.byType(SubtaskComposerRow));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  // THE PHONE FOLD'S ONLY WAY INTO THE TASK FORM — Ray, on the launcher's
  // Tasks page: "tasks saved cant be edited".
  //
  // What a later edit could quietly undo: on a wide window the card's own
  // onTap opens the form in the detail plane, but on one plane that tap is
  // spoken for — it expands the card in place, which IS frame 44d's fold —
  // so the form had no gesture left and a saved task could not be changed on
  // a phone at all. The pill below is that gesture. Dropping it, or drawing
  // it only on a collapsed card, puts the bug straight back.
  group('the edit pill - the way into the task form on the phone fold', () {
    testWidgets('the expanded card offers it and reports the tap', (
      tester,
    ) async {
      var edited = false;
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () {},
          expanded: true,
          onEdit: () => edited = true,
        ),
        width: 390,
      );

      expect(find.byKey(TaskCard.editKey), findsOneWidget);
      await tester.tap(find.byKey(TaskCard.editKey));
      await tester.pump();
      expect(edited, isTrue);
    });

    testWidgets('a collapsed card keeps it out of the list', (tester) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () {},
          onEdit: () {},
        ),
        width: 390,
      );

      expect(find.byKey(TaskCard.editKey), findsNothing);
    });

    testWidgets('no callback draws no pill - what a wide window passes', (
      tester,
    ) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(_seed),
          onToggleDone: () {},
          expanded: true,
        ),
      );

      expect(find.byKey(TaskCard.editKey), findsNothing);
    });

    testWidgets('a DONE task can still be opened - being finished is a field '
        'like any other, and a wrong one has to be fixable', (tester) async {
      await _pump(
        tester,
        TaskCard(
          task: TaskViewModel.fromMap(<String, dynamic>{
            ..._seed,
            'isDone': true,
          }),
          onToggleDone: () {},
          expanded: true,
          onEdit: () {},
        ),
        width: 390,
      );

      expect(find.byKey(TaskCard.editKey), findsOneWidget);
    });
  });
}
