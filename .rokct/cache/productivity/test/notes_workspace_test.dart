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

// Notes on the /tasks workspace — Ray: "i cant do notes its only tasks and
// no seperate notes if need to be".
//
// Like tasks_workspace_test.dart these import only the presentation layer,
// never the repository or the database, so the suite loads on a bare
// checkout.
//
// What a later edit could quietly undo:
//   * a note has NO done state. A checkbox on this card would make it a
//     task with the task parts left blank, which is exactly what having a
//     separate list is for.
//   * the heading is DERIVED when the title is empty: a note jotted
//     body-first must still be findable, and writing that first line into
//     the title column would let a later body edit disagree with it.
//   * the card never prints the same words twice — the preview drops the
//     line standing in as the heading.
//   * the segment shows BOTH lists and their counts at once. The page
//     already promoted its sort from a dropdown for that reason.

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/presentation/notes/note_card.dart';
import 'package:productivity_sdk/src/common/presentation/notes/note_view_model.dart';
import 'package:productivity_sdk/src/common/presentation/notes/notes_list_controls.dart';

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

void main() {
  group('NoteViewModel', () {
    test('round-trips the store map', () {
      final Map<String, dynamic> map = <String, dynamic>{
        'id': 'note-1',
        'title': 'Softener resin',
        'body': 'Supplier quoted two weeks on the 25 L bag.',
        'createdAt': DateTime.utc(2026, 9, 14, 8, 30).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 9, 18, 6).toIso8601String(),
      };

      final NoteViewModel note = NoteViewModel.fromMap(map);

      expect(note.id, 'note-1');
      expect(note.title, 'Softener resin');
      expect(note.body, 'Supplier quoted two weeks on the 25 L bag.');
      expect(note.createdAt, DateTime.utc(2026, 9, 14, 8, 30));
      expect(note.updatedAt, DateTime.utc(2026, 9, 18, 6));
      expect(note.toMap(), map);
    });

    test('an absent field is empty, never a throw', () {
      final NoteViewModel note = NoteViewModel.fromMap(<String, dynamic>{});

      expect(note.id, '');
      expect(note.title, '');
      expect(note.body, '');
      expect(note.createdAt, isNull);
      expect(note.updatedAt, isNull);
      expect(note.isEmpty, isTrue);
      expect(note.updatedLabel, '');
    });

    test('the heading falls back to the body\'s first line', () {
      const NoteViewModel note = NoteViewModel(
        id: 'note-2',
        body: '\nCall the lab back\nask for the September COA',
      );

      expect(note.displayTitle, 'Call the lab back');
      // And the preview does not repeat it.
      expect(note.preview, 'ask for the September COA');
    });

    test('a note with neither a title nor a body still has a name', () {
      const NoteViewModel note = NoteViewModel(id: 'note-3');

      expect(note.displayTitle, 'Untitled note');
      expect(note.preview, '');
    });

    test('a titled note keeps its whole body in the preview', () {
      const NoteViewModel note = NoteViewModel(
        id: 'note-4',
        title: 'Pump hours',
        body: 'Booster at 4 210 h\nTransfer at 1 980 h',
      );

      expect(note.displayTitle, 'Pump hours');
      expect(note.preview, 'Booster at 4 210 h Transfer at 1 980 h');
    });

    test('the updated line names the last change, not the creation', () {
      final NoteViewModel note = NoteViewModel(
        id: 'note-5',
        title: 'Anything',
        createdAt: DateTime(2026, 9, 14, 8, 30),
        updatedAt: DateTime(2026, 9, 18, 14, 5),
      );

      expect(note.updatedLabel, startsWith('Updated Sep 18'));
    });
  });

  group('NoteCard', () {
    testWidgets('draws the heading, the preview and the updated line', (
      tester,
    ) async {
      await _pump(
        tester,
        NoteCard(
          note: NoteViewModel(
            id: 'note-1',
            title: 'Softener resin',
            body: 'Supplier quoted two weeks.',
            updatedAt: DateTime(2026, 9, 18, 6),
          ),
        ),
      );

      final String text = _text(tester);
      expect(text, contains('Softener resin'));
      expect(text, contains('Supplier quoted two weeks.'));
      expect(text, contains('Updated Sep 18'));
    });

    testWidgets('has no done state — a note is kept, not finished', (
      tester,
    ) async {
      await _pump(
        tester,
        const NoteCard(note: NoteViewModel(id: 'note-1', title: 'Kept')),
      );

      expect(find.byType(Checkbox), findsNothing);
      expect(find.byIcon(Icons.check_box_outlined), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('the delete control is drawn only when it does something', (
      tester,
    ) async {
      await _pump(
        tester,
        const NoteCard(note: NoteViewModel(id: 'note-1', title: 'Kept')),
      );
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      int deleted = 0;
      await _pump(
        tester,
        NoteCard(
          note: const NoteViewModel(id: 'note-1', title: 'Kept'),
          onDelete: () => deleted++,
        ),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, 1);
    });

    testWidgets('a selected card is lit in primary', (tester) async {
      await _pump(
        tester,
        const NoteCard(
          note: NoteViewModel(id: 'note-1', title: 'Kept'),
          selected: true,
        ),
      );

      final Container card = tester.widget<Container>(
        find.descendant(
          of: find.byType(NoteCard),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = card.decoration! as BoxDecoration;
      expect(decoration.border, isA<Border>());
      expect(
        (decoration.border! as Border).top.color,
        AppStyle.primary,
      );
    });

    testWidgets('tapping the card opens it', (tester) async {
      int opened = 0;
      await _pump(
        tester,
        NoteCard(
          note: const NoteViewModel(id: 'note-1', title: 'Kept'),
          onTap: () => opened++,
        ),
      );

      await tester.tap(find.byType(NoteCard));
      expect(opened, 1);
    });
  });

  group('WorkspaceListSegment', () {
    testWidgets('shows both lists and both counts at once', (tester) async {
      await _pump(
        tester,
        WorkspaceListSegment(
          active: WorkspaceList.tasks,
          counts: const <WorkspaceList, int>{
            WorkspaceList.tasks: 4,
            WorkspaceList.notes: 2,
          },
          onChanged: (_) {},
        ),
      );

      final String text = _text(tester);
      expect(text, contains('Tasks'));
      expect(text, contains('Notes'));
      expect(text, contains('4'));
      expect(text, contains('2'));
    });

    testWidgets('a missing count reads zero rather than blank', (tester) async {
      await _pump(
        tester,
        WorkspaceListSegment(
          active: WorkspaceList.notes,
          counts: const <WorkspaceList, int>{},
          onChanged: (_) {},
        ),
      );

      expect(_text(tester), contains('0'));
    });

    testWidgets('picking the other list reports it once', (tester) async {
      final List<WorkspaceList> picked = <WorkspaceList>[];
      await _pump(
        tester,
        WorkspaceListSegment(
          active: WorkspaceList.tasks,
          counts: const <WorkspaceList, int>{
            WorkspaceList.tasks: 1,
            WorkspaceList.notes: 0,
          },
          onChanged: picked.add,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('workspace-list-notes')));
      expect(picked, <WorkspaceList>[WorkspaceList.notes]);
    });
  });
}
