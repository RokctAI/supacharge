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

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:base_sdk/src/database/app_database.dart';
import 'package:base_sdk/src/database/owner_scope.dart';

/// The two owner-scoped tables exactly as they were before this change: no
/// `owner` column, and a primary key that cannot hold two accounts' rows for
/// one key. This is what is on every device in the field today.
const String _oldKeyValueTable = '''
CREATE TABLE key_value_table (
  box TEXT NOT NULL,
  id TEXT NOT NULL,
  data TEXT NOT NULL,
  PRIMARY KEY (box, id)
)''';

const String _oldOutboxTable = '''
CREATE TABLE outbox_table (
  id TEXT NOT NULL,
  op_type TEXT NOT NULL,
  sdk TEXT NOT NULL,
  payload TEXT NOT NULL,
  temp_ids TEXT NOT NULL,
  depends_on TEXT NOT NULL,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  last_error TEXT NULL,
  next_attempt_at INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (id)
)''';

const String _oldIdMappingsTable = '''
CREATE TABLE id_mappings_table (
  temp_id TEXT NOT NULL,
  backend_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  mapped_at INTEGER NOT NULL,
  PRIMARY KEY (temp_id)
)''';

/// Upgrading a device that already has user data on it.
///
/// Two shapes matter and both are here: an ORDINARY upgrade (stored version
/// below the new one) and the NUMBERING SLIP (stored version already at the
/// composed maximum, so drift runs no migration at all - not onCreate, the
/// file exists, and not onUpgrade, the versions match). The second is the one
/// that cost productivity_sdk its notes table, and the one a column - unlike
/// a whole table - has no existing floor under it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rokct_owner_scope');
    file = File(p.join(dir.path, 'rokct_app.sqlite'));
    OwnerScope.instance.debugReset(withResolver: () => null);
  });

  tearDown(() async {
    OwnerScope.instance.debugReset();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// Writes a pre-owner-scope file carrying one document and one queued op,
  /// stamped with [storedVersion].
  Future<void> seedPreOwnerScopeFile(int storedVersion) async {
    final raw = NativeDatabase(file);
    final db = _RawDatabase(raw);
    await db.customStatement(_oldKeyValueTable);
    await db.customStatement(_oldOutboxTable);
    await db.customStatement(_oldIdMappingsTable);
    await db.customStatement(
      "INSERT INTO key_value_table (box, id, data) "
      "VALUES ('tasks', 't1', '${jsonEncode({'title': 'fit the softener'})}')",
    );
    await db.customStatement(
      "INSERT INTO outbox_table (id, op_type, sdk, payload, temp_ids, "
      "depends_on, status, attempts, created_at, updated_at) "
      "VALUES ('op-1', 'task.create', 'productivity_sdk', '{}', '[]', '[]', "
      "'pending', 0, 1, 1)",
    );
    await db.customStatement('PRAGMA user_version = $storedVersion');
    await db.close();
  }

  Future<T> onOpen<T>(Future<T> Function(AppDatabase db) body) async {
    final db = AppDatabase.forTesting(NativeDatabase(file));
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
          variables: [Variable<String>(table)],
        )
        .get();
    return rows.map((row) => row.read<String>('name')).toList();
  }

  Future<int> userVersion(AppDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

  for (final stored in <int>[18, 19]) {
    final label = stored == 19
        ? 'a file already AT the composed version (the numbering slip)'
        : 'a file below the composed version (an ordinary upgrade)';

    group(label, () {
      test('gains the owner column on both tables and keeps its rows',
          () async {
        await seedPreOwnerScopeFile(stored);

        await onOpen((db) async {
          expect(await columnsOf(db, 'key_value_table'), contains('owner'));
          expect(await columnsOf(db, 'outbox_table'), contains('owner'));

          // Nothing deleted: the point of the ruling.
          expect(
            await db.getItem('tasks', 't1'),
            {'title': 'fit the softener'},
          );
          expect(await db.select(db.outboxTable).get(), hasLength(1));
        });
      });

      test('leaves the carried-over rows unowned, guessing no owner',
          () async {
        await seedPreOwnerScopeFile(stored);

        await onOpen((db) async {
          final row = await db.select(db.keyValueTable).getSingle();
          expect(row.owner, kUnownedOwner);
          final op = await db.select(db.outboxTable).getSingle();
          expect(op.owner, kUnownedOwner);
        });
      });

      test('those rows are still visible to whoever signs in next', () async {
        await seedPreOwnerScopeFile(stored);

        await onOpen((db) async {
          OwnerScope.instance.debugReset(withResolver: () => 'user-a');
          // No worse than today: legacy data reads exactly as it did, rather
          // than vanishing behind a strict owner match.
          expect(
            await db.getItem('tasks', 't1'),
            {'title': 'fit the softener'},
          );
          expect(await db.countBox('tasks'), 1);
        });
      });

      test('the widened primary key is really in place afterwards', () async {
        await seedPreOwnerScopeFile(stored);

        await onOpen((db) async {
          OwnerScope.instance.debugReset(withResolver: () => 'user-a');
          await db.putItem('settings', 'theme', {'mode': 'dark'});
          OwnerScope.instance.debugReset(withResolver: () => 'user-b');
          await db.putItem('settings', 'theme', {'mode': 'light'});

          // Only possible if the table was rebuilt with {box, id, owner} as
          // its key; the old key would have raised a uniqueness conflict (or
          // silently replaced the first row).
          final rows = await (db.select(db.keyValueTable)
                ..where((t) => t.box.equals('settings')))
              .get();
          expect(rows.map((r) => r.owner), <String>['user-a', 'user-b']);
        });
      });

      test('the rebuild leaves no scratch table behind and is idempotent',
          () async {
        await seedPreOwnerScopeFile(stored);
        await onOpen((db) async {});

        // A second and third open must do nothing and change nothing.
        for (var i = 0; i < 2; i++) {
          await onOpen((db) async {
            final tables = await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table'",
                )
                .get();
            final names =
                tables.map((row) => row.read<String>('name')).toList();
            expect(
              names.where((n) => n.contains('pre_owner_scope')),
              isEmpty,
            );
            expect(await db.ensureOwnerScopeColumns(), isEmpty);
            expect(
              await db.getItem('tasks', 't1'),
              {'title': 'fit the softener'},
            );
          });
        }
      });
    });
  }

  test('a fresh install comes up with the owner column already there',
      () async {
    await onOpen((db) async {
      expect(await columnsOf(db, 'key_value_table'), contains('owner'));
      expect(await columnsOf(db, 'outbox_table'), contains('owner'));
      expect(await db.ensureOwnerScopeColumns(), isEmpty);
      expect(await userVersion(db), db.schemaVersion);
    });
  });

  test(
    "the manifest's claimed migration version and this Dart schemaVersion "
    'agree, and the step calls the method that exists',
    () async {
      // The composer SUBSTITUTES schemaVersion from the manifest, so a number
      // that drifts between the two files is invisible until it reaches a
      // device. Read the manifest rather than trust it.
      final manifest =
          jsonDecode(await File('manifest.json').readAsString())
              as Map<String, dynamic>;
      final migration = (manifest['database']
          as Map<String, dynamic>)['migration'] as Map<String, dynamic>;

      await onOpen((db) async {
        expect(migration['version'], db.schemaVersion);
      });
      expect(migration['step'], contains('ensureOwnerScopeColumns'));
      expect(migration['step'], contains('from < ${migration['version']}'));
    },
  );
}

/// A bare drift database on a caller-supplied executor, used only to lay down
/// the pre-owner-scope schema by hand.
class _RawDatabase extends GeneratedDatabase {
  _RawDatabase(QueryExecutor executor) : super(executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables =>
      const <TableInfo<Table, dynamic>>[];

  @override
  int get schemaVersion => 1;
}
