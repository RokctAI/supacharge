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

// The /tasks surface keeps a task as a plain map: on top of the columns
// TasksTable declares, it carries notifId, reminder, priority, category,
// recurrence and a subtask list. Those extras only exist in the row's `data`
// JSON blob, so a load that hands the blob back as a raw string drops all of
// them - the task comes back as a bare name and a checkbox.
//
// These tests drive the real repository against a real drift/SQLite database
// so a save/load cycle is an actual write and an actual read, and pin:
//
//   * every field the surface writes survives a full cycle;
//   * a row whose blob is missing, empty or corrupt still loads;
//   * the save path stores what it claims to, and stays idempotent instead of
//     nesting one encoding inside the next.

import 'dart:convert';
import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

/// One task with every field the surface can put on it.
Map<String, dynamic> _fullTask() => <String, dynamic>{
      'id': 'task-1',
      'notifId': 4242,
      'title': 'Ship the tasks fix',
      'isDone': false,
      'deadline': DateTime.utc(2026, 9, 14, 8, 30).toIso8601String(),
      'reminder': true,
      'priority': 'High',
      'category': 'Engineering',
      'recurrence': 'Weekly',
      'createdAt': DateTime.utc(2026, 8, 30, 6).toIso8601String(),
      'subtasks': <Map<String, dynamic>>[
        <String, dynamic>{'title': 'Decode the blob', 'isDone': true},
        <String, dynamic>{'title': 'Cover the bad rows', 'isDone': false},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase database;
  late TodoRepositoryImpl repository;

  setUpAll(() async {
    // AppDatabase opens its file under the app documents directory; in a VM
    // test that channel has no implementation, so point it at a temp dir.
    tempDir = await Directory.systemTemp.createTemp('productivity_tasks_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    // AppDatabase is a process-wide singleton by design, so the whole file
    // shares one database and each test clears the table instead.
    database = AppDatabase();
    repository = TodoRepositoryImpl(database);
  });

  tearDownAll(() async {
    await database.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await database.delete(database.tasksTable).go();
  });

  /// Reads the stored row straight from SQLite, bypassing the repository.
  Future<TaskEntity> readRow(String id) async {
    final rows = await (database.select(database.tasksTable)
          ..where((t) => t.id.equals(id)))
        .get();
    expect(rows, hasLength(1), reason: 'expected exactly one row for $id');
    return rows.single;
  }

  group('save/load round trip', () {
    test('every field the surface writes survives a cycle', () async {
      final Map<String, dynamic> task = _fullTask();
      await repository.saveTodos(<Map<String, dynamic>>[task]);

      final List<Map<String, dynamic>> loaded = await repository.loadTodos();

      expect(loaded, hasLength(1));
      final Map<String, dynamic> todo = loaded.single;
      expect(todo['id'], 'task-1');
      expect(todo['title'], 'Ship the tasks fix');
      expect(todo['isDone'], isFalse);
      expect(todo['notifId'], 4242);
      expect(todo['reminder'], isTrue);
      expect(todo['priority'], 'High');
      expect(todo['category'], 'Engineering');
      expect(todo['recurrence'], 'Weekly');
      expect(
        DateTime.parse(todo['deadline'] as String).toUtc(),
        DateTime.utc(2026, 9, 14, 8, 30),
      );
      expect(
        DateTime.parse(todo['createdAt'] as String).toUtc(),
        DateTime.utc(2026, 8, 30, 6),
      );

      final List<Map<String, dynamic>> subtasks =
          List<Map<String, dynamic>>.from(todo['subtasks'] as List);
      expect(subtasks, hasLength(2));
      expect(subtasks.first['title'], 'Decode the blob');
      expect(subtasks.first['isDone'], isTrue);
      expect(subtasks.last['title'], 'Cover the bad rows');
      expect(subtasks.last['isDone'], isFalse);
    });

    test('the stored blob never leaks back onto the surface map', () async {
      await repository.saveTodos(<Map<String, dynamic>>[_fullTask()]);

      final Map<String, dynamic> todo = (await repository.loadTodos()).single;

      // The surface re-encodes whatever map it is handed. A 'data' key on it
      // would nest one encoding inside the next on every save.
      expect(todo.containsKey('data'), isFalse);
    });

    test('a reloaded task can be saved and reloaded again unchanged',
        () async {
      await repository.saveTodos(<Map<String, dynamic>>[_fullTask()]);
      final Map<String, dynamic> first = (await repository.loadTodos()).single;

      await repository.saveTodos(<Map<String, dynamic>>[first]);
      final Map<String, dynamic> second = (await repository.loadTodos()).single;

      for (final String key in <String>[
        'id',
        'notifId',
        'title',
        'isDone',
        'reminder',
        'priority',
        'category',
        'recurrence',
        'deadline',
        'createdAt',
      ]) {
        expect(second[key], first[key], reason: '$key changed on re-save');
      }
      expect(
        List<Map<String, dynamic>>.from(second['subtasks'] as List),
        List<Map<String, dynamic>>.from(first['subtasks'] as List),
      );

      // The blob must hold the task, not a string holding the task.
      final Object? decoded = jsonDecode((await readRow('task-1')).data!);
      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded! as Map)['subtasks'], isA<List<dynamic>>());
    });

    test('several tasks all come back with their own extras', () async {
      final Map<String, dynamic> other = _fullTask()
        ..['id'] = 'task-2'
        ..['title'] = 'Second'
        ..['priority'] = 'Low'
        ..['isDone'] = true
        ..['subtasks'] = <Map<String, dynamic>>[];

      await repository.saveTodos(<Map<String, dynamic>>[_fullTask(), other]);
      final List<Map<String, dynamic>> loaded = await repository.loadTodos();

      expect(loaded, hasLength(2));
      final Map<String, dynamic> one =
          loaded.firstWhere((t) => t['id'] == 'task-1');
      final Map<String, dynamic> two =
          loaded.firstWhere((t) => t['id'] == 'task-2');
      expect(one['priority'], 'High');
      expect(one['subtasks'], hasLength(2));
      expect(two['priority'], 'Low');
      expect(two['isDone'], isTrue);
      expect(two['subtasks'], isEmpty);
    });
  });

  group('rows written before the fix, and broken rows', () {
    /// Writes a row the repository never produced - the shape a dev database
    /// from before this fix, or a hand-edited row, can hold.
    Future<void> insertRawRow(String id, Value<String?> data) async {
      await database.into(database.tasksTable).insertOnConflictUpdate(
            TasksTableCompanion.insert(
              id: Value(id),
              title: 'Legacy $id',
              isCompleted: const Value(true),
              dueDate: Value(DateTime.utc(2026, 10, 1)),
              data: data,
            ),
          );
    }

    test('a null data column loads from its columns alone', () async {
      await insertRawRow('legacy-null', const Value<String?>(null));

      final Map<String, dynamic> todo = (await repository.loadTodos()).single;

      expect(todo['id'], 'legacy-null');
      expect(todo['title'], 'Legacy legacy-null');
      expect(todo['isDone'], isTrue);
      expect(todo['deadline'], isNotNull);
      expect(todo.containsKey('data'), isFalse);
      // The surface defaults these when they are absent; what matters is that
      // nothing threw and no key holds a raw JSON string.
      expect(todo['priority'], isNull);
      expect(todo['subtasks'], isNull);
    });

    test('an empty data column loads', () async {
      await insertRawRow('legacy-empty', const Value<String?>('   '));

      final Map<String, dynamic> todo = (await repository.loadTodos()).single;

      expect(todo['title'], 'Legacy legacy-empty');
      expect(todo.containsKey('data'), isFalse);
    });

    test('a malformed data column loads instead of throwing', () async {
      await insertRawRow('legacy-broken', const Value<String?>('{"title": '));

      final Map<String, dynamic> todo = (await repository.loadTodos()).single;

      expect(todo['id'], 'legacy-broken');
      expect(todo['title'], 'Legacy legacy-broken');
      expect(todo['isDone'], isTrue);
    });

    test('a data column holding valid JSON that is not an object loads',
        () async {
      await insertRawRow('legacy-array', const Value<String?>('["a", "b"]'));

      final Map<String, dynamic> todo = (await repository.loadTodos()).single;

      expect(todo['title'], 'Legacy legacy-array');
      expect(todo.containsKey('data'), isFalse);
    });

    test('one broken row does not take the good rows down with it', () async {
      await insertRawRow('legacy-broken', const Value<String?>('not json'));
      await repository.saveTodos(<Map<String, dynamic>>[_fullTask()]);

      final List<Map<String, dynamic>> loaded = await repository.loadTodos();

      expect(loaded, hasLength(2));
      final Map<String, dynamic> good =
          loaded.firstWhere((t) => t['id'] == 'task-1');
      expect(good['priority'], 'High');
      expect(good['subtasks'], hasLength(2));
    });
  });

  group('the save path writes what it claims to', () {
    test('typed columns and the blob agree with the map handed in', () async {
      final Map<String, dynamic> task = _fullTask();
      await repository.saveTodos(<Map<String, dynamic>>[task]);

      final TaskEntity row = await readRow('task-1');
      expect(row.title, 'Ship the tasks fix');
      expect(row.isCompleted, isFalse);
      expect(row.dueDate?.toUtc(), DateTime.utc(2026, 9, 14, 8, 30));
      expect(row.createdAt.toUtc(), DateTime.utc(2026, 8, 30, 6));

      final Map<String, dynamic> blob =
          jsonDecode(row.data!) as Map<String, dynamic>;
      expect(blob['notifId'], 4242);
      expect(blob['reminder'], isTrue);
      expect(blob['priority'], 'High');
      expect(blob['category'], 'Engineering');
      expect(blob['recurrence'], 'Weekly');
      expect(blob['subtasks'], hasLength(2));
      expect(blob.containsKey('data'), isFalse);
    });

    test('a task saved without an id keeps the generated one', () async {
      final Map<String, dynamic> task = _fullTask()..remove('id');

      await repository.saveTodos(<Map<String, dynamic>>[task]);
      final Map<String, dynamic> todo = (await repository.loadTodos()).single;

      expect(todo['id'], isA<String>());
      expect((todo['id'] as String), isNotEmpty);

      final Map<String, dynamic> blob =
          jsonDecode((await readRow(todo['id'] as String)).data!)
              as Map<String, dynamic>;
      // The row key and the stored blob must name the same task, or the next
      // load hands the surface an id that no row answers to.
      expect(blob['id'], todo['id']);
    });

    test('one unencodable task does not lose the rest of the write',
        () async {
      final Map<String, dynamic> broken = _fullTask()
        ..['id'] = 'task-broken'
        ..['notifId'] = Object();

      await repository.saveTodos(
        <Map<String, dynamic>>[broken, _fullTask()],
      );

      final List<Map<String, dynamic>> loaded = await repository.loadTodos();
      expect(loaded, hasLength(2));
      final Map<String, dynamic> good =
          loaded.firstWhere((t) => t['id'] == 'task-1');
      expect(good['priority'], 'High');
      expect(good['subtasks'], hasLength(2));
      final Map<String, dynamic> salvaged =
          loaded.firstWhere((t) => t['id'] == 'task-broken');
      expect(salvaged['title'], 'Ship the tasks fix');
    });
  });
}
