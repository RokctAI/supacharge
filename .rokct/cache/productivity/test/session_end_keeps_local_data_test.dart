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

// AFTER A SIGN-OUT THE TASKS LEAVE THE SCREEN AND STAY ON THE DEVICE.
//
// Ray, 2026-09-19: "if on temp local user you logout all your tasks still
// show". The symptom was that the rows were still PAINTED. The first cut of
// `ProductivitySessionEnd` answered it by deleting them -- the tasks rows, the
// notes rows, this SDK's pending outbox rows and the pull cursor -- and Ray
// ruled that wrong: a local temp account that does real work and signs out
// must not come back to an empty list, and the same holds for a seller.
//
// So the two halves of this file pull in opposite directions on purpose:
//
//   * the FIRST test is the one this change exists for -- run the hook over a
//     seeded session and every row is still there afterwards, while the
//     notifier is empty. Nothing is deleted; the screen is cleared;
//   * the LAST-BUT-ONE test is the older trap, kept: `tasksStateProvider` is
//     a plain StateNotifierProvider, root-scoped and alive for the whole
//     process, so emptying the tables around it changes nothing a user can
//     see. It now deletes the rows by hand (the hook no longer will) and
//     asserts the notifier is STILL holding both tasks. It is the reason
//     `TasksNotifier.clearLive` exists and it fails the day someone decides
//     a store clear would have been enough.
//
// Everything runs against a real drift/SQLite database and a real
// ProviderContainer, so a write is an actual write and the notifier state is
// the one a page would read.

import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/productivity_sdk.dart';
import 'package:productivity_sdk/src/common/application/tasks/tasks_notifier.dart';
import 'package:productivity_sdk/src/common/application/tasks/tasks_provider.dart';
import 'package:productivity_sdk/src/common/application/tasks/tasks_state.dart';

Map<String, dynamic> _task(String id, String title) => <String, dynamic>{
      'id': id,
      'title': title,
      'isDone': false,
      'createdAt': DateTime.utc(2026, 9, 19, 6).toIso8601String(),
      'subtasks': <Map<String, dynamic>>[],
    };

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase database;
  late TodoRepositoryImpl repository;
  late NoteRepositoryImpl notes;

  setUpAll(() async {
    // AppDatabase opens its file under the app documents directory; in a VM
    // test that channel has no implementation, so point it at a temp dir.
    tempDir = await Directory.systemTemp.createTemp('productivity_session_end');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    // AppDatabase is a process-wide singleton by design, so the whole file
    // shares one database and each test seeds it from empty.
    database = AppDatabase();
    repository = TodoRepositoryImpl(database);
    notes = NoteRepositoryImpl(database);
  });

  tearDownAll(() async {
    await database.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Everything a signed-in user's session leaves on the device.
  Future<void> seedSession() async {
    await database.delete(database.tasksTable).go();
    await database.delete(database.notesTable).go();
    await database.delete(database.outboxTable).go();
    await database.clearBox(TaskSyncStore.cursorBox);
    TaskPullService.lastFailure.value = null;

    await repository.saveTodos(<Map<String, dynamic>>[
      _task('task-1', 'Fix the gate latch'),
      _task('task-2', 'Call the plumber'),
    ]);
    await notes.saveNote(<String, dynamic>{
      'title': 'Gate code',
      'body': 'left of the meter box',
    });
    // An incremental pull cursor pointing into this user's history.
    await database.putItem(
      TaskSyncStore.cursorBox,
      TaskSyncStore.cursorKey,
      <String, dynamic>{'value': '2026-09-19 06:00:00'},
    );
  }

  /// Waits for the notifier's constructor `loadTasks` to land, so nothing is
  /// asserted against -- or disposed under -- a read still in flight.
  Future<TasksState> settled(ProviderContainer container) async {
    for (int i = 0; i < 100; i++) {
      final TasksState state = container.read(tasksStateProvider);
      if (!state.isLoading && state.tasks.isNotEmpty) return state;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return container.read(tasksStateProvider);
  }

  Future<int> taskRows() async =>
      (await database.select(database.tasksTable).get()).length;
  Future<int> noteRows() async =>
      (await database.select(database.notesTable).get()).length;
  Future<int> outboxRows() async =>
      (await database.select(database.outboxTable).get()).length;

  group('ProductivitySessionEnd.clearLiveView', () {
    // THE POINT OF THE CHANGE. Everything the signing-out user put on the
    // device is still on the device afterwards, and the screen is empty.
    test('deletes nothing, and empties the view', () async {
      await seedSession();
      expect(await taskRows(), 2);
      expect(await noteRows(), 1);
      // `saveTodos` queues one push per task through TaskSyncQueue, so the
      // seeded session leaves two pending outbox rows behind it.
      expect(await outboxRows(), 2);

      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      expect((await settled(container)).tasks, hasLength(2));

      await ProductivitySessionEnd.clearLiveView();

      expect(await taskRows(), 2, reason: 'the tasks must survive a sign-out');
      expect(await noteRows(), 1, reason: 'the notes must survive a sign-out');
      expect(
        await outboxRows(),
        2,
        reason: 'a pending push is work that never reached the server; '
            'deleting it destroys it',
      );
      expect(
        await database.getItem(
          TaskSyncStore.cursorBox,
          TaskSyncStore.cursorKey,
        ),
        isNotNull,
        reason: 'the pull cursor is not user data to throw away either',
      );
      // And the same rows read back through the surfaces that own them, so
      // this is not merely "a row exists" but "the user gets it back".
      expect(await repository.loadTodos(), hasLength(2));
      expect(await notes.loadNotes(), hasLength(1));

      // The half the bug was actually about.
      final TasksState after = container.read(tasksStateProvider);
      expect(after.tasks, isEmpty, reason: 'the tasks must leave the screen');
      expect(after.errorMessage, isNull);
      expect(after.isLoading, isFalse);
    });

    test('the data is still there for the same user signing back in',
        () async {
      await seedSession();
      await ProductivitySessionEnd.clearLiveView();

      // A fresh container is the post-sign-in page: it builds a new notifier,
      // which loads from the store. The tasks come back because they were
      // never deleted.
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        (await settled(container)).tasks,
        hasLength(2),
        reason: 'a temp-local user who signs out and back in must find their '
            'work where they left it',
      );
    });

    test('clears the stale sync-failure notice', () async {
      await seedSession();
      TaskPullService.lastFailure.value = const TaskPullFailure(
        cmd: 'api.projects.list_personal_tasks',
        errorClass: 'DioException',
      );
      expect(TaskPullService.syncFailed, isTrue);

      await ProductivitySessionEnd.clearLiveView();

      // The notice belonged to the session that just ended; the next user's
      // list must not be drawn under it. Transient error state, not user data.
      expect(TaskPullService.syncFailed, isFalse);
    });

    test(
      'emptying the tables would NOT have been enough on its own -- the '
      'root-scoped notifier keeps the tasks on screen',
      () async {
        await seedSession();
        final ProviderContainer container = ProviderContainer();
        addTearDown(container.dispose);

        // The page reads the provider; the notifier loads on construction.
        expect((await settled(container)).tasks, hasLength(2));

        // A store-only clear -- what "delete the rows" alone amounts to. The
        // hook does not do this any more, so the test does it by hand.
        await database.delete(database.tasksTable).go();

        // THIS is Ray's symptom, and the reason a delete never addressed it.
        // `tasksStateProvider` is not autoDispose, so the notifier and its
        // tasks outlive the route replace a sign-out ends with; the list is
        // still on screen even with the table empty.
        expect(
          container.read(tasksStateProvider).tasks,
          hasLength(2),
          reason: 'if this ever comes back empty the provider changed and the '
              'comment above is out of date -- but clearLive must stay',
        );

        // The hook closes that gap, and it is the whole of what it does.
        await ProductivitySessionEnd.clearLiveView();
        final TasksState after = container.read(tasksStateProvider);
        expect(after.tasks, isEmpty, reason: 'the tasks must leave the screen');
        expect(after.errorMessage, isNull);
        expect(after.isLoading, isFalse);
      },
    );

    test('a disposed notifier is not held, and clearing is safe', () async {
      await seedSession();
      final int before = TasksNotifier.liveCount;

      final ProviderContainer container = ProviderContainer();
      expect((await settled(container)).tasks, hasLength(2));
      expect(TasksNotifier.liveCount, before + 1);

      container.dispose();
      expect(
        TasksNotifier.liveCount,
        before,
        reason: 'dispose must unregister, or the registry grows without bound',
      );

      // With nothing live this is still a clean run: no disposed notifier is
      // written to, and the rows are untouched.
      await ProductivitySessionEnd.clearLiveView();
      expect(await taskRows(), 2);
    });

    test('running twice is harmless, and still deletes nothing', () async {
      await seedSession();
      await ProductivitySessionEnd.clearLiveView();
      await ProductivitySessionEnd.clearLiveView();
      expect(await taskRows(), 2);
      expect(await noteRows(), 1);
      expect(await outboxRows(), 2);
    });
  });
}
