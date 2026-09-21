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

// Design strip frame 46i — the paused run on the hub's Tasks row (and
// 47j, folded into it).
//
// What a later edit could quietly undo:
//   * the line is DERIVED from the task list; there is no paused-runs
//     table and nothing sets a flag;
//   * it is exactly nothing when no run is paused — no spinner, no
//     placeholder, no empty row;
//   * it is one line on the Tasks row, wired through the manifest to the
//     host's `// @productivity-tasks-row` marker, and opens the run by
//     route path so the host never imports a page.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/run/paused_run.dart';
import 'package:productivity_sdk/src/common/presentation/hub/paused_run_line.dart';

Map<String, dynamic> _task(
  String id,
  String title, {
  bool done = false,
  List<Map<String, dynamic>> steps = const <Map<String, dynamic>>[],
}) => <String, dynamic>{'id': id, 'title': title, 'isDone': done, 'subtasks': steps};

const Map<String, dynamic> _untouched = <String, dynamic>{'title': 'a', 'isDone': false};

Map<String, dynamic> _doneAt(String when) => <String, dynamic>{
  'title': 'a',
  'isDone': true,
  'completedAt': when,
};

Map<String, dynamic> _startedAt(String when) => <String, dynamic>{
  'title': 'b',
  'isDone': false,
  'durationSeconds': 600,
  'startedAt': when,
};

/// The frame: paused on Thursday, opened days later.
final Map<String, dynamic> _stockCount = _task(
  'task-stock',
  'Month-end stock count',
  steps: <Map<String, dynamic>>[
    _doneAt('2026-08-27T09:00:00.000'),
    _doneAt('2026-08-27T09:20:00.000'),
    _startedAt('2026-08-27T09:25:00.000'),
    _untouched,
    _untouched,
    _untouched,
  ],
);

Future<void> _pump(WidgetTester tester, Widget child, {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: ScreenUtilInit(
        designSize: const Size(390, 900),
        builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
      ),
    ),
  );
}

void main() {
  group('the derivation', () {
    test('no run in progress is null, not an empty summary', () {
      expect(PausedRunSummary.fromTodos(const <Map<String, dynamic>>[]), isNull);
      expect(
        PausedRunSummary.fromTodos(<Map<String, dynamic>>[
          _task('plain', 'No steps'),
          _task('fresh', 'Untouched run', steps: <Map<String, dynamic>>[_untouched, _untouched]),
          _task('finished', 'Finished run', steps: <Map<String, dynamic>>[_doneAt('2026-08-27T09:00:00.000')]),
          _task('ticked', 'Done task', done: true, steps: <Map<String, dynamic>>[_doneAt('2026-08-27T09:00:00.000'), _untouched]),
        ]),
        isNull,
      );
    });

    test('a touched, unfinished run is paused, with its position', () {
      final PausedRunSummary? summary = PausedRunSummary.fromTodos(<Map<String, dynamic>>[_stockCount]);
      expect(summary, isNotNull);
      expect(summary!.count, 1);
      expect(summary.first.taskId, 'task-stock');
      expect(summary.first.taskTitle, 'Month-end stock count');
      expect(summary.first.positionLabel, 'Step 3 of 6');
      expect(summary.first.lastTouched, DateTime.parse('2026-08-27T09:25:00.000'));
    });

    test('the most recently touched run comes first', () {
      final PausedRunSummary summary = PausedRunSummary.fromTodos(<Map<String, dynamic>>[
        _stockCount,
        _task('later', 'Softener regeneration', steps: <Map<String, dynamic>>[
          _doneAt('2026-08-30T08:00:00.000'),
          _untouched,
        ]),
        _task('hand', 'Ticked by hand', steps: <Map<String, dynamic>>[
          <String, dynamic>{'title': 'x', 'isDone': true},
          _untouched,
        ]),
      ])!;
      expect(summary.runs.map((r) => r.taskId), ['later', 'task-stock', 'hand']);
    });

    test('"kept from" reads as a person says it', () {
      final DateTime now = DateTime(2026, 8, 31, 10); // a Monday
      expect(keptFromLabel(DateTime(2026, 8, 31, 8), now: now), 'kept from earlier today');
      expect(keptFromLabel(DateTime(2026, 8, 30, 8), now: now), 'kept from yesterday');
      expect(keptFromLabel(DateTime(2026, 8, 27, 9), now: now), 'kept from Thursday');
      expect(keptFromLabel(DateTime(2026, 8, 12, 9), now: now), 'kept from 12 Aug');
      expect(keptFromLabel(null, now: now), isNull);
    });
  });

  group('chip 859 on the hub row', () {
    testWidgets('HIDDEN when no run is paused', (tester) async {
      await _pump(
        tester,
        const PausedRunLine(),
        overrides: <Override>[pausedRunProvider.overrideWith((ref) async => null)],
      );
      await tester.pump();
      expect(find.byKey(PausedRunLineView.key859), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('hidden while the store is still being read, and on failure', (tester) async {
      await _pump(
        tester,
        const PausedRunLine(),
        overrides: <Override>[
          pausedRunProvider.overrideWith((ref) => Future<PausedRunSummary?>.error('no store')),
        ],
      );
      expect(find.byType(Text), findsNothing);
      await tester.pump();
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('names the run, the task and where it stopped', (tester) async {
      final PausedRunSummary summary = PausedRunSummary.fromTodos(<Map<String, dynamic>>[_stockCount])!;
      await _pump(
        tester,
        const PausedRunLine(),
        overrides: <Override>[pausedRunProvider.overrideWith((ref) async => summary)],
      );
      await tester.pump();
      expect(find.text('1 run paused · Month-end stock count, step 3 of 6'), findsOneWidget);
      expect(find.textContaining('kept from'), findsOneWidget);
    });

    testWidgets('the words, read against a fixed clock', (tester) async {
      final PausedRunSummary summary = PausedRunSummary.fromTodos(<Map<String, dynamic>>[_stockCount])!;
      await _pump(
        tester,
        PausedRunLineView(summary: summary, now: DateTime(2026, 8, 31, 10)),
      );
      expect(find.text('kept from Thursday — resumes where it stopped'), findsOneWidget);
    });

    testWidgets('two runs count themselves', (tester) async {
      final PausedRunSummary summary = PausedRunSummary.fromTodos(<Map<String, dynamic>>[
        _stockCount,
        _task('later', 'Softener regeneration', steps: <Map<String, dynamic>>[
          _doneAt('2026-08-30T08:00:00.000'),
          _untouched,
        ]),
      ])!;
      await _pump(tester, PausedRunLineView(summary: summary, now: DateTime(2026, 8, 31, 10)));
      expect(find.text('2 runs paused · Softener regeneration, step 2 of 2'), findsOneWidget);
      expect(find.text('kept from yesterday — and 1 more'), findsOneWidget);
    });

    testWidgets('tapping opens the run by task id', (tester) async {
      String? opened;
      final PausedRunSummary summary = PausedRunSummary.fromTodos(<Map<String, dynamic>>[_stockCount])!;
      await _pump(tester, PausedRunLineView(summary: summary, onOpen: (id) => opened = id));
      await tester.tap(find.byKey(PausedRunLineView.key859));
      expect(opened, 'task-stock');
    });
  });

  group('the manifest wires it to the hub', () {
    final Map<String, dynamic> manifest =
        jsonDecode(File('manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final List<Map<String, dynamic>> integrations =
        (manifest['integrations'] as List).cast<Map<String, dynamic>>();

    test('one integration replaces the Tasks-row marker with the line', () {
      final Map<String, dynamic> row = integrations.firstWhere(
        (i) => (i['placeholder'] as String).trim() == '// @productivity-tasks-row',
      );
      expect(row['target'], 'lib/presentation/pages/manager/restaurant/restaurant_page.dart');
      // The indent travels with the marker, exactly like @launcher-glance:
      // the composer does a plain substring replace, and the bare marker
      // is a prefix of the imports marker at column 0.
      expect((row['placeholder'] as String).startsWith('        //'), isTrue);
      expect(row['replacement'], contains('PausedRunLine('));
      expect(row['replacement'], contains("'/tasks/run?task="));
    });

    test('a second integration brings the import the line needs', () {
      final Map<String, dynamic> imports = integrations.firstWhere(
        (i) => i['placeholder'] == '// @productivity-tasks-row-imports',
      );
      expect(imports['target'], 'lib/presentation/pages/manager/restaurant/restaurant_page.dart');
      expect(imports['replacement'], "import 'package:productivity_sdk/productivity_sdk.dart';");
    });

    test('the launcher glance integration is untouched', () {
      expect(
        integrations.where((i) => (i['placeholder'] as String).contains('@launcher-glance')),
        hasLength(1),
      );
    });
  });
}
