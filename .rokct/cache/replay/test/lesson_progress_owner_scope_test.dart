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

// Owner scoping for lesson_progress_table: two accounts on one device do not
// resume each other's lessons, rows written before scoping stay visible to
// everyone, signing out destroys nothing, and a file that predates the owner
// column migrates without losing a position.
//
// The table lives in base_sdk's composed AppDatabase in a real app, which
// has no generated accessors here, so these drive an equivalent generated
// database of this SDK's own tables.

import 'package:base_sdk/base_sdk.dart'
    show OwnerScope, kUnownedOwner, ownerVisible;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:replay_sdk/src/common/infrastructure/database/drift_tables.dart';

part 'lesson_progress_owner_scope_test.g.dart';

@DriftDatabase(tables: [LessonProgressTable, DownloadedAssetsTable])
class OwnerScopeTestDatabase extends _$OwnerScopeTestDatabase {
  OwnerScopeTestDatabase(super.executor);

  @override
  int get schemaVersion => 23;
}

/// The table exactly as it stood before this change: no `owner`,
/// `session_id` alone as the key.
const String _preOwnerScopeDdl = '''
CREATE TABLE lesson_progress_table (
  session_id TEXT NOT NULL,
  "current_timestamp" REAL NOT NULL,
  subtopic_ref TEXT NOT NULL,
  door_open INTEGER NOT NULL,
  PRIMARY KEY (session_id)
);
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OwnerScopeTestDatabase db;

  setUp(() {
    db = OwnerScopeTestDatabase(NativeDatabase.memory());
    OwnerScope.instance.debugReset(withResolver: () => null);
  });

  tearDown(() async {
    await db.close();
    OwnerScope.instance.debugReset();
  });

  Future<void> write(String owner, String sessionId, double at) {
    return db.into(db.lessonProgressTable).insertOnConflictUpdate(
          LessonProgressTableCompanion.insert(
            sessionId: sessionId,
            currentTimestamp: at,
            subtopicRef: 'sub-1',
            doorOpen: false,
            owner: Value(owner),
          ),
        );
  }

  Future<List<double>> visibleTo(String owner) async {
    final rows = await (db.select(db.lessonProgressTable)
          ..where((t) => ownerVisible(t.owner, owner)))
        .get();
    return rows.map((r) => r.currentTimestamp).toList()..sort();
  }

  Future<int> rowCount() async =>
      (await db.select(db.lessonProgressTable).get()).length;

  test('two accounts keep their own position in the same session', () async {
    await write('user-a', 'lesson-1', 30.0);
    await write('user-b', 'lesson-1', 90.0);

    expect(await rowCount(), 2, reason: 'one must not overwrite the other');
    expect(await visibleTo('user-a'), [30.0]);
    expect(await visibleTo('user-b'), [90.0]);
  });

  test('positions written before scoping stay visible to everyone', () async {
    await write(kUnownedOwner, 'lesson-legacy', 12.0);
    await write('user-a', 'lesson-1', 30.0);

    expect(await visibleTo('user-a'), [12.0, 30.0]);
    expect(await visibleTo('user-b'), [12.0]);
  });

  test('signing out deletes nothing; it only changes what is visible',
      () async {
    OwnerScope.instance.debugReset(withResolver: () => 'user-a');
    await write(OwnerScope.instance.current, 'lesson-1', 30.0);

    OwnerScope.instance.resolver = () => null;
    expect(OwnerScope.instance.current, 'user-a',
        reason: 'a write still settling belongs to the departing account');
    expect(await rowCount(), 1, reason: 'sign-out must delete no user data');

    OwnerScope.instance.debugReset(withResolver: () => 'user-b');
    expect(await visibleTo(OwnerScope.instance.current), isEmpty);
    expect(await rowCount(), 1);

    OwnerScope.instance.debugReset(withResolver: () => 'user-a');
    expect(await visibleTo(OwnerScope.instance.current), [30.0]);
  });

  group('migration from a pre-owner file', () {
    setUp(() async {
      await db.customStatement('DROP TABLE lesson_progress_table');
      await db.customStatement(_preOwnerScopeDdl);
      await db.customStatement(
        'INSERT INTO lesson_progress_table '
        '(session_id, "current_timestamp", subtopic_ref, door_open) VALUES '
        "('lesson-1', 30.0, 'sub-1', 0), "
        "('lesson-2', 5.5, 'sub-2', 1)",
      );
    });

    test('adds owner, keeps every row, and leaves them unowned', () async {
      expect(await ensureReplayOwnerScopeColumns(db),
          ['lesson_progress_table']);

      final rows = await db.select(db.lessonProgressTable).get();
      expect(rows.map((r) => r.sessionId).toList()..sort(),
          ['lesson-1', 'lesson-2']);
      expect(rows.every((r) => r.owner == kUnownedOwner), isTrue);
      expect(await visibleTo('user-a'), [5.5, 30.0]);
    });

    test('owner joins the key, so a second account no longer overwrites',
        () async {
      await ensureReplayOwnerScopeColumns(db);
      await write('user-a', 'lesson-1', 99.0);
      expect(await rowCount(), 3);
    });

    test('is idempotent and leaves no scratch table behind', () async {
      await ensureReplayOwnerScopeColumns(db);
      expect(await ensureReplayOwnerScopeColumns(db), isEmpty);

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('lesson_progress_table'));
      expect(names, isNot(contains('lesson_progress_table_pre_owner_scope')));
      expect(await rowCount(), 2);
    });

    test('does nothing to a table that is simply absent', () async {
      await db.customStatement('DROP TABLE lesson_progress_table');
      expect(await ensureReplayOwnerScopeColumns(db), isEmpty);
    });
  });

  test('downloaded_assets_table is deliberately not scoped', () async {
    // It indexes files on the device's own disk. The files are shared, so
    // the index of them has to be; scoping it would re-download bytes that
    // are already there and orphan the first account's files.
    expect(
        db.downloadedAssetsTable.columnsByName.keys, isNot(contains('owner')));
  });
}
