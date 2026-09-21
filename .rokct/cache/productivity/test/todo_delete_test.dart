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

// Deleting a task on the /tasks surface used to drop it from the in-memory
// list and then call saveTodos, which only inserts and updates. The row
// survived, so every task the user had ever deleted came back on the next
// start. Deletion is now its own repository operation naming one id.
//
// TasksTable has a second writer - TaskService, reached through TasksNotifier
// - and its rows are indistinguishable from the surface's: neither writer
// ever originates `createdBy`, so nothing on a row says who put it there.
// That is why the fix is an explicit delete and not a prune inside the save,
// and it is why the second test here matters as much as the first: a save
// that deleted every row absent from its own list would silently destroy the
// other writer's tasks.
//
// Both tests drive the real repository and the real service against a real
// drift/SQLite database, so a delete is an actual write and a reload is an
// actual read.

import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

Map<String, dynamic> _task(String id, String title) => <String, dynamic>{
      'id': id,
      'title': title,
      'isDone': false,
      'notifId': 4242,
      'priority': 'High',
      'category': 'Work',
      'recurrence': 'None',
      'reminder': false,
      'createdAt': DateTime.utc(2026, 8, 30, 6).toIso8601String(),
      'subtasks': <Map<String, dynamic>>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase database;
  late TodoRepositoryImpl repository;
  late TaskService service;

  setUpAll(() async {
    // AppDatabase opens its file under the app documents directory; in a VM
    // test that channel has no implementation, so point it at a temp dir.
    tempDir = await Directory.systemTemp.createTemp('productivity_delete_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    // AppDatabase is a process-wide singleton by design, so the whole file
    // shares one database and each test clears the table instead.
    database = AppDatabase();
    repository = TodoRepositoryImpl(database);
    service = TaskService(database);
  });

  tearDownAll(() async {
    await database.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await database.delete(database.tasksTable).go();
  });

  /// Counts rows straight from SQLite, bypassing both writers.
  Future<int> rowCount() async =>
      (await database.select(database.tasksTable).get()).length;

  group('deleting a task', () {
    test('a deleted task is gone after a save and reload cycle', () async {
      final Map<String, dynamic> kept = _task('keep-1', 'Survives');
      final Map<String, dynamic> doomed = _task('drop-1', 'Deleted by the user');

      // The surface saves both, as it would after the user added them.
      await repository.saveTodos(<Map<String, dynamic>>[kept, doomed]);
      expect(await rowCount(), 2, reason: 'both tasks should be stored');

      // The user deletes one. The surface drops it from its list and asks the
      // repository to delete that id.
      await repository.deleteTodo('drop-1');

      // Whatever else the surface does after a delete, it saves its list.
      await repository.saveTodos(<Map<String, dynamic>>[kept]);

      // Restart: a fresh load off the same database.
      final List<Map<String, dynamic>> loaded = await repository.loadTodos();

      expect(loaded.map((t) => t['id']), <String>['keep-1'],
          reason: 'the deleted task must not come back on the next start');
      expect(await rowCount(), 1,
          reason: 'the deleted row must be gone from the table, not just the list');
    });

    test("deleting one task leaves the other writer's rows untouched",
        () async {
      // TaskService is the second writer into TasksTable. Its rows carry the
      // same shape and, like the surface's, no marker of who wrote them.
      await service.addTask(TaskModel(
        id: 'service-1',
        title: 'Owned by TaskService',
        lastUpdated: DateTime.utc(2026, 8, 30, 7),
      ));
      await repository.saveTodos(
        <Map<String, dynamic>>[_task('surface-1', 'Owned by the surface')],
      );
      expect(await rowCount(), 2);

      // The surface deletes its own task. Its list never contained
      // service-1, so a prune-on-save would have taken that row with it.
      await repository.deleteTodo('surface-1');
      await repository.saveTodos(<Map<String, dynamic>>[]);

      final rows = await database.select(database.tasksTable).get();
      expect(rows.map((r) => r.id), <String>['service-1'],
          reason: "the other writer's row must survive the surface's delete");

      // And the other writer can still read its own task back intact.
      final tasks = await service.getTasks();
      expect(tasks.map((t) => t.id), <String>['service-1']);
      expect(tasks.single.title, 'Owned by TaskService');
    });

    test('deleting an id that is not stored changes nothing', () async {
      await repository.saveTodos(
        <Map<String, dynamic>>[_task('keep-1', 'Survives')],
      );

      await repository.deleteTodo('never-existed');
      await repository.deleteTodo('');

      expect(await rowCount(), 1);
    });
  });
}
