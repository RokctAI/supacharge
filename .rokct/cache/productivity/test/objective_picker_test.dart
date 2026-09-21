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

// Design strip frame 44c — chips 834 (the picker), 833 (the link row)
// and canonical 787 (the objective card).
//
// Presentation only, no generated code, like tasks_workspace_test.dart.
//
// What a later edit could quietly undo:
//   * the pillar tabs FILTER the cards and carry their own counts, all
//     derived from the same list;
//   * Link objective is dead until a radio is on;
//   * the amber NOT-IN-BACKEND flag is NOT drawn — its preconditions are
//     met and drawing it now would be the lie;
//   * the card adds nothing: title, pillar tag, KPI count — and no KPI
//     chip when the count was not readable, which is not zero.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/models/data/objective_data.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/objective_picker_pane.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_view_model.dart';

/// The frame is a tablet (1280), and the design size matches the window
/// so ScreenUtil scales by one: the test font is square Ahem, and the
/// pillar tabs need the width to sit on screen without scrolling.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(1280, 900),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

String _text(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

const ObjectiveCatalog _catalog = ObjectiveCatalog(
  pillars: <Pillar>[
    Pillar(name: 'PIL-OPS', title: 'Operations'),
    Pillar(name: 'PIL-GRW', title: 'Growth'),
    Pillar(name: 'PIL-PPL', title: 'People'),
  ],
  objectives: <StrategicObjective>[
    StrategicObjective(name: 'OBJ-1', title: 'Cut plant downtime under 2%', pillar: 'PIL-OPS'),
    StrategicObjective(name: 'OBJ-2', title: 'Open two new depot routes', pillar: 'PIL-GRW'),
    StrategicObjective(name: 'OBJ-3', title: 'Every driver ROK-certified by Q2', pillar: 'PIL-PPL'),
    StrategicObjective(name: 'OBJ-4', title: 'Bottle cost under R4.10 landed', pillar: 'PIL-OPS'),
  ],
  kpiCountByObjective: <String, int>{'OBJ-1': 3, 'OBJ-2': 2, 'OBJ-3': 1, 'OBJ-4': 2},
);

void main() {
  group('chip 834 - the picker', () {
    testWidgets('header, count pill, provenance and every card', (tester) async {
      await _pump(
        tester,
        ObjectivePickerPane(catalog: _catalog, onCancel: () {}, onLink: (_) {}),
      );
      final String text = _text(tester);
      expect(text, contains('Link an objective'));
      expect(text, contains('4 objectives'));
      expect(text, contains(ObjectivePickerPane.provenance));
      expect(text, contains('get_strategic_objectives'));
      expect(text, contains('get_pillars'));
      for (final StrategicObjective o in _catalog.objectives) {
        expect(find.text(o.title), findsOneWidget);
      }
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Link objective'), findsOneWidget);
    });

    testWidgets('the amber flag is gone', (tester) async {
      await _pump(
        tester,
        ObjectivePickerPane(catalog: _catalog, onCancel: () {}, onLink: (_) {}),
      );
      expect(_text(tester).toUpperCase(), isNot(contains('NOT IN BACKEND')));
    });

    testWidgets('the pillar tabs carry counts derived from the list', (tester) async {
      await _pump(
        tester,
        ObjectivePickerPane(catalog: _catalog, onCancel: () {}, onLink: (_) {}),
      );
      final String text = _text(tester);
      expect(text, contains('All pillars | 4'));
      expect(text, contains('Operations | 2'));
      expect(text, contains('Growth | 1'));
      expect(text, contains('People | 1'));
    });

    testWidgets('a pillar tab FILTERS the cards', (tester) async {
      await _pump(
        tester,
        ObjectivePickerPane(catalog: _catalog, onCancel: () {}, onLink: (_) {}),
      );
      await tester.tap(find.byKey(ObjectivePickerPane.pillarTabKey('PIL-OPS')));
      await tester.pump();
      expect(find.text('Cut plant downtime under 2%'), findsOneWidget);
      expect(find.text('Bottle cost under R4.10 landed'), findsOneWidget);
      expect(find.text('Open two new depot routes'), findsNothing);
      expect(find.text('Every driver ROK-certified by Q2'), findsNothing);

      await tester.tap(find.byKey(ObjectivePickerPane.pillarTabKey('PIL-GRW')));
      await tester.pump();
      expect(find.text('Open two new depot routes'), findsOneWidget);
      expect(find.text('Cut plant downtime under 2%'), findsNothing);

      await tester.tap(find.byKey(ObjectivePickerPane.pillarTabKey(null)));
      await tester.pump();
      expect(find.byType(ObjectiveCard), findsNWidgets(4));
    });

    testWidgets('Link objective is dead until a radio is on', (tester) async {
      StrategicObjective? linked;
      await _pump(
        tester,
        ObjectivePickerPane(
          catalog: _catalog,
          onCancel: () {},
          onLink: (o) => linked = o,
        ),
      );
      expect(
        tester.widget<ElevatedButton>(find.byKey(ObjectivePickerPane.linkKey)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Open two new depot routes'));
      await tester.pump();
      await tester.tap(find.byKey(ObjectivePickerPane.linkKey));
      await tester.pump();
      expect(linked?.name, 'OBJ-2');
    });

    testWidgets('the current link starts selected, and Cancel hands back nothing', (
      tester,
    ) async {
      bool cancelled = false;
      StrategicObjective? linked;
      await _pump(
        tester,
        ObjectivePickerPane(
          catalog: _catalog,
          initialSelection: 'OBJ-3',
          onCancel: () => cancelled = true,
          onLink: (o) => linked = o,
        ),
      );
      expect(
        tester.widget<ElevatedButton>(find.byKey(ObjectivePickerPane.linkKey)).onPressed,
        isNotNull,
      );
      final ObjectiveCard card = tester.widget<ObjectiveCard>(
        find.ancestor(
          of: find.text('Every driver ROK-certified by Q2'),
          matching: find.byType(ObjectiveCard),
        ),
      );
      expect(card.selected, isTrue);
      await tester.tap(find.byKey(ObjectivePickerPane.cancelKey));
      expect(cancelled, isTrue);
      expect(linked, isNull);
    });

    testWidgets('loading draws a spinner and no cards', (tester) async {
      await _pump(
        tester,
        ObjectivePickerPane(catalog: null, loading: true, onCancel: () {}, onLink: (_) {}),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ObjectiveCard), findsNothing);
    });

    testWidgets('a failed read is drawn in the backend\'s words, with a retry', (
      tester,
    ) async {
      bool retried = false;
      await _pump(
        tester,
        ObjectivePickerPane(
          catalog: null,
          error: 'Not permitted',
          onCancel: () {},
          onLink: (_) {},
          onRetry: () => retried = true,
        ),
      );
      expect(find.text('Not permitted'), findsOneWidget);
      await tester.tap(find.byKey(ObjectivePickerPane.retryKey));
      expect(retried, isTrue);
    });

    testWidgets('an empty plan says so', (tester) async {
      await _pump(
        tester,
        ObjectivePickerPane(
          catalog: ObjectiveCatalog.empty,
          onCancel: () {},
          onLink: (_) {},
        ),
      );
      expect(find.text('No objectives in the plan yet.'), findsOneWidget);
    });
  });

  group('canonical 787 - the objective card', () {
    testWidgets('title, pillar tag, KPI count - and nothing else', (tester) async {
      await _pump(
        tester,
        ObjectiveCard(
          objective: _catalog.objectives.first,
          pillarTitle: 'Operations',
          accent: Colors.teal,
          kpiCount: 3,
        ),
      );
      expect(_text(tester), 'Operations | 3 KPIs | Cut plant downtime under 2%');
    });

    testWidgets('one KPI is singular', (tester) async {
      await _pump(
        tester,
        ObjectiveCard(
          objective: _catalog.objectives.first,
          accent: Colors.teal,
          kpiCount: 1,
        ),
      );
      expect(find.text('1 KPI'), findsOneWidget);
    });

    testWidgets('no count readable means no chip, not zero', (tester) async {
      await _pump(
        tester,
        ObjectiveCard(objective: _catalog.objectives.first, accent: Colors.teal),
      );
      expect(_text(tester), 'Cut plant downtime under 2%');
    });
  });

  group('chip 833 - the link row', () {
    testWidgets('unlinked, it says so and opens the picker', (tester) async {
      bool opened = false;
      await _pump(
        tester,
        ObjectiveLinkRow(
          task: const TaskViewModel(id: 't', title: 'x'),
          onTap: () => opened = true,
        ),
      );
      expect(find.text(ObjectiveLinkRow.label), findsOneWidget);
      expect(find.text(ObjectiveLinkRow.unlinked), findsOneWidget);
      expect(find.byKey(ObjectiveLinkRow.clearKey), findsNothing);
      await tester.tap(find.byKey(ObjectiveLinkRow.key833));
      expect(opened, isTrue);
    });

    testWidgets('linked, it reads pillar > title and offers the clear', (tester) async {
      bool cleared = false;
      await _pump(
        tester,
        ObjectiveLinkRow(
          task: const TaskViewModel(
            id: 't',
            title: 'x',
            strategicObjective: 'OBJ-1',
            strategicObjectiveTitle: 'Cut plant downtime under 2%',
            strategicObjectivePillar: 'Operations',
          ),
          onTap: () {},
          onClear: () => cleared = true,
        ),
      );
      expect(find.text('Operations › “Cut plant downtime under 2%”'), findsOneWidget);
      await tester.tap(find.byKey(ObjectiveLinkRow.clearKey));
      expect(cleared, isTrue);
    });

    testWidgets('a link with no display pair falls back to the name', (tester) async {
      await _pump(
        tester,
        ObjectiveLinkRow(
          task: const TaskViewModel(id: 't', title: 'x', strategicObjective: 'OBJ-1'),
          onTap: () {},
        ),
      );
      expect(find.text('“OBJ-1”'), findsOneWidget);
    });
  });

  group('the view model reads the link off the map', () {
    test('name and display pair, blanks as null', () {
      final TaskViewModel task = TaskViewModel.fromMap(const <String, dynamic>{
        'title': 'x',
        'strategicObjective': 'OBJ-1',
        'strategicObjectiveTitle': '  ',
        'strategicObjectivePillar': 'Operations',
      });
      expect(task.hasStrategicObjective, isTrue);
      expect(task.strategicObjective, 'OBJ-1');
      expect(task.strategicObjectiveTitle, isNull);
      expect(task.strategicObjectivePillar, 'Operations');
      expect(TaskViewModel.fromMap(const {'title': 'x'}).hasStrategicObjective, isFalse);
    });
  });

  group('the accent is derived from the pillar list', () {
    test('the same pillar gets the same accent on every read', () {
      expect(_catalog.accentIndexOf('PIL-GRW'), 1);
      expect(_catalog.accentIndexOf('missing'), 0);
      expect(pillarAccent(1), pillarAccent(6), reason: 'wraps, never throws');
    });
  });
}
