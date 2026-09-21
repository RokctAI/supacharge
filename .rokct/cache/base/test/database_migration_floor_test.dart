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

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:base_sdk/src/database/app_database.dart';

/// The `beforeOpen` floor under migration numbering.
///
/// Every composed SDK manifest declares `database.migration.version` into ONE
/// shared namespace, and the composer takes the MAXIMUM across all manifests
/// as the app's `schemaVersion` while concatenating each SDK's `step` into one
/// `onUpgrade`. Two SDKs that pick the same number - or tables registered with
/// no matching step - produce a database whose stored `user_version` already
/// equals that maximum, so drift runs NO migration at all on an upgrading
/// install: not `onCreate` (the file exists) and not `onUpgrade` (the versions
/// match). The table is in the schema and nothing ever creates it. Fresh
/// installs are fine, because `onCreate` calls `createAll`; the device that
/// upgraded crashes on its first query.
///
/// These tests drive that exact state with base's own tables. `key_value_table`
/// is in `allTables` and no `onUpgrade` step recreates it, so a file at the
/// current `schemaVersion` with that table absent is the numbering slip in
/// miniature - and the only thing that can put it back is `beforeOpen`.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rokct_migration_floor');
    file = File(p.join(dir.path, 'rokct_app.sqlite'));
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  /// One open/close cycle of the real [AppDatabase] against [file], so each
  /// body sees the migration strategy exactly as a device would on launch.
  Future<T> onOpen<T>(Future<T> Function(AppDatabase db) body) async {
    final db = AppDatabase.forTesting(NativeDatabase(file));
    try {
      return await body(db);
    } finally {
      await db.close();
    }
  }

  Future<Set<String>> tableNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<int> userVersion(AppDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

  /// Bring [file] into being at the current schema version and then remove
  /// [table] from it WITHOUT touching `user_version`, which is what a
  /// duplicate migration number leaves behind on an upgrading device.
  Future<int> seedInstallMissing(String table) async {
    await onOpen((db) async {
      await db.putItem('seeded', 'row', {'value': 1});
    });
    return onOpen((db) async {
      final version = await userVersion(db);
      await db.customStatement('DROP TABLE $table');
      expect(
        await tableNames(db),
        isNot(contains(table)),
        reason: 'the fixture must actually leave $table absent',
      );
      return version;
    });
  }

  test('a table no migration step creates is still queryable after open',
      () async {
    final stored = await seedInstallMissing('key_value_table');

    await onOpen((db) async {
      // Same version in and out: drift runs neither onCreate nor onUpgrade,
      // so anything that exists now was put there by the beforeOpen floor.
      expect(await userVersion(db), stored,
          reason: 'the fixture must not have moved the stored version');
      expect(await tableNames(db), contains('key_value_table'));

      // The real proof: a query, not a schema listing.
      expect(await db.getAll('anything'), isEmpty);
      await db.putItem('box', 'key', {'value': 7});
      expect(await db.getItem('box', 'key'), {'value': 7});
    });
  });

  test('the floor covers every table in the schema, not a hand-listed few',
      () async {
    // outbox_table and id_mappings_table were already named one by one in
    // beforeOpen; key_value_table was not. Whatever the composer injects into
    // @sdk-database-tables is in allTables too and must be covered the same
    // way, so drop all three at once and require all three back.
    await onOpen((db) async {
      await db.putItem('seeded', 'row', {'value': 1});
    });
    await onOpen((db) async {
      await db.customStatement('DROP TABLE key_value_table');
      await db.customStatement('DROP TABLE outbox_table');
      await db.customStatement('DROP TABLE id_mappings_table');
    });

    await onOpen((db) async {
      final names = await tableNames(db);
      expect(
        names,
        containsAll(<String>[
          'key_value_table',
          'outbox_table',
          'id_mappings_table',
        ]),
      );
      for (final table in db.allTables) {
        expect(names, contains(table.actualTableName));
      }
    });
  });

  test('the floor is idempotent and keeps the rows already on disk', () async {
    await onOpen((db) async {
      await db.putItem('box', 'kept', {'value': 'original'});
    });

    // Two further opens with nothing missing: CREATE TABLE IF NOT EXISTS must
    // leave the existing tables and their rows exactly as they were.
    for (var i = 0; i < 2; i++) {
      await onOpen((db) async {
        expect(await db.getItem('box', 'kept'), {'value': 'original'});
      });
    }
  });

  test('a fresh file still comes up through onCreate with a usable schema',
      () async {
    await onOpen((db) async {
      final names = await tableNames(db);
      for (final table in db.allTables) {
        expect(names, contains(table.actualTableName));
      }
      await db.putItem('box', 'key', {'value': 1});
      expect(await db.countBox('box'), 1);
    });
  });
}
