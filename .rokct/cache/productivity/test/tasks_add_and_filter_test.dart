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


// The two smaller things Ray asked for on the launcher's Tasks page, in the
// same pass as the notes and edit fixes:
//
//   * "plus opens new but i think hlding it should give me option like tasks
//     notes" — the add button's long press names both lists.
//   * "when thereis completed task switch from all to pending" — the status
//     tabs open on the work that is left.
//
// Like the rest of this suite these import only the presentation and
// application layers, never the repository or the database, so they load on a
// bare checkout (the composed app is where the drift tables exist).
//
// What a later edit could quietly undo:
//   * the TAP must keep opening a new item without asking. The sheet is the
//     long press only; making the tap ask a question is a worse page.
//   * the filter rule is DERIVED and must stay pure. The moment it reads a
//     stored preference it starts being right about a list it has not seen.
//   * the rule chooses an INITIAL value. Re-deriving it over a filter the
//     reader picked is the failure mode, not the feature.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/tasks/initial_status_filter.dart';
import 'package:productivity_sdk/src/common/presentation/notes/notes_list_controls.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/new_item_sheet.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_view_model.dart';

/// What the sheet resolved to, filled in once it closes — the sheet outlives
/// the call that opened it, so the value cannot be returned from the helper.
class _Chosen {
  bool closed = false;
  WorkspaceList? list;
}

/// Opens the sheet from a button, the way the page's add button does.
Future<_Chosen> _openSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final _Chosen chosen = _Chosen();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 900),
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                chosen.list = await showNewItemSheet(context);
                chosen.closed = true;
              },
              child: const Text('add'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('add'));
  await tester.pumpAndSettle();
  return chosen;
}

void main() {
  group('the add button long press - Task or Note', () {
    testWidgets('it names both lists at once', (tester) async {
      await _openSheet(tester);

      expect(find.text('New task'), findsOneWidget);
      expect(find.text('New note'), findsOneWidget);
      expect(
        find.byKey(newItemSheetKeyFor(WorkspaceList.tasks)),
        findsOneWidget,
      );
      expect(
        find.byKey(newItemSheetKeyFor(WorkspaceList.notes)),
        findsOneWidget,
      );
    });

    testWidgets('choosing Note resolves to the notes list', (tester) async {
      final _Chosen chosen = await _openSheet(tester);
      await tester.tap(find.byKey(newItemSheetKeyFor(WorkspaceList.notes)));
      await tester.pumpAndSettle();

      expect(chosen.closed, isTrue, reason: 'the sheet closes on a choice');
      expect(chosen.list, WorkspaceList.notes);
      expect(find.text('New note'), findsNothing);
    });

    testWidgets('choosing Task resolves to the tasks list', (tester) async {
      final _Chosen chosen = await _openSheet(tester);
      await tester.tap(find.byKey(newItemSheetKeyFor(WorkspaceList.tasks)));
      await tester.pumpAndSettle();

      expect(chosen.list, WorkspaceList.tasks);
    });

    testWidgets('it resolves to null when dismissed, so nothing opens', (
      tester,
    ) async {
      final _Chosen chosen = await _openSheet(tester);
      // Tapping the scrim is how a modal bottom sheet is dismissed.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(chosen.closed, isTrue);
      expect(chosen.list, isNull,
          reason: 'a dismissed sheet must open neither form');
      expect(find.text('New task'), findsNothing);
    });

    test('every list on the segment has a row and a label of its own', () {
      // A third list added to WorkspaceList without a label here would make
      // the sheet throw rather than quietly offer one option.
      for (final WorkspaceList list in WorkspaceList.values) {
        expect(newItemSheetLabelFor(list), isNotEmpty);
        expect(WorkspaceListSegment.labelFor(list), isNotEmpty);
      }
    });
  });

  group('InitialStatusFilter - the tabs open on the work that is left', () {
    test('a list with completed work in it opens on Pending', () {
      expect(
        InitialStatusFilter.forCompletedCount(1),
        TaskStatusFilter.pending,
      );
      expect(
        InitialStatusFilter.forCompletedCount(9),
        TaskStatusFilter.pending,
      );
    });

    test('nothing completed keeps the shipped All', () {
      expect(InitialStatusFilter.forCompletedCount(0), TaskStatusFilter.all);
    });

    test('an empty list is All, not Pending - there is no work to be left of', () {
      expect(InitialStatusFilter.forTodos(const []), TaskStatusFilter.all);
    });

    test('it reads the same isDone field the tabs count', () {
      expect(
        InitialStatusFilter.forTodos(const <Map<String, dynamic>>[
          {'id': 'a', 'isDone': false},
          {'id': 'b', 'isDone': true},
        ]),
        TaskStatusFilter.pending,
      );
      expect(
        InitialStatusFilter.forTodos(const <Map<String, dynamic>>[
          {'id': 'a', 'isDone': false},
          {'id': 'b'},
        ]),
        TaskStatusFilter.all,
      );
    });

    test('a non-bool isDone is not completed, and never throws', () {
      // The surface holds Map<String, dynamic>: a pulled or hand-edited row
      // can carry anything at all in that key.
      expect(
        InitialStatusFilter.forTodos(const <Map<String, dynamic>>[
          {'id': 'a', 'isDone': 'true'},
          {'id': 'b', 'isDone': 1},
          {'id': 'c', 'isDone': null},
        ]),
        TaskStatusFilter.all,
      );
    });

    test('it never chooses Completed - a filter that hides every open task '
        'is not a page anyone asked to open on', () {
      for (int completed = 0; completed < 50; completed++) {
        expect(
          InitialStatusFilter.forCompletedCount(completed),
          isNot(TaskStatusFilter.completed),
        );
      }
    });
  });
}
