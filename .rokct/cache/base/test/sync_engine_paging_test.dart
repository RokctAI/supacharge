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

// drift exports `isNull`/`isNotNull` as SQL expression builders, which
// collide by name with matcher's `isNull`/`isNotNull` that `expect` needs
// here. Neither drift name is used in this file, so hiding them resolves
// the ambiguity without losing anything.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/database/app_database.dart';
import 'package:base_sdk/src/sync/outbox_table.dart';
import 'package:base_sdk/src/sync/sync_engine.dart';
import 'package:base_sdk/src/sync/sync_handler.dart';

/// Records the order ops were pushed in and replies with a scripted result.
class RecordingHandler extends SyncHandler {
  RecordingHandler(this.reply);

  /// Op id -> the result to return for it. Anything unlisted syncs cleanly.
  final Map<String, SyncResult> reply;

  final List<String> pushed = <String>[];
  final List<String> pushedPayloads = <String>[];

  @override
  Future<SyncResult> push(OutboxEntry op) async {
    pushed.add(op.id);
    pushedPayloads.add(op.payload);
    return reply[op.id] ?? const SyncResult.synced();
  }
}

/// The drain and the temp-id rewrite used to materialise whole tables. They
/// now page. These lock the four behaviours that had to survive: oldest-first
/// ordering, dependsOn gating, the idempotency-key (dedupe) contract, and the
/// temp-id rewrite.
void main() {
  late AppDatabase db;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.debugOverrideInstance(db);
    SyncEngine.debugReset();
    engine = SyncEngine();
    // Force multi-page paths on tiny fixtures.
    engine.pageSize = 2;
  });

  tearDown(() async {
    SyncEngine.debugReset();
    AppDatabase.debugOverrideInstance(null);
    try {
      await db.close();
    } catch (_) {}
  });

  Future<void> queue(
    String id, {
    String opType = 'demo.op',
    Map<String, dynamic> payload = const <String, dynamic>{},
    List<String> tempIds = const <String>[],
    List<String> dependsOn = const <String>[],
  }) {
    return engine.enqueue(
      id: id,
      opType: opType,
      sdk: 'test_sdk',
      payload: payload,
      tempIds: tempIds,
      dependsOn: dependsOn,
    );
  }

  Future<OutboxEntry?> row(String id) {
    return (db.select(db.outboxTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  test('drains every pending op oldest first, across pages', () async {
    for (var i = 1; i <= 5; i++) {
      await queue('op-${i.toString().padLeft(2, '0')}');
    }
    final handler = RecordingHandler(const <String, SyncResult>{});
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    expect(handler.pushed, <String>[
      'op-01', 'op-02', 'op-03', 'op-04', 'op-05',
    ]);
    // Synced ops are deleted from the outbox.
    expect(await db.select(db.outboxTable).get(), isEmpty);
  });

  test('an op with no registered handler is left pending, not skipped over',
      () async {
    await queue('op-01', opType: 'other.op');
    await queue('op-02');
    await queue('op-03');
    final handler = RecordingHandler(const <String, SyncResult>{});
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    expect(handler.pushed, <String>['op-02', 'op-03']);
    expect((await row('op-01'))?.status, OutboxStatus.pending.name);
  });

  test('a dependency still in the outbox blocks its dependent', () async {
    await queue('op-01');
    await queue('op-02', dependsOn: <String>['op-01']);
    await queue('op-03', dependsOn: <String>['op-01']);
    final handler = RecordingHandler(const <String, SyncResult>{
      'op-01': SyncResult.rejected('nope'),
    });
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    // op-01 stays as failed, so both dependents are held back.
    expect(handler.pushed, <String>['op-01']);
    expect((await row('op-01'))?.status, OutboxStatus.failed.name);
    expect((await row('op-02'))?.status, OutboxStatus.pending.name);
    expect((await row('op-03'))?.status, OutboxStatus.pending.name);
  });

  test('a dependency that syncs earlier in the same page unblocks its '
      'dependent', () async {
    await queue('op-01');
    await queue('op-02', dependsOn: <String>['op-01']);
    final handler = RecordingHandler(const <String, SyncResult>{});
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    expect(handler.pushed, <String>['op-01', 'op-02']);
  });

  test('a dependency that syncs in an earlier page unblocks a dependent in a '
      'later page', () async {
    // pageSize is 2, so op-04 is read only after op-01 has already synced.
    await queue('op-01');
    await queue('op-02');
    await queue('op-03');
    await queue('op-04', dependsOn: <String>['op-01']);
    final handler = RecordingHandler(const <String, SyncResult>{});
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    expect(handler.pushed, <String>['op-01', 'op-02', 'op-03', 'op-04']);
    expect(await db.select(db.outboxTable).get(), isEmpty);
  });

  test('an op depending on itself is not blocked by itself', () async {
    await queue('op-01', dependsOn: <String>['op-01']);
    final handler = RecordingHandler(const <String, SyncResult>{});
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    expect(handler.pushed, <String>['op-01']);
  });

  test('an op inside its backoff window is skipped without blocking the rest',
      () async {
    await queue('op-01');
    await queue('op-02');
    await (db.update(db.outboxTable)..where((t) => t.id.equals('op-01')))
        .write(
      OutboxTableCompanion(
        nextAttemptAt: Value(DateTime.now().add(const Duration(hours: 1))),
      ),
    );
    final handler = RecordingHandler(const <String, SyncResult>{});
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    expect(handler.pushed, <String>['op-02']);
    expect((await row('op-01'))?.status, OutboxStatus.pending.name);
  });

  test('a retryable failure backs the op off instead of killing it', () async {
    await queue('op-01');
    final handler = RecordingHandler(const <String, SyncResult>{
      'op-01': SyncResult.retryable('boom'),
    });
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    final stored = await row('op-01');
    expect(stored?.status, OutboxStatus.pending.name);
    expect(stored?.attempts, 1);
    expect(stored?.lastError, 'boom');
    expect(stored?.nextAttemptAt, isNotNull);
  });

  test('the temp-id rewrite reaches pending ops beyond the first page',
      () async {
    await queue(
      'op-01',
      tempIds: <String>['offline:t1'],
      payload: <String, dynamic>{'self': true},
    );
    for (var i = 2; i <= 5; i++) {
      await queue(
        'op-${i.toString().padLeft(2, '0')}',
        payload: <String, dynamic>{'parent': 'offline:t1'},
      );
    }
    // Only op-01 syncs; everything else stays put so the stored payloads can
    // be inspected after the pass.
    final handler = RecordingHandler(<String, SyncResult>{
      'op-01': const SyncResult.synced(
        idMappings: <String, String>{'offline:t1': 'server-1'},
        entityType: 'demo',
      ),
      for (var i = 2; i <= 5; i++)
        'op-${i.toString().padLeft(2, '0')}': const SyncResult.retryable('hold'),
    });
    engine.registerHandler('demo.op', handler);

    await engine.kick();

    for (var i = 2; i <= 5; i++) {
      final stored = await row('op-${i.toString().padLeft(2, '0')}');
      final payload = jsonDecode(stored!.payload) as Map<String, dynamic>;
      expect(
        payload['parent'],
        'server-1',
        reason: 'op-$i should have had its temp id rewritten',
      );
    }

    // The mapping is also recorded for later lookups.
    final mapping = await (db.select(db.idMappingsTable)
          ..where((t) => t.tempId.equals('offline:t1')))
        .getSingleOrNull();
    expect(mapping?.backendId, 'server-1');
    expect(mapping?.entityType, 'demo');
  });

  test('enqueueOrReplace keeps one row per dedupe key and resets its retry '
      'state', () async {
    final first = await engine.enqueueOrReplace(
      opType: 'cart.sync',
      sdk: 'test_sdk',
      dedupeKey: 'cart-9',
      payload: <String, dynamic>{'v': 1},
    );
    expect(first, 'cart.sync:cart-9');

    // Simulate a failed attempt before the newer snapshot arrives.
    await (db.update(db.outboxTable)..where((t) => t.id.equals(first))).write(
      OutboxTableCompanion(
        status: const Value('failed'),
        attempts: const Value(3),
        lastError: const Value('stale'),
      ),
    );

    final second = await engine.enqueueOrReplace(
      opType: 'cart.sync',
      sdk: 'test_sdk',
      dedupeKey: 'cart-9',
      payload: <String, dynamic>{'v': 2},
    );
    expect(second, first);

    final rows = await db.select(db.outboxTable).get();
    expect(rows, hasLength(1));
    expect(jsonDecode(rows.single.payload), <String, dynamic>{'v': 2});
    expect(rows.single.status, OutboxStatus.pending.name);
    expect(rows.single.attempts, 0);
    expect(rows.single.lastError, isNull);
    expect(rows.single.nextAttemptAt, isNull);
  });

  test('hasPending and parkedOps still see a paged outbox', () async {
    await queue('op-01');
    await queue('op-02');
    expect(await engine.hasPending('demo.op'), isTrue);
    expect(await engine.hasPending('other.op'), isFalse);

    final handler = RecordingHandler(const <String, SyncResult>{
      'op-01': SyncResult.rejected('bad'),
    });
    engine.registerHandler('demo.op', handler);
    await engine.kick();

    final parked = await engine.parkedOps();
    expect(parked.map((op) => op.id).toList(), <String>['op-01']);
  });

  test('an empty outbox drains without touching a handler', () async {
    final handler = RecordingHandler(const <String, SyncResult>{});
    engine.registerHandler('demo.op', handler);
    await engine.kick();
    expect(handler.pushed, isEmpty);
  });
}
