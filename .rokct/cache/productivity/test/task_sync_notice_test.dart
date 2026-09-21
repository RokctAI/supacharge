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

// The one line the tasks page may say about a failed pull — pinned where
// it can be pinned without a store, like tasks_workspace_test.dart: this
// imports only the presentation layer, so it loads on a bare checkout.
//
// What a later edit could quietly undo:
//   * the line appears ONLY when the local list is empty AND the last
//     pull failed. An empty list with a healthy sync is just empty; a
//     list with rows in it gets no banner;
//   * the widget takes two booleans and no failure object, so no cmd
//     name, error class or error text has a path to the screen.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_sync_notice.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 900),
      builder: (context, _) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

String _text(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  group('TaskSyncNotice', () {
    testWidgets('says its one line when the list is empty and the pull failed',
        (tester) async {
      await _pump(
        tester,
        const TaskSyncNotice(localListEmpty: true, lastPullFailed: true),
      );
      expect(find.text(TaskSyncNotice.message), findsOneWidget);
      expect(
        TaskSyncNotice.message,
        'Sync paused. '
        'Your tasks will sync when the connection is back.',
      );
    });

    testWidgets('an empty list with a healthy sync is just an empty list',
        (tester) async {
      await _pump(
        tester,
        const TaskSyncNotice(localListEmpty: true, lastPullFailed: false),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a list with rows in it gets no banner, failed pull or not',
        (tester) async {
      await _pump(
        tester,
        const TaskSyncNotice(localListEmpty: false, lastPullFailed: true),
      );
      expect(find.byType(Text), findsNothing);

      await _pump(
        tester,
        const TaskSyncNotice(localListEmpty: false, lastPullFailed: false),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the line carries no admin detail', (tester) async {
      await _pump(
        tester,
        const TaskSyncNotice(localListEmpty: true, lastPullFailed: true),
      );
      final String drawn = _text(tester);
      expect(drawn, isNot(contains('api.')));
      expect(drawn, isNot(contains('list_personal_tasks')));
      expect(drawn, isNot(contains('Exception')));
      expect(drawn, isNot(contains('Error')));
    });
  });
}
