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

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/database/app_database.dart';
import 'package:base_sdk/src/database/owner_scope.dart';
import 'package:base_sdk/src/sync/outbox_table.dart';
import 'package:base_sdk/src/sync/sync_engine.dart';
import 'package:base_sdk/src/sync/sync_handler.dart';

/// Records what it was handed and reports it synced.
class _RecordingHandler implements SyncHandler {
  final List<String> pushed = <String>[];

  @override
  Future<SyncResult> push(OutboxEntry op) async {
    pushed.add(op.id);
    return const SyncResult.synced();
  }

  @override
  Future<void> onSynced(OutboxEntry op, Map<String, String> idMappings) async {}
}

/// Reports the op synced and hands back the temp-identity -> backend-identity
/// mapping an offline registration resolves to.
class _IdentityResolvingHandler implements SyncHandler {
  _IdentityResolvingHandler(this.tempIdentity, this.backendIdentity);

  final String tempIdentity;
  final String backendIdentity;

  @override
  Future<SyncResult> push(OutboxEntry op) async => SyncResult.synced(
        idMappings: <String, String>{tempIdentity: backendIdentity},
        entityType: 'user',
      );

  @override
  Future<void> onSynced(OutboxEntry op, Map<String, String> idMappings) async {}
}

/// Owner scoping, end to end against a real database.
///
/// The ruling this encodes: sign-out never deletes anything, an existing row
/// with no owner counts as the current user's, and two accounts on one device
/// cannot see - or overwrite - each other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  String? owner;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.debugOverrideInstance(db);
    owner = null;
    OwnerScope.instance.debugReset(withResolver: () => owner);
    SyncEngine.debugReset();
  });

  tearDown(() async {
    OwnerScope.instance.debugReset();
    AppDatabase.debugOverrideInstance(null);
    SyncEngine.debugReset();
    await db.close();
  });

  /// Sign [who] in for everything that follows; null means nobody.
  void signedInAs(String? who) {
    owner = who;
    OwnerScope.instance.debugRemember(null);
  }

  Future<List<String>> ownersIn(String box, String key) async {
    final rows = await (db.select(db.keyValueTable)
          ..where((t) => t.box.equals(box) & t.id.equals(key))
          ..orderBy([(t) => OrderingTerm.asc(t.owner)]))
        .get();
    return rows.map((KeyValueEntity r) => r.owner).toList();
  }

  group('the JSON document store', () {
    test('two accounts hold the same box and key side by side', () async {
      signedInAs('user-a');
      await db.putItem('settings', 'theme', {'mode': 'dark'});
      signedInAs('user-b');
      await db.putItem('settings', 'theme', {'mode': 'light'});

      // Two rows, not one overwritten one - the collision the widened primary
      // key exists to allow.
      expect(await ownersIn('settings', 'theme'), ['user-a', 'user-b']);

      expect(await db.getItem('settings', 'theme'), {'mode': 'light'});
      signedInAs('user-a');
      expect(await db.getItem('settings', 'theme'), {'mode': 'dark'});
    });

    test('a second write by the same account still updates in place', () async {
      signedInAs('user-a');
      await db.putItem('settings', 'theme', {'mode': 'dark'});
      await db.putItem('settings', 'theme', {'mode': 'sepia'});

      // The insertOnConflictUpdate must still find its conflict target after
      // the key widened; a miss would append a second row here and the next
      // read would have two to choose from.
      expect(await ownersIn('settings', 'theme'), ['user-a']);
      expect(await db.getItem('settings', 'theme'), {'mode': 'sepia'});
    });

    test('a row with no owner counts as the current account\'s', () async {
      signedInAs(null);
      await db.putItem('notes', 'n1', {'body': 'written before scoping'});
      expect(await ownersIn('notes', 'n1'), [kUnownedOwner]);

      signedInAs('user-a');
      expect(await db.getItem('notes', 'n1'), {'body': 'written before scoping'});
      expect(await db.getAll('notes'), hasLength(1));
      expect(await db.countBox('notes'), 1);
    });

    test('an unowned row leaves the unowned set when it is next written',
        () async {
      signedInAs(null);
      await db.putItem('notes', 'n1', {'body': 'legacy'});

      signedInAs('user-a');
      await db.putItem('notes', 'n1', {'body': 'edited'});

      // Claimed, not duplicated: one row, owned, and the single-row read has
      // no ambiguity to resolve.
      expect(await ownersIn('notes', 'n1'), ['user-a']);
      expect(await db.getItem('notes', 'n1'), {'body': 'edited'});

      // And it is gone from the next account's view, which is the point.
      signedInAs('user-b');
      expect(await db.getItem('notes', 'n1'), isNull);
    });

    test('a legacy row and an owned row for one key read as the owned one',
        () async {
      // Hand-built: putItem claims the legacy row, so this state can only be
      // reached by writing the rows directly. The read must still not throw.
      await db.into(db.keyValueTable).insert(
            KeyValueTableCompanion.insert(
              box: 'notes',
              id: 'n1',
              data: '{"body":"legacy"}',
            ),
          );
      await db.into(db.keyValueTable).insert(
            KeyValueTableCompanion.insert(
              box: 'notes',
              id: 'n1',
              data: '{"body":"mine"}',
              owner: const Value('user-a'),
            ),
          );

      signedInAs('user-a');
      expect(await db.getItem('notes', 'n1'), {'body': 'mine'});
    });

    test('paged and counted reads are scoped as well', () async {
      signedInAs('user-a');
      await db.putItem('notes', 'n1', {'body': 'a1'});
      await db.putItem('notes', 'n2', {'body': 'a2'});
      signedInAs('user-b');
      await db.putItem('notes', 'n3', {'body': 'b1'});

      expect(await db.countBox('notes'), 1);
      expect(await db.getAll('notes'), [
        {'body': 'b1', 'id': 'n3'},
      ]);
      expect(await db.getPage('notes'), hasLength(1));

      signedInAs('user-a');
      expect(await db.countBox('notes'), 2);
      expect(await db.getAll('notes'), hasLength(2));
    });

    test('signing out and back in finds the work again', () async {
      // The temp-local account of the ruling: real work, a sign-out, a return.
      signedInAs('offline:1789234000000123');
      await db.putItem('tasks', 't1', {'title': 'fit the softener'});

      signedInAs(null); // signed out
      signedInAs('offline:1789234000000123'); // and back

      expect(await db.getItem('tasks', 't1'), {'title': 'fit the softener'});
    });

    test('clearBox empties only the caller\'s rows', () async {
      signedInAs('user-a');
      await db.putItem('notes', 'n1', {'body': 'a1'});
      signedInAs(null);
      await db.putItem('notes', 'legacy', {'body': 'nobody\'s'});
      signedInAs('user-b');
      await db.putItem('notes', 'n2', {'body': 'b1'});

      // What a session-end hook calls. Before the owner existed it emptied
      // the box for every account that had ever used the device.
      expect(await db.clearBox('notes'), 2); // b's row and the unowned one

      signedInAs('user-a');
      expect(await db.getItem('notes', 'n1'), {'body': 'a1'});
    });

    test('deleteItem leaves the other account\'s row alone', () async {
      signedInAs('user-a');
      await db.putItem('settings', 'theme', {'mode': 'dark'});
      signedInAs('user-b');
      await db.putItem('settings', 'theme', {'mode': 'light'});

      await db.deleteItem('settings', 'theme');

      expect(await ownersIn('settings', 'theme'), ['user-a']);
    });
  });

  group('the outbox', () {
    test('a drain pushes only the current account\'s ops', () async {
      final engine = SyncEngine();
      final handler = _RecordingHandler();
      engine.registerHandler('order.create', handler);

      signedInAs('user-a');
      final a = await engine.enqueue(
        opType: 'order.create',
        sdk: 'orders_sdk',
        payload: <String, dynamic>{'from': 'a'},
      );
      signedInAs('user-b');
      final b = await engine.enqueue(
        opType: 'order.create',
        sdk: 'orders_sdk',
        payload: <String, dynamic>{'from': 'b'},
      );

      await engine.kick();

      // The whole defect in one assertion: A's queued mutation must not go out
      // under B's session.
      expect(handler.pushed, <String>[b]);
      final left = await db.select(db.outboxTable).get();
      expect(left.map((OutboxEntry e) => e.id), <String>[a]);
    });

    test('an op queued before scoping still drains for whoever is here',
        () async {
      final engine = SyncEngine();
      final handler = _RecordingHandler();
      engine.registerHandler('order.create', handler);

      signedInAs(null);
      final legacy = await engine.enqueue(
        opType: 'order.create',
        sdk: 'orders_sdk',
        payload: <String, dynamic>{},
      );

      signedInAs('user-b');
      await engine.kick();

      expect(handler.pushed, <String>[legacy]);
    });

    test('enqueueOrReplace coalesces per account, not per device', () async {
      final engine = SyncEngine();

      signedInAs('user-a');
      await engine.enqueueOrReplace(
        opType: 'cart.sync',
        sdk: 'orders_sdk',
        dedupeKey: 'shop-7',
        payload: <String, dynamic>{'items': 1},
      );
      signedInAs('user-b');
      final id = await engine.enqueueOrReplace(
        opType: 'cart.sync',
        sdk: 'orders_sdk',
        dedupeKey: 'shop-7',
        payload: <String, dynamic>{'items': 2},
      );

      // Same deterministic id, two accounts: two rows, and A's snapshot is
      // untouched.
      expect(id, 'cart.sync:shop-7');
      final rows = await (db.select(db.outboxTable)
            ..where((t) => t.id.equals(id))
            ..orderBy([(t) => OrderingTerm.asc(t.owner)]))
          .get();
      expect(rows.map((OutboxEntry e) => e.owner), <String>['user-a', 'user-b']);
      expect(rows.first.payload, contains('"items":1'));
      expect(rows.last.payload, contains('"items":2'));
    });

    test('hasPending, parkedOps, retryOp and deleteOp are all scoped',
        () async {
      final engine = SyncEngine();

      signedInAs('user-a');
      final a = await engine.enqueue(
        opType: 'order.create',
        sdk: 'orders_sdk',
        payload: <String, dynamic>{},
      );
      await (db.update(db.outboxTable)
            ..where((t) => t.id.equals(a) & t.owner.equals('user-a')))
          .write(OutboxTableCompanion(status: Value(OutboxStatus.failed.name)));

      signedInAs('user-b');
      expect(await engine.hasPending('order.create'), isFalse);
      expect(await engine.parkedOps(), isEmpty);
      expect(await engine.retryOp(a), isFalse);
      expect(await engine.deleteOp(a), isFalse);

      signedInAs('user-a');
      expect(await engine.parkedOps(), hasLength(1));
      expect(await engine.deleteOp(a), isTrue);
    });
  });

  group('adoptOwner', () {
    test('carries a temp-local account\'s rows over to its backend identity',
        () async {
      signedInAs('offline:1789234000000123');
      await db.putItem('tasks', 't1', {'title': 'fit the softener'});
      await SyncEngine().enqueue(
        opType: 'task.create',
        sdk: 'productivity_sdk',
        payload: <String, dynamic>{},
      );

      final moved = await db.adoptOwner('offline:1789234000000123', '4217');
      expect(moved, 2);

      // The account the backend now calls 4217 still sees its own work.
      signedInAs('4217');
      expect(await db.getItem('tasks', 't1'), {'title': 'fit the softener'});
      expect(await SyncEngine().hasPending('task.create'), isTrue);

      signedInAs('offline:1789234000000123');
      expect(await db.getItem('tasks', 't1'), isNull);
    });

    test('the sync engine adopts when a temp-local identity resolves',
        () async {
      final engine = SyncEngine();
      engine.registerHandler(
        'auth.register',
        _IdentityResolvingHandler('offline:1789234000000123', '4217'),
      );

      signedInAs('offline:1789234000000123');
      await db.putItem('tasks', 't1', {'title': 'fit the softener'});
      await engine.enqueue(
        opType: 'auth.register',
        sdk: 'auth_sdk',
        payload: <String, dynamic>{},
      );

      await engine.kick();

      signedInAs('4217');
      expect(await db.getItem('tasks', 't1'), {'title': 'fit the softener'});
    });

    test('never promotes unowned rows to an owner', () async {
      signedInAs(null);
      await db.putItem('notes', 'n1', {'body': 'legacy'});

      expect(await db.adoptOwner(kUnownedOwner, '4217'), 0);
      expect(await db.adoptOwner('4217', kUnownedOwner), 0);
      expect(await ownersIn('notes', 'n1'), [kUnownedOwner]);
    });
  });
}
