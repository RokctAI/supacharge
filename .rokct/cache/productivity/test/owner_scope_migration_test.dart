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

// UPGRADING A DEVICE THAT ALREADY HAS THIS SDK'S DATA ON IT.
//
// The shape that matters most is the NUMBERING SLIP: the composer folds
// every SDK's migration into one shared version namespace, so a device whose
// stored user_version already equals the composed maximum runs no migration
// at all -- not onCreate (the file exists) and not onUpgrade (the versions
// match). This SDK lost its notes table to exactly that once already. A
// missing COLUMN has no floor in base_sdk's beforeOpen, which only ever
// creates a whole missing table, so this SDK carries its own:
// ProductivityOwnerScope.ready, awaited by every read and write it makes.
//
// What the rebuild must never do: destroy a row, or guess an owner for one.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:base_sdk/base_sdk.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

/// `tasks_table` exactly as it was before owner scoping: no `owner`, and a
/// primary key that cannot hold two accounts' rows for one id.
const String _oldTasksTable = '''
CREATE TABLE tasks_table (
  id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0,
  due_date INTEGER NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  created_by TEXT NULL,
  data TEXT NULL,
  client_id TEXT NULL,
  remote_id TEXT NULL,
  PRIMARY KEY (id)
)''';

const String _oldNotesTable = '''
CREATE TABLE notes_table (
  id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  PRIMARY KEY (id)
)''';

/// A drift database over a raw file, used only to write the pre-scoping
/// shape the same way a device in the field holds it.
class _RawDatabase extends GeneratedDatabase {
  _RawDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables =>
      const Iterable<TableInfo<Table, dynamic>>.empty();

  @override
  int get schemaVersion => 1;
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('productivity_owner_mig');
    file = File(p.join(dir.path, 'rokct_app.sqlite'));
    OwnerScope.instance.debugReset(withResolver: () => null);
  });

  tearDown(() async {
    OwnerScope.instance.debugReset();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// Writes a pre-owner-scope file holding one task and one note, stamped
  /// with [storedVersion].
  Future<void> seedPreOwnerScopeFile(int storedVersion) async {
    final _RawDatabase db = _RawDatabase(NativeDatabase(file));
    await db.customStatement(_oldTasksTable);
    await db.customStatement(_oldNotesTable);
    await db.customStatement(
      "INSERT INTO tasks_table (id, title, created_at, updated_at, data) "
      "VALUES ('t1', 'Fit the softener', 1, 1, '{\"id\":\"t1\"}')",
    );
    await db.customStatement(
      "INSERT INTO notes_table (id, title, body, created_at, updated_at) "
      "VALUES ('n1', 'Gate code', 'left of the meter box', 1, 1)",
    );
    await db.customStatement('PRAGMA user_version = $storedVersion');
    await db.close();
  }

  Future<T> onOpen<T>(Future<T> Function(AppDatabase db) body) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(file));
    try {
      return await body(db);
    } finally {
      await db.close();
    }
  }

  Future<List<String>> columnsOf(AppDatabase db, String table) async {
    final rows = await db
        .customSelect(
          'SELECT name FROM pragma_table_info(?1)',
          variables: <Variable<Object>>[Variable<String>(table)],
        )
        .get();
    return rows.map((row) => row.read<String>('name')).toList();
  }

  group('a file written before owner scoping', () {
    // THE NUMBERING SLIP. 20 is the version this SDK now declares, so a
    // device already sitting there runs no migration whatsoever -- and the
    // first read would throw `no such column: owner` if the floor were not
    // there.
    test('gains the column even when no migration runs at all', () async {
      await seedPreOwnerScopeFile(20);
      await onOpen((AppDatabase db) async {
        expect(await columnsOf(db, 'tasks_table'), isNot(contains('owner')));
        await ProductivityOwnerScope.ready(db);
        expect(await columnsOf(db, 'tasks_table'), contains('owner'));
        expect(await columnsOf(db, 'notes_table'), contains('owner'));
      });
    });

    test('keeps every row, and every column it already had', () async {
      await seedPreOwnerScopeFile(20);
      await onOpen((AppDatabase db) async {
        await ProductivityOwnerScope.ready(db);
        final rows = await db.select(db.tasksTable).get();
        expect(rows.length, 1);
        expect(rows.single.id, 't1');
        expect(rows.single.title, 'Fit the softener');
        expect(rows.single.data, '{"id":"t1"}');
        final notes = await db.select(db.notesTable).get();
        expect(notes.single.body, 'left of the meter box');
      });
    });

    // NO OWNER IS GUESSED. A carried-over row takes the '' default, which
    // the visibility rule reads as "belongs to nobody in particular", so it
    // stays exactly as visible as it is today.
    test('leaves carried-over rows unowned, and therefore visible', () async {
      await seedPreOwnerScopeFile(20);
      await onOpen((AppDatabase db) async {
        await ProductivityOwnerScope.ready(db);
        final rows = await db.select(db.tasksTable).get();
        expect(rows.single.owner, kUnownedOwner);

        OwnerScope.instance.debugReset(withResolver: () => 'user-a');
        final List<Map<String, dynamic>> todos =
            await TodoRepositoryImpl(db).loadTodos();
        expect(todos.map((t) => t['title']), <String>['Fit the softener']);
      });
    });

    test('parks nothing behind: the rebuild drops its own scratch table',
        () async {
      await seedPreOwnerScopeFile(20);
      await onOpen((AppDatabase db) async {
        await ProductivityOwnerScope.ready(db);
        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name LIKE '%_pre_owner_scope'",
            )
            .get();
        expect(rows, isEmpty);
      });
    });

    test('is upgraded once: running the rebuild again changes nothing',
        () async {
      await seedPreOwnerScopeFile(20);
      await onOpen((AppDatabase db) async {
        final List<String> first = await ensureProductivityOwnerColumns(
          db,
          ProductivityOwnerScope.tablesOf(db),
        );
        expect(first, contains('tasks_table'));
        expect(first, contains('notes_table'));
        final List<String> second = await ensureProductivityOwnerColumns(
          db,
          ProductivityOwnerScope.tablesOf(db),
        );
        expect(second, isEmpty, reason: 'the second pass must be a no-op');
        expect((await db.select(db.tasksTable).get()).length, 1);
      });
    });

    test('a read on the reopened file finds the same rows twice over',
        () async {
      await seedPreOwnerScopeFile(20);
      await onOpen((AppDatabase db) async {
        await ProductivityOwnerScope.ready(db);
        expect((await TodoRepositoryImpl(db).loadTodos()).length, 1);
      });
      // Reopened, with the column already in place.
      await onOpen((AppDatabase db) async {
        expect(await columnsOf(db, 'tasks_table'), contains('owner'));
        expect((await TodoRepositoryImpl(db).loadTodos()).length, 1);
        expect((await NoteRepositoryImpl(db).loadNotes()).length, 1);
      });
    });
  });

  group('the migration this SDK declares', () {
    test('claims version 20 and rebuilds every table it registers', () {
      final File manifest = File('manifest.json');
      final String text = manifest.readAsStringSync();
      expect(text, contains('"version": 20'));
      expect(text, contains('ensureProductivityOwnerColumns(this,'));
      for (final String getter in <String>[
        'tasksTable',
        'notesTable',
        'recoveryProfilesTable',
        'avoidedHabitsTable',
        'urgeLogsTable',
        'dailyRitualsTable',
        'ritualLogsTable',
        'procrastinationLogsTable',
      ]) {
        expect(text, contains(getter),
            reason: '$getter must be handed to the owner-scope rebuild');
      }
    });
  });
}
