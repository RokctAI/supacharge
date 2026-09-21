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

// Owner scoping for assistant_history_table: two accounts on one device do
// not read each other's transcripts, rows written before scoping stay
// visible to everyone, signing out destroys nothing, and a file that
// predates the owner column migrates without losing a message.
//
// The table lives in base_sdk's composed AppDatabase in a real app, which
// has no generated accessors here, so these drive an equivalent generated
// database of this SDK's own tables. Same table definition, same migration
// helper, same visibility predicate.

import 'package:agent_sdk/src/common/infrastructure/database/drift_tables.dart';
import 'package:base_sdk/base_sdk.dart' show OwnerScope, kUnownedOwner, ownerVisible;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

part 'assistant_history_owner_scope_test.g.dart';

@DriftDatabase(tables: [AssistantCacheTable, AssistantHistoryTable])
class OwnerScopeTestDatabase extends _$OwnerScopeTestDatabase {
  OwnerScopeTestDatabase(super.executor);

  @override
  int get schemaVersion => 21;
}

/// The table exactly as it stood before this change: no `owner`, `id` alone
/// as the key. Seeding this and then running the migration is the on-device
/// upgrade path.
const String _preOwnerScopeDdl = '''
CREATE TABLE assistant_history_table (
  id TEXT NOT NULL,
  session TEXT NOT NULL,
  sender TEXT NOT NULL,
  message TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  PRIMARY KEY (id)
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

  Future<void> write(String owner, String id, String message) {
    return db.into(db.assistantHistoryTable).insertOnConflictUpdate(
          AssistantHistoryTableCompanion.insert(
            id: id,
            session: 's1',
            sender: 'user',
            message: message,
            timestamp: DateTime.utc(2026, 1, 1),
            owner: Value(owner),
          ),
        );
  }

  Future<List<String>> visibleTo(String owner) async {
    final rows = await (db.select(db.assistantHistoryTable)
          ..where((t) => ownerVisible(t.owner, owner)))
        .get();
    return rows.map((r) => r.message).toList()..sort();
  }

  Future<int> rowCount() async {
    final rows = await db.select(db.assistantHistoryTable).get();
    return rows.length;
  }

  test('two accounts on one device do not see each other messages', () async {
    await write('user-a', 'm1', 'a asked something');
    await write('user-b', 'm2', 'b asked something else');

    expect(await visibleTo('user-a'), ['a asked something']);
    expect(await visibleTo('user-b'), ['b asked something else']);
  });

  test('the same message id under two owners is two rows, not one', () async {
    // The whole reason owner is IN the key: an offline id is minted from the
    // clock, so two accounts can collide on it. Before scoping the second
    // write silently replaced the first account's message.
    await write('user-a', 'shared-id', 'from a');
    await write('user-b', 'shared-id', 'from b');

    expect(await rowCount(), 2);
    expect(await visibleTo('user-a'), ['from a']);
    expect(await visibleTo('user-b'), ['from b']);
  });

  test('rows written before scoping stay visible to everyone', () async {
    await write(kUnownedOwner, 'legacy', 'written before owner existed');
    await write('user-a', 'm1', 'a asked something');

    expect(await visibleTo('user-a'),
        ['a asked something', 'written before owner existed']);
    expect(await visibleTo('user-b'), ['written before owner existed']);
    expect(await visibleTo(kUnownedOwner), ['written before owner existed']);
  });

  test('signing out deletes nothing; it only changes what is visible',
      () async {
    OwnerScope.instance.debugReset(withResolver: () => 'user-a');
    await write(OwnerScope.instance.current, 'm1', 'a asked something');
    expect(await rowCount(), 1);

    // Sign-out: the resolver stops naming anyone. OwnerScope keeps the
    // departing account for writes still in flight, so the row is not
    // orphaned into the unowned set where the next account would read it.
    OwnerScope.instance.resolver = () => null;
    expect(OwnerScope.instance.current, 'user-a');
    expect(await rowCount(), 1, reason: 'sign-out must delete no user data');

    // The next account signs in and sees an empty history, with the first
    // account's messages still on disk.
    OwnerScope.instance.debugReset(withResolver: () => 'user-b');
    expect(await visibleTo(OwnerScope.instance.current), isEmpty);
    expect(await rowCount(), 1);

    // ...and the first account gets all of it back on the way in.
    OwnerScope.instance.debugReset(withResolver: () => 'user-a');
    expect(await visibleTo(OwnerScope.instance.current),
        ['a asked something']);
  });

  group('migration from a pre-owner file', () {
    setUp(() async {
      await db.customStatement('DROP TABLE assistant_history_table');
      await db.customStatement(_preOwnerScopeDdl);
      await db.customStatement(
        'INSERT INTO assistant_history_table '
        '(id, session, sender, message, timestamp) VALUES '
        "('m1', 's1', 'user', 'kept', 0), "
        "('m2', 's1', 'bot', 'also kept', 0)",
      );
    });

    test('adds owner, keeps every row, and leaves them unowned', () async {
      expect(await ensureAgentOwnerScopeColumns(db),
          ['assistant_history_table']);

      final rows = await db.select(db.assistantHistoryTable).get();
      expect(rows.map((r) => r.message).toList()..sort(), ['also kept', 'kept']);
      expect(rows.every((r) => r.owner == kUnownedOwner), isTrue);
      // Unowned is the state the visibility rule treats as everyone's, so
      // the upgrade is invisible to the account already using the app.
      expect(await visibleTo('user-a'), ['also kept', 'kept']);
    });

    test('owner joins the key, so the id collision no longer overwrites',
        () async {
      await ensureAgentOwnerScopeColumns(db);
      await write('user-a', 'm1', 'from a');
      expect(await rowCount(), 3);
    });

    test('is idempotent and leaves a scratch table behind nowhere', () async {
      await ensureAgentOwnerScopeColumns(db);
      expect(await ensureAgentOwnerScopeColumns(db), isEmpty);

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('assistant_history_table'));
      expect(names,
          isNot(contains('assistant_history_table_pre_owner_scope')));
      expect(await rowCount(), 2);
    });

    test('does nothing to a table that is simply absent', () async {
      await db.customStatement('DROP TABLE assistant_history_table');
      expect(await ensureAgentOwnerScopeColumns(db), isEmpty);
    });
  });

  test('assistant_cache_table is deliberately not scoped', () async {
    // Content, not a record of who asked. Asserted so a later change has to
    // be deliberate about it.
    expect(db.assistantCacheTable.columnsByName.keys, isNot(contains('owner')));
  });
}
