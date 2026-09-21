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


// compliance-ignore-file: flutter-http-timeout (test double: Dio uses a scripted in-memory adapter, no real network)

import 'dart:convert';
import 'dart:typed_data';

import 'package:base_sdk/base_sdk.dart'
    show HttpService, OutboxEntry, OutboxStatus, SyncHandler, SyncRejected,
        SyncRetryable, SyncSynced, getIt, kPlatformGatewayPath;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/src/common/infrastructure/repositories/http_lms_repository.dart';
import 'package:lms_sdk/src/common/infrastructure/sync/lms_upload_queue.dart';
import 'package:lms_sdk/src/common/presentation/widgets/pending_sync_notice.dart';

/// In-memory [LmsUploadOutbox] mirroring the contract of base_sdk's
/// SyncEngine + outbox table the production `SyncEngineLmsOutbox` delegates
/// to: FIFO drain of pending ops, `(opType, dedupeKey)` replace semantics
/// with the deterministic `<opType>:<dedupeKey>` id, attempt counting with a
/// `dead` park after [maxAttempts] retryable failures, and `failed` on
/// rejection. Lets the queue's routing/ordering/surfacing logic run without
/// a database file (same seam pattern as `ScheduleStore`).
class InMemoryOutbox implements LmsUploadOutbox {
  final List<_Op> ops = [];
  final Map<String, SyncHandler> handlers = {};
  int nextSeq = 0;
  int maxAttempts;

  InMemoryOutbox({this.maxAttempts = 10});

  @override
  Future<void> enqueue({
    required String opType,
    required Map<String, dynamic> payload,
  }) async {
    ops.add(_Op('op-${nextSeq++}', opType, jsonEncode(payload)));
  }

  @override
  Future<void> enqueueOrReplace({
    required String opType,
    required String dedupeKey,
    required Map<String, dynamic> payload,
  }) async {
    // compliance-ignore: flutter-hardcoded-secret (outbox dedupe id in a test fake, not a credential)
    final id = '$opType:$dedupeKey';
    final existing = ops.where((o) => o.id == id).firstOrNull;
    if (existing == null) {
      ops.add(_Op(id, opType, jsonEncode(payload)));
      return;
    }
    // Latest snapshot wins; retry state resets (SyncEngine.enqueueOrReplace).
    existing.payload = jsonEncode(payload);
    existing.status = OutboxStatus.pending;
    existing.attempts = 0;
  }

  @override
  Future<bool> hasPendingFor(String opType, String recordKey) async {
    return ops.any((o) =>
        o.opType == opType &&
        (jsonDecode(o.payload) as Map)['record'] == recordKey);
  }

  @override
  Future<LmsUploadStatus> counts() async {
    var pending = 0;
    var parked = 0;
    for (final o in ops) {
      if (o.status == OutboxStatus.failed || o.status == OutboxStatus.dead) {
        parked++;
      } else {
        pending++;
      }
    }
    return LmsUploadStatus(pending: pending, parked: parked);
  }

  @override
  Future<List<String>> parkedLmsOps() async => [
        for (final o in ops)
          if (o.status == OutboxStatus.failed || o.status == OutboxStatus.dead)
            o.id,
      ];

  @override
  Future<void> retryOp(String opId) async {
    final op = ops.where((o) => o.id == opId).firstOrNull;
    if (op == null) return;
    op.status = OutboxStatus.pending;
    op.attempts = 0;
  }

  @override
  Future<void> kick() async {
    // Oldest-first drain, one pass (SyncEngine._drainOnce).
    for (final op in List.of(ops)) {
      if (op.status != OutboxStatus.pending) continue;
      final handler = handlers[op.opType];
      if (handler == null) continue;
      final result = await handler.push(op.toEntry());
      switch (result) {
        case SyncSynced():
          await handler.onSynced(op.toEntry(), const {});
          ops.remove(op);
        case SyncRetryable():
          op.attempts++;
          op.status = op.attempts >= maxAttempts
              ? OutboxStatus.dead
              : OutboxStatus.pending;
        case SyncRejected():
          op.attempts++;
          op.status = OutboxStatus.failed;
      }
    }
  }

  @override
  void registerHandler(String opType, SyncHandler handler) {
    handlers[opType] = handler;
  }
}

class _Op {
  final String id;
  final String opType;
  String payload;
  OutboxStatus status = OutboxStatus.pending;
  int attempts = 0;

  _Op(this.id, this.opType, this.payload);

  OutboxEntry toEntry() => OutboxEntry(
        id: id,
        opType: opType,
        sdk: LmsUploadQueue.sdkName,
        payload: payload,
        tempIds: '[]',
        dependsOn: '[]',
        status: status.name,
        attempts: attempts,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
}

Map<String, dynamic> _body(_Op op) =>
    Map<String, dynamic>.from((jsonDecode(op.payload) as Map)['body'] as Map);

DioException _http(int code) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
          requestOptions: RequestOptions(path: '/x'), statusCode: code),
      type: DioExceptionType.badResponse,
    );

DioException _network() => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );

/// [HttpService] whose Dio answers every request from [handle] — lets the
/// REAL request paths (repository direct POSTs and the handler's default
/// `_dioPost`) run against a scripted backend, capturing the actual wire
/// headers. Same substitution seam production uses (`getIt<HttpService>`).
class _FakeHttpService implements HttpService {
  _FakeHttpService(this.handle);

  final ResponseBody Function(RequestOptions options) handle;

  @override
  Dio client({bool requireAuth = false, bool routing = false}) =>
      Dio(BaseOptions(baseUrl: 'https://unit.test'))
        ..httpClientAdapter = _ScriptedAdapter(handle);
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handle);

  final ResponseBody Function(RequestOptions options) handle;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      handle(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  group('LmsUploadQueue enqueue-on-failure', () {
    test('queueSaveProgress persists opType, record key and request body',
        () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);

      await queue.queueSaveProgress('LESSON-1', isComplete: true);

      expect(outbox.ops, hasLength(1));
      final op = outbox.ops.single;
      expect(op.opType, LmsUploadQueue.opSaveProgress);
      // Persistence round-trip: the payload JSON decodes back to the exact
      // request body the handler will POST.
      final decoded = jsonDecode(op.payload) as Map;
      expect(decoded['record'], 'LESSON-1');
      expect(decoded['body'], {'lesson': 'LESSON-1', 'is_complete': 1});
      expect(queue.status.value, const LmsUploadStatus(pending: 1));
    });

    test('event ops append; snapshot ops coalesce', () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);

      await queue.queueVideoWatch(
          lesson: 'L1', source: 'lesson', watchTimeSeconds: 10);
      await queue.queueVideoWatch(
          lesson: 'L1', source: 'lesson', watchTimeSeconds: 20);
      await queue.queueSaveProgress('L1');
      await queue.queueSaveProgress('L1', isComplete: false);

      final watches = outbox.ops
          .where((o) => o.opType == LmsUploadQueue.opVideoWatch)
          .toList();
      final saves = outbox.ops
          .where((o) => o.opType == LmsUploadQueue.opSaveProgress)
          .toList();
      // Watch-time increments both survive, in order.
      expect(watches, hasLength(2));
      expect(_body(watches[0])['watch_time'], 10);
      expect(_body(watches[1])['watch_time'], 20);
      // Progress snapshots coalesced — latest wins.
      expect(saves, hasLength(1));
      expect(_body(saves.single)['is_complete'], 0);
    });

    test('a newer queued grade supersedes the older one and resets retries',
        () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);

      await queue.queueSetGrade(10);
      outbox.ops.single.attempts = 3; // pretend some retries failed
      await queue.queueSetGrade(11);

      expect(outbox.ops, hasLength(1));
      expect(_body(outbox.ops.single)['grade'], 11);
      expect(outbox.ops.single.attempts, 0);
    });
  });

  group('per-record ordering (defer)', () {
    test('defer is a no-op while nothing is queued for the record', () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);

      expect(await queue.deferSaveProgress('L1'), isFalse);
      expect(await queue.deferSetGrade(9), isFalse);
      expect(
          await queue.deferAttendanceEvent(
              sessionId: 'S1', body: {'session_id': 'S1'}),
          isFalse);
      expect(outbox.ops, isEmpty);
    });

    test('a write for a record with a queued op routes behind it', () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);

      await queue.queueAttendanceEvent(
          sessionId: 'S1', body: {'session_id': 'S1', 'outcome': 'Attended'});
      final deferred = await queue.deferAttendanceEvent(
          sessionId: 'S1',
          body: {'session_id': 'S1', 'outcome': 'Attended', 'data_used_mb': 4});

      expect(deferred, isTrue);
      final events = outbox.ops
          .where((o) => o.opType == LmsUploadQueue.opAttendanceEvent)
          .toList();
      expect(events, hasLength(2));
      // Original order preserved: join event first, completion event second.
      expect(_body(events[0]).containsKey('data_used_mb'), isFalse);
      expect(_body(events[1])['data_used_mb'], 4);

      // A different record is unaffected.
      expect(
          await queue.deferAttendanceEvent(
              sessionId: 'S2', body: {'session_id': 'S2'}),
          isFalse);
    });

    test('deferred snapshot supersedes the queued one', () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);

      await queue.queueSetGrade(10);
      expect(await queue.deferSetGrade(12), isTrue);

      expect(outbox.ops, hasLength(1));
      expect(_body(outbox.ops.single)['grade'], 12);
    });
  });

  group('drain', () {
    test('successful push posts the stored body to the right alias and '
        'removes the op', () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);
      final posts = <(String, Map<String, dynamic>)>[];
      final handler = LmsUploadSyncHandler(
        post: (alias, body, _) async => posts.add((alias, body)),
        onSyncedOp: (_) => queue.refreshStatus(),
      );
      for (final op in LmsUploadQueue.opTypes) {
        outbox.registerHandler(op, handler);
      }

      await queue.queueSaveProgress('L1');
      await queue.queueVideoWatch(
          lesson: 'L1', source: 'lesson', watchTimeSeconds: 30);
      await queue.queueSetGrade(11);
      expect(queue.status.value.pending, 3);

      await queue.kick();

      expect(outbox.ops, isEmpty);
      expect(queue.status.value, const LmsUploadStatus());
      expect(posts, hasLength(3));
      expect(posts[0].$1, 'save_progress');
      expect(posts[0].$2, {'lesson': 'L1', 'is_complete': 1});
      expect(posts[1].$1, 'record_video_watch');
      expect(posts[1].$2['watch_time'], 30);
      expect(posts[2].$1, 'student_set_grade');
      expect(posts[2].$2, {'grade': 11});
    });

    test('retryable failures keep the op pending; exhaustion parks it and '
        'the status surfaces it', () async {
      final outbox = InMemoryOutbox(maxAttempts: 3);
      final queue = LmsUploadQueue(outbox: outbox);
      final handler = LmsUploadSyncHandler(post: (_, __, ___) => throw _network());
      outbox.registerHandler(LmsUploadQueue.opSaveProgress, handler);

      await queue.queueSaveProgress('L1');
      await queue.kick(); // attempt 1
      expect(queue.status.value, const LmsUploadStatus(pending: 1));
      await queue.kick(); // attempt 2
      await queue.kick(); // attempt 3 -> dead
      expect(queue.status.value, const LmsUploadStatus(parked: 1));

      // Exhausted op re-arms via the notice's tap-to-retry.
      await queue.retryParked();
      expect(queue.status.value, const LmsUploadStatus(pending: 1));
    });

    test('4xx rejection parks the op instead of retrying it', () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);
      final handler = LmsUploadSyncHandler(post: (_, __, ___) => throw _http(417));
      outbox.registerHandler(LmsUploadQueue.opSetGrade, handler);

      await queue.queueSetGrade(9);
      await queue.kick();

      expect(queue.status.value, const LmsUploadStatus(parked: 1));
      expect(outbox.ops.single.status, OutboxStatus.failed);
    });
  });

  group('LmsUploadSyncHandler classification', () {
    OutboxEntry entry([String opType = LmsUploadQueue.opSaveProgress]) =>
        _Op('id-1', opType, jsonEncode({'record': 'L1', 'body': {'lesson': 'L1'}}))
            .toEntry();

    test('success -> synced', () async {
      final h = LmsUploadSyncHandler(post: (_, __, ___) async {});
      expect(await h.push(entry()), isA<SyncSynced>());
    });

    test('5xx / network errors -> retryable', () async {
      expect(
          await LmsUploadSyncHandler(post: (_, __, ___) => throw _http(503))
              .push(entry()),
          isA<SyncRetryable>());
      expect(
          await LmsUploadSyncHandler(post: (_, __, ___) => throw _network())
              .push(entry()),
          isA<SyncRetryable>());
      // Transient 4xx codes stay retryable too.
      expect(
          await LmsUploadSyncHandler(post: (_, __, ___) => throw _http(429))
              .push(entry()),
          isA<SyncRetryable>());
    });

    test('other 4xx -> rejected; unknown op type -> rejected', () async {
      expect(
          await LmsUploadSyncHandler(post: (_, __, ___) => throw _http(403))
              .push(entry()),
          isA<SyncRejected>());
      expect(
          await LmsUploadSyncHandler(post: (_, __, ___) async {})
              .push(entry('lms.not_a_thing')),
          isA<SyncRejected>());
    });
  });

  group('idempotency keys', () {
    String keyOf(_Op op) =>
        (jsonDecode(op.payload) as Map)[LmsUploadQueue.payloadIdempotencyKey]
            as String;

    test('every envelope gets a key and push sends it with the POST',
        () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);
      final sentKeys = <String?>[];
      final handler =
          LmsUploadSyncHandler(post: (_, __, key) async => sentKeys.add(key));
      for (final op in LmsUploadQueue.opTypes) {
        outbox.registerHandler(op, handler);
      }

      await queue.queueVideoWatch(
          lesson: 'L1', source: 'lesson', watchTimeSeconds: 5);
      final envelopeKey = keyOf(outbox.ops.single);
      expect(envelopeKey, isNotEmpty);

      await queue.kick();

      expect(sentKeys, [envelopeKey]);
    });

    test('the key is stable across retries of the same op', () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);
      final sentKeys = <String?>[];
      var failuresLeft = 2;
      final handler = LmsUploadSyncHandler(post: (_, __, key) async {
        sentKeys.add(key);
        if (failuresLeft-- > 0) throw _network();
      });
      outbox.registerHandler(LmsUploadQueue.opQuizResult, handler);

      await queue.queueQuizResult(lesson: 'L1', body: {'lesson': 'L1'});
      final envelopeKey = keyOf(outbox.ops.single);
      await queue.kick(); // attempt 1: fails
      await queue.kick(); // attempt 2: fails
      await queue.kick(); // attempt 3: lands

      expect(outbox.ops, isEmpty);
      // Same payload -> same key on every attempt: the backend can dedupe.
      expect(sentKeys, [envelopeKey, envelopeKey, envelopeKey]);
    });

    test('a coalescing replace mints a fresh key for the new snapshot',
        () async {
      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);

      await queue.queueSetGrade(10);
      final firstKey = keyOf(outbox.ops.single);
      await queue.queueSetGrade(11);

      // Same op id (coalesced), NEW payload -> NEW key, or the backend
      // would replay the stored grade-10 response for the grade-11 save.
      expect(outbox.ops, hasLength(1));
      expect(keyOf(outbox.ops.single), isNot(firstKey));
    });

    test('legacy envelope without a key posts with no header', () async {
      final sentKeys = <String?>[];
      final handler =
          LmsUploadSyncHandler(post: (_, __, key) async => sentKeys.add(key));
      // A row persisted by the previous app version: record + body only.
      final legacy = _Op(
        'id-legacy',
        LmsUploadQueue.opSaveProgress,
        jsonEncode({'record': 'L1', 'body': {'lesson': 'L1'}}),
      ).toEntry();

      expect(await handler.push(legacy), isA<SyncSynced>());
      expect(sentKeys, [null]);
    });

    test('repository shares one X-Idempotency-Key between the direct '
        'attempt and its queued retry', () async {
      final requests = <RequestOptions>[];
      var failNext = true;
      if (getIt.isRegistered<HttpService>()) {
        getIt.unregister<HttpService>();
      }
      getIt.registerSingleton<HttpService>(_FakeHttpService((options) {
        requests.add(options);
        if (failNext) {
          failNext = false;
          return ResponseBody.fromString('oops', 503);
        }
        return ResponseBody.fromString(
          jsonEncode({'message': null}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }));
      addTearDown(() => getIt.unregister<HttpService>());

      final outbox = InMemoryOutbox();
      final queue = LmsUploadQueue(outbox: outbox);
      // Default post (the real _dioPost) so the drain also goes over the
      // fake wire and its headers are captured.
      final handler = LmsUploadSyncHandler();
      for (final op in LmsUploadQueue.opTypes) {
        outbox.registerHandler(op, handler);
      }
      final repo = HttpLmsRepository(retryQueue: queue);

      await repo.recordVideoWatch(
          lesson: 'L1', source: 'lesson', watchTimeSeconds: 10);

      // Direct attempt failed (503) -> queued; the queued envelope holds the
      // exact key the failed attempt already sent.
      expect(requests, hasLength(1));
      final directKey =
          requests.single.headers[LmsUploadSyncHandler.idempotencyHeader];
      expect(directKey, isNotNull);
      expect(outbox.ops, hasLength(1));
      expect(keyOf(outbox.ops.single), directKey);

      await queue.kick();

      // Retry hit the same gateway cmd with the SAME header value — and the
      // header name on the wire is the backend's, verbatim. Every call now
      // rides the universal gateway path; the target method is the body's
      // prefix-free `cmd`.
      expect(outbox.ops, isEmpty);
      expect(requests, hasLength(2));
      expect(requests[1].path, kPlatformGatewayPath);
      expect((requests[1].data as Map)['cmd'], 'api.lms.record_video_watch');
      expect(requests[1].headers['X-Idempotency-Key'], directKey);
    });
  });

  group('PendingSyncNotice', () {
    testWidgets('hidden when empty, counts while pending, error + retry '
        'when parked', (tester) async {
      final outbox = InMemoryOutbox(maxAttempts: 1);
      final queue = LmsUploadQueue(outbox: outbox);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PendingSyncNotice(queue: queue)),
      ));
      await tester.pump();
      expect(find.textContaining('sync'), findsNothing); // fully hidden

      await queue.queueSaveProgress('L1');
      await queue.queueSetGrade(10);
      await tester.pump();
      expect(find.text('2 updates waiting to sync'), findsOneWidget);

      // Exhaust retries -> parked -> failure surfaced with a retry action.
      final handler = LmsUploadSyncHandler(post: (_, __, ___) => throw _network());
      for (final op in LmsUploadQueue.opTypes) {
        outbox.registerHandler(op, handler);
      }
      await queue.kick();
      await tester.pump();
      expect(
          find.text("Some of your progress couldn't sync"), findsOneWidget);
      expect(find.text('Tap to retry now.'), findsOneWidget);

      // Tap-to-retry re-arms the ops and, once the backend recovers, the
      // notice disappears.
      outbox.handlers.updateAll(
          (_, __) => LmsUploadSyncHandler(post: (_, __, ___) async {}));
      await tester.tap(find.text('Tap to retry now.'));
      await tester.pumpAndSettle();
      expect(find.text('Tap to retry now.'), findsNothing);
      expect(outbox.ops, isEmpty);
    });
  });
}
