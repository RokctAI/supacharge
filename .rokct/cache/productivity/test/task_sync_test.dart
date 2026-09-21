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

// Task sync, client side: the wiring that connects the /tasks workspace to
// the personal-task endpoints in `projects/frappe/src/task_sync.py`.
//
// Two properties are pinned here, and they are NOT the same property:
//
//   * OFFLINE IS NOT A DEGRADED MODE. Creating, editing, completing and
//     deleting a task must behave identically with no server in existence -
//     no throw, no wait, no error surfaced, and the local store still the
//     answer to every read. Sync is additive; it may only ever add.
//   * THE HANDSHAKE AND THE PULL ACTUALLY WORK. A task born on the device
//     with a locally minted `client_id` reaches the server and learns its
//     real id back, and a task the server knows about lands in the local
//     store.
//
// The tests drive real drift, the real SyncEngine outbox and the real
// PlatformGateway. Only the socket is fake: a stub Dio adapter stands in for
// the backend, so the request that goes out and the response that comes back
// are the actual wire shapes the endpoints define. Several tests register no
// backend at all, which is the strongest form of "there is no server".

import 'dart:convert';
import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

/// One request the stub backend saw.
class _Call {
  _Call(this.cmd, this.payload);

  final String cmd;
  final Map<String, dynamic> payload;
}

/// A stub backend. Answers gateway calls from [replies] and records every
/// request, so a test can assert the exact wire shape that went out.
class _StubBackend implements HttpClientAdapter {
  final List<_Call> calls = <_Call>[];

  /// cmd -> reply. A reply is either a Map (200 with that as the method's
  /// return value) or an int status code to fail with.
  final Map<String, Object> replies = <String, Object>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Map<String, dynamic> body = options.data is Map
        ? (options.data as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final String cmd = (body['cmd'] ?? '').toString();
    final Map<String, dynamic> payload =
        (body['payload'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    calls.add(_Call(cmd, payload));

    final Object? reply = replies[cmd];
    if (reply is int) {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'exc_type': 'ValidationError'}),
        reply,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    // Frappe wraps a whitelisted method's return value in `message`; the
    // shared stack's FrappeResponseInterceptor is what unwraps it, and this
    // test keeps that interceptor in place so the handlers are exercised
    // against the real envelope rather than a pre-opened one.
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'message': reply ?? <String, dynamic>{}}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [HttpService] wired to a [_StubBackend] instead of a socket.
class _StubHttpService extends HttpService {
  _StubHttpService(this.backend);

  final _StubBackend backend;

  @override
  Dio client({bool requireAuth = false, bool routing = false}) {
    return Dio(BaseOptions(baseUrl: 'https://tasks.invalid'))
      ..interceptors.add(const FrappeResponseInterceptor())
      ..httpClientAdapter = backend;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase database;
  late TodoRepositoryImpl repository;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('productivity_task_sync');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async => tempDir.path,
        );
    database = AppDatabase();
    repository = TodoRepositoryImpl(database);
  });

  /// Every telemetry event the code under test emitted, through
  /// base_sdk's injection seam ([TelemetryClient.configure]) so nothing
  /// rides the stub backend and a test can read the exact wire body.
  final List<_Call> telemetry = <_Call>[];

  setUp(() async {
    telemetry.clear();
    TelemetryClient.configure(
      transport: (String cmd, Map<String, dynamic> payload) async {
        telemetry.add(_Call(cmd, payload));
      },
    );
    TaskPullService.lastFailure.value = null;
    await database.delete(database.tasksTable).go();
    await database.delete(database.outboxTable).go();
    await database.delete(database.keyValueTable).go();
    // A fresh engine per test: handlers are registered per engine, and the
    // registration under test is the one this SDK's DI hook performs.
    SyncEngine.debugReset();
    if (GetIt.I.isRegistered<HttpService>()) {
      GetIt.I.unregister<HttpService>();
    }
    if (!GetIt.I.isRegistered<AppDatabase>()) {
      GetIt.I.registerSingleton<AppDatabase>(database);
    }
    ProductivitySdkDependencies.register(GetIt.I);
  });

  tearDown(() {
    TelemetryClient.configure(transport: null);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  /// The outbox, oldest first.
  Future<List<OutboxEntry>> outbox() async {
    final List<OutboxEntry> rows = await database
        .select(database.outboxTable)
        .get();
    rows.sort(
      (OutboxEntry a, OutboxEntry b) => a.createdAt.compareTo(b.createdAt),
    );
    return rows;
  }

  Map<String, dynamic> payloadOf(OutboxEntry op) =>
      jsonDecode(op.payload) as Map<String, dynamic>;

  /// Wait for the outbox to stop moving.
  ///
  /// Needed BECAUSE of the property under test: queueing an op asks the
  /// engine to drain and deliberately does not wait for it, so a save
  /// returns while the push is still in the air. Nothing in the app waits
  /// for this; a test asserting on the push has to.
  Future<void> settle() async {
    String? previous;
    for (int i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final List<OutboxEntry> rows = await database
          .select(database.outboxTable)
          .get();
      final List<String> snapshot =
          rows
              .map((OutboxEntry r) => '${r.id}:${r.status}:${r.attempts}')
              .toList()
            ..sort();
      final String current = snapshot.join('|');
      final bool quiet = !rows.any(
        (OutboxEntry r) => r.status == OutboxStatus.inFlight.name,
      );
      if (i >= 3 && quiet && current == previous) return;
      previous = current;
    }
  }

  _StubBackend useBackend() {
    final _StubBackend backend = _StubBackend();
    GetIt.I.registerSingleton<HttpService>(_StubHttpService(backend));
    return backend;
  }

  /// The client_id every fixture task carries.
  ///
  /// Minted up front rather than left to the repository so a test can stage
  /// the backend's reply before the save that triggers the push. The
  /// repository mints one itself when a task arrives without it, and the
  /// first test in this file is the one that pins that.
  const String cid = 'cid-fixture-1';

  Map<String, dynamic> aTask({
    String id = 'local-1',
    String title = 'Ship the client half',
    bool isDone = false,
    String? deadline,
    String? clientId = cid,
  }) => <String, dynamic>{
    'id': id,
    if (clientId != null) 'clientId': clientId,
    'title': title,
    'isDone': isDone,
    'deadline': deadline ?? DateTime(2026, 9, 14, 8, 30).toIso8601String(),
    'reminder': true,
    'priority': 'High',
    'category': 'Engineering',
    'recurrence': 'Weekly',
    'notifId': 4242,
    'subtasks': <Map<String, dynamic>>[
      <String, dynamic>{'title': 'Wire the outbox', 'isDone': true},
    ],
  };

  // ───────────────────────── offline is not a mode ─────────────────────────

  group('with no backend in existence', () {
    // NOTHING is registered for HttpService in this group. A gateway call
    // cannot even be constructed, which is a harsher environment than being
    // merely offline, and every user action still has to work.

    test(
      'creating a task saves it and surfaces it, exactly as before',
      () async {
        // No client id supplied: the repository has to mint one, with no
        // server to ask and no network to reach.
        final Map<String, dynamic> task = aTask(clientId: null);
        await repository.saveTodos(<Map<String, dynamic>>[task]);

        final List<Map<String, dynamic>> loaded = await repository.loadTodos();
        expect(loaded, hasLength(1));
        expect(loaded.single['title'], 'Ship the client half');
        expect(loaded.single['priority'], 'High');
        expect(loaded.single['subtasks'], hasLength(1));
        // It also gained the id the server will upsert on - minted locally,
        // with nothing to ask.
        expect((loaded.single['clientId'] as String?) ?? '', isNotEmpty);
        // ...and nothing has been told to the server, because there is none.
        expect(loaded.single['remoteId'], isNull);
      },
    );

    test('editing and completing a task work, and read back', () async {
      final Map<String, dynamic> task = aTask();
      await repository.saveTodos(<Map<String, dynamic>>[task]);

      final Map<String, dynamic> edited =
          Map<String, dynamic>.from((await repository.loadTodos()).single)
            ..['title'] = 'Ship it twice'
            ..['isDone'] = true;
      await repository.saveTodos(<Map<String, dynamic>>[edited]);

      final Map<String, dynamic> reloaded =
          (await repository.loadTodos()).single;
      expect(reloaded['title'], 'Ship it twice');
      expect(reloaded['isDone'], isTrue);
    });

    test('deleting a task removes it', () async {
      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      await repository.deleteTodo('local-1');
      expect(await repository.loadTodos(), isEmpty);
    });

    test('syncNow reports no change and throws nothing', () async {
      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      expect(await repository.syncNow(), isFalse);
      // The task is untouched by the failed attempt.
      expect(await repository.loadTodos(), hasLength(1));
    });

    test(
      'a failed push leaves the task alone and keeps the op for later',
      () async {
        await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
        // No kick here on purpose: queueing already asked the engine to drain.
        await settle();

        expect(
          (await repository.loadTodos()).single['title'],
          'Ship the client half',
        );
        final List<OutboxEntry> ops = await outbox();
        expect(ops, hasLength(1));
        // Retryable, not rejected: nothing was refused, nobody answered.
        expect(ops.single.status, OutboxStatus.pending.name);
        expect(ops.single.attempts, 1);
      },
    );
  });

  // ───────────────────────────── the push side ─────────────────────────────

  group('push', () {
    test('a save queues one upsert carrying the wire contract', () async {
      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);

      final List<OutboxEntry> ops = await outbox();
      expect(ops, hasLength(1));
      expect(ops.single.opType, TaskUpsertSyncHandler.opType);
      expect(ops.single.sdk, TaskSyncQueue.sdkName);

      final Map<String, dynamic> payload = payloadOf(ops.single);
      final String clientId =
          (await repository.loadTodos()).single['clientId'] as String;
      expect(payload['client_id'], clientId);
      // The server's vocabulary, not the device's.
      expect(payload['title'], 'Ship the client half');
      expect(payload['is_done'], 0);
      expect(payload['deadline'], '2026-09-14 08:30:00');
      expect(payload['remind_at'], '2026-09-14 08:30:00');
      expect(payload['priority'], 'High');
      expect(payload['recurrence'], 'Weekly');
      expect(payload['subtasks'], <Map<String, dynamic>>[
        <String, dynamic>{'title': 'Wire the outbox', 'isDone': true, 'durationSeconds': 0},
      ]);
    });

    test('ten edits before the first push cost one outbox row', () async {
      Map<String, dynamic> task = aTask();
      for (int i = 0; i < 10; i++) {
        task = Map<String, dynamic>.from(task)..['title'] = 'Edit $i';
        await repository.saveTodos(<Map<String, dynamic>>[task]);
      }
      final List<OutboxEntry> ops = await outbox();
      expect(ops, hasLength(1));
      // The latest snapshot wins, not the first.
      expect(payloadOf(ops.single)['title'], 'Edit 9');
    });

    test(
      'a save that changed nothing the server cares about queues nothing',
      () async {
        await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
        await database.delete(database.outboxTable).go();

        final Map<String, dynamic> reloaded = Map<String, dynamic>.from(
          (await repository.loadTodos()).single,
        );
        // A purely local field. The tasks page re-saves the whole list on
        // every action, so this is the common case, not an exotic one.
        reloaded['notifId'] = 9999;
        await repository.saveTodos(<Map<String, dynamic>>[reloaded]);

        expect(await outbox(), isEmpty);
      },
    );

    test(
      'THE HANDSHAKE: the push carries the local client_id and the local row '
      'learns the real id back',
      () async {
        final _StubBackend backend = useBackend();
        backend.replies['api.projects.sync_personal_task'] = <String, dynamic>{
          'name': 'TASK-2026-00042',
          'client_id': cid,
          'created': 1,
          'status': 'Open',
          'remind_at': '2026-09-14 08:30:00',
          'reminder_fired': 0,
          'modified': '2026-09-01 10:00:00',
        };

        await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
        // The save did not wait for the push, so the test does.
        await settle();

        // The request went to the right method, with the device's own id.
        expect(backend.calls, hasLength(1));
        expect(backend.calls.single.cmd, 'api.projects.sync_personal_task');
        expect(backend.calls.single.payload['client_id'], cid);

        // The local row now holds the server's id - the real half of the
        // handshake - and the op is gone from the outbox.
        final Map<String, dynamic> reconciled =
            (await repository.loadTodos()).single;
        expect(reconciled['remoteId'], 'TASK-2026-00042');
        expect(reconciled['clientId'], cid, reason: 'client_id is stable');
        expect(await outbox(), isEmpty);
      },
    );

    test('a second push for the same task reuses the same client_id', () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.sync_personal_task'] = <String, dynamic>{
        'name': 'TASK-2026-00042',
        'client_id': cid,
        'status': 'Open',
      };
      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      await settle();

      final Map<String, dynamic> edited = Map<String, dynamic>.from(
        (await repository.loadTodos()).single,
      )..['title'] = 'Renamed';
      await repository.saveTodos(<Map<String, dynamic>>[edited]);
      await settle();

      expect(backend.calls, hasLength(2));
      // Same key both times: this is what makes the upsert an update rather
      // than a second task.
      expect(backend.calls.last.payload['client_id'], cid);
      expect(backend.calls.last.payload['title'], 'Renamed');
    });

    test('a server that is down means a retry, never a lost task', () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.sync_personal_task'] = 503;

      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      await settle();

      expect(
        (await repository.loadTodos()).single['title'],
        'Ship the client half',
      );
      final OutboxEntry op = (await outbox()).single;
      expect(op.status, OutboxStatus.pending.name);
      expect(op.attempts, 1);
      expect(op.nextAttemptAt, isNotNull);
    });

    test('a server that says no parks the op and keeps the task', () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.sync_personal_task'] = 403;

      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      await settle();

      expect(await repository.loadTodos(), hasLength(1));
      expect((await outbox()).single.status, OutboxStatus.failed.name);
    });

    test(
      'deleting queues a delete and drops the task\'s queued upsert',
      () async {
        final _StubBackend backend = useBackend();
        // The create never gets through, so it is still sitting in the outbox
        // when the task is deleted - the offline create-then-delete case.
        backend.replies['api.projects.sync_personal_task'] = 503;
        backend.replies['api.projects.delete_personal_task'] =
            <String, dynamic>{'name': 'TASK-2026-00042', 'deleted': true};

        await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
        await settle();

        await repository.deleteTodo('local-1');
        expect(await repository.loadTodos(), isEmpty);

        final List<OutboxEntry> ops = await outbox();
        // The queued create is gone; only the delete remains.
        expect(ops.map((OutboxEntry o) => o.opType), <String>[
          TaskDeleteSyncHandler.opType,
        ]);
        expect(payloadOf(ops.single)['client_id'], cid);

        await settle();
        expect(backend.calls.last.cmd, 'api.projects.delete_personal_task');
        expect(await outbox(), isEmpty);
      },
    );

    test('deleting something the server never had is not an error', () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.sync_personal_task'] = 503;
      // `delete_personal_task` throws DoesNotExistError -> 404.
      backend.replies['api.projects.delete_personal_task'] = 404;

      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      await settle();
      await repository.deleteTodo('local-1');
      await settle();

      // Already gone is the goal state, so the op retires rather than
      // parking an error in front of the user.
      expect(await outbox(), isEmpty);
    });
  });

  // ───────────────────────────── the pull side ─────────────────────────────

  group('pull', () {
    test(
      'a task this device has never seen arrives in the local store',
      () async {
        final _StubBackend backend = useBackend();
        backend.replies['api.projects.list_personal_tasks'] = <String, dynamic>{
          'tasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'TASK-2026-00099',
              'client_id': 'from-the-other-handset',
              'subject': 'Typed on the other device',
              'description': 'and pulled down here',
              'status': 'Open',
              'priority': 'Urgent',
              'category': 'Ops',
              'recurrence': 'Daily',
              'is_long_term': 0,
              'exp_end_date': '2026-09-20 17:00:00',
              'remind_at': '2026-09-20 09:00:00',
              'reminder_fired': 0,
              'modified': '2026-09-01 11:00:00',
              'subtasks': <Map<String, dynamic>>[
                <String, dynamic>{'subject': 'Step one', 'is_done': 1},
              ],
            },
          ],
          'server_time': '2026-09-01 11:00:05.123456',
        };

        expect(await repository.syncNow(), isTrue);

        final Map<String, dynamic> pulled =
            (await repository.loadTodos()).single;
        expect(pulled['title'], 'Typed on the other device');
        expect(pulled['description'], 'and pulled down here');
        expect(pulled['priority'], 'Urgent');
        expect(pulled['recurrence'], 'Daily');
        expect(pulled['isDone'], isFalse);
        expect(pulled['clientId'], 'from-the-other-handset');
        expect(pulled['remoteId'], 'TASK-2026-00099');
        expect(pulled['deadline'], DateTime(2026, 9, 20, 17).toIso8601String());
        // The reminder is its OWN time, not the deadline.
        expect(pulled['remindAt'], DateTime(2026, 9, 20, 9).toIso8601String());
        expect(pulled['subtasks'], <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Step one', 'isDone': true, 'durationSeconds': 0},
        ]);
      },
    );

    test('the next pull resumes from the server clock, verbatim', () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.list_personal_tasks'] = <String, dynamic>{
        'tasks': <Map<String, dynamic>>[],
        'server_time': '2026-09-01 11:00:05.123456',
      };

      await repository.syncNow();
      expect(backend.calls.last.payload.containsKey('modified_after'), isFalse);

      await repository.syncNow();
      // Byte for byte what the server sent. Re-formatting it would
      // reinterpret a server-timezone stamp against the device's clock.
      expect(
        backend.calls.last.payload['modified_after'],
        '2026-09-01 11:00:05.123456',
      );
    });

    test(
      'a pull never overwrites an edit that has not been pushed yet',
      () async {
        final _StubBackend backend = useBackend();
        // The push is refused, so the local edit stays queued.
        backend.replies['api.projects.sync_personal_task'] = 503;

        backend.replies['api.projects.list_personal_tasks'] = <String, dynamic>{
          'tasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'TASK-2026-00042',
              'client_id': cid,
              'subject': 'The stale server copy',
              'status': 'Open',
              'modified': '2026-09-01 10:00:00',
            },
          ],
          'server_time': '2026-09-01 11:00:00',
        };

        await repository.saveTodos(<Map<String, dynamic>>[
          aTask(title: 'My unsent edit'),
        ]);
        await settle();

        await repository.syncNow();

        // The device's own words survive: its edit is the NEWER one, and the
        // queued op is what will settle the difference.
        expect(
          (await repository.loadTodos()).single['title'],
          'My unsent edit',
        );
      },
    );

    test(
      'a pulled task is merged onto the local row, not swapped for it',
      () async {
        final _StubBackend backend = useBackend();
        backend.replies['api.projects.sync_personal_task'] = <String, dynamic>{
          'name': 'TASK-2026-00042',
          'client_id': cid,
          'status': 'Open',
        };
        await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
        await settle();
        expect(
          await outbox(),
          isEmpty,
          reason: 'the edit is pushed, not pending',
        );

        backend.replies['api.projects.list_personal_tasks'] = <String, dynamic>{
          'tasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'TASK-2026-00042',
              'client_id': cid,
              'subject': 'Completed elsewhere',
              'status': 'Completed',
              'modified': '2026-09-01 12:00:00',
            },
          ],
          'server_time': '2026-09-01 12:00:01',
        };
        await repository.syncNow();

        final Map<String, dynamic> merged =
            (await repository.loadTodos()).single;
        expect(merged['title'], 'Completed elsewhere');
        expect(merged['isDone'], isTrue);
        // The local notification id is this device's bookkeeping and means
        // nothing on another handset, so the server does not carry it - and a
        // pull must therefore not wipe it.
        expect(merged['notifId'], 4242);
        // Same row, not a second one.
        expect(merged['id'], 'local-1');
      },
    );

    test('an unreachable server during a pull changes nothing', () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.list_personal_tasks'] = 500;
      backend.replies['api.projects.sync_personal_task'] = 500;

      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      expect(await repository.syncNow(), isFalse);
      expect(
        (await repository.loadTodos()).single['title'],
        'Ship the client half',
      );
    });

    // A failed pull used to vanish in a catch: no event, no state. These
    // pin that it is now SEEN without becoming a throw — syncNow keeps its
    // never-throws contract (the test above), the local list keeps its
    // rows, and what leaves the device is the cmd and the error's class,
    // never its text.
    test(
      'a failed pull emits one telemetry event carrying the cmd and the '
      'error class, and nothing else',
      () async {
        final _StubBackend backend = useBackend();
        backend.replies['api.projects.list_personal_tasks'] = 500;

        expect(await TaskPullService.pull(), 0);
        // logError is fire-and-forget; let the transport receive it.
        await pumpEventQueue();

        expect(telemetry, hasLength(1));
        final _Call event = telemetry.single;
        expect(event.cmd, TelemetryClient.cmd);
        expect(event.payload['error_message'], 'task_pull_failed');
        final Map<String, dynamic> context =
            (jsonDecode(event.payload['context'] as String) as Map)
                .cast<String, dynamic>();
        expect(
          context['context'],
          <String, dynamic>{
            'cmd': 'api.projects.list_personal_tasks',
            'error_class': 'DioException',
          },
        );
        // The class, never the text: no status line, no URL, no body.
        final String wire = jsonEncode(event.payload);
        expect(wire, isNot(contains('500')));
        expect(wire, isNot(contains('tasks.invalid')));
        expect(wire, isNot(contains('ValidationError')));
      },
    );

    test('a failed pull lands on lastFailure and a good one clears it',
        () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.list_personal_tasks'] = 500;

      expect(TaskPullService.syncFailed, isFalse);
      final List<TaskPullFailure?> seen = <TaskPullFailure?>[];
      void watch() => seen.add(TaskPullService.lastFailure.value);
      TaskPullService.lastFailure.addListener(watch);
      addTearDown(() => TaskPullService.lastFailure.removeListener(watch));

      expect(await TaskPullService.pull(), 0);
      expect(TaskPullService.syncFailed, isTrue);
      final TaskPullFailure failure = TaskPullService.lastFailure.value!;
      expect(failure.cmd, 'api.projects.list_personal_tasks');
      expect(failure.errorClass, 'DioException');
      expect(seen, hasLength(1));

      // The server comes back: the next completed pull clears the flag,
      // and the page hears about that too.
      backend.replies['api.projects.list_personal_tasks'] =
          <String, dynamic>{'tasks': <Object>[], 'server_time': null};
      expect(await TaskPullService.pull(), 0);
      expect(TaskPullService.syncFailed, isFalse);
      expect(seen, hasLength(2));
      expect(seen.last, isNull);
    });

    test('a pull with no backend in existence is reported the same way',
        () async {
      // The strongest form of "no server": nothing registered at all,
      // which is what an uncomposed host looks like.
      expect(await TaskPullService.pull(), 0);
      await pumpEventQueue();

      expect(TaskPullService.syncFailed, isTrue);
      expect(telemetry, hasLength(1));
      final Map<String, dynamic> context =
          (jsonDecode(telemetry.single.payload['context'] as String) as Map)
              .cast<String, dynamic>();
      final Map<String, dynamic> fields =
          (context['context'] as Map).cast<String, dynamic>();
      expect(fields['cmd'], 'api.projects.list_personal_tasks');
      expect(fields['error_class'], TaskPullService.lastFailure.value!.errorClass);
      expect(fields.keys, unorderedEquals(<String>['cmd', 'error_class']));
    });

    // A demo build (--dart-define=IS_DEMO=true) has no backend by design.
    // Its pull must not be a failure that flags syncFailed - that is what
    // drew "Sync paused. Your tasks will sync when the connection is back."
    // on the guided tour's empty tasks list - and must not go out at all.
    test('a demo build never pulls, never flags a failed sync and emits '
        'no telemetry', () async {
      // isDemo is a compile-time constant; the override is the only way a
      // test can stand in a demo build.
      TaskPullService.isDemoOverride = true;
      addTearDown(() => TaskPullService.isDemoOverride = null);
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.list_personal_tasks'] = 500;
      // A failure left over from before the flag flipped is cleared, the
      // same way a successful pull clears it.
      TaskPullService.lastFailure.value = const TaskPullFailure(
        cmd: 'api.projects.list_personal_tasks',
        errorClass: 'DioException',
      );

      expect(await TaskPullService.pull(), 0);
      await pumpEventQueue();

      expect(TaskPullService.syncFailed, isFalse);
      expect(backend.calls, isEmpty);
      expect(telemetry, isEmpty);
    });
  });

  // ────────────────────────────── the snooze ───────────────────────────────

  group('snooze', () {
    test('moves the reminder and NEVER the deadline', () async {
      final _StubBackend backend = useBackend();
      backend.replies['api.projects.sync_personal_task'] = <String, dynamic>{
        'name': 'TASK-2026-00042',
        'client_id': cid,
        'status': 'Open',
      };
      backend.replies['api.projects.snooze_task_reminder'] = <String, dynamic>{
        'name': 'TASK-2026-00042',
        'client_id': cid,
        'remind_at': '2026-09-15 08:30:00',
        'reminder_fired': 0,
        'exp_end_date': '2026-09-14',
        'deadline_moved': 0,
      };
      await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
      await settle();
      final Map<String, dynamic> before = (await repository.loadTodos()).single;
      final Object? deadlineBefore = before['deadline'];

      final DateTime later = DateTime.now().add(const Duration(days: 1));
      expect(await repository.snoozeReminder('local-1', later), isTrue);

      final Map<String, dynamic> after = (await repository.loadTodos()).single;
      expect(after['remindAt'], later.toIso8601String());
      expect(
        after['deadline'],
        deadlineBefore,
        reason: 'a snooze must not renegotiate when the work is due',
      );

      final Map<String, dynamic> payload = payloadOf(
        (await outbox()).firstWhere(
          (OutboxEntry o) => o.opType == TaskSnoozeSyncHandler.opType,
        ),
      );
      expect(payload['client_id'], cid);
      expect(payload['remind_at'], isNotNull);
      // There is no deadline field on this op at all, so it could not move
      // one even if the server let it.
      expect(payload.containsKey('deadline'), isFalse);

      await settle();

      final Map<String, dynamic> settled =
          (await repository.loadTodos()).single;
      // The server's remind_at is authoritative once it has answered.
      expect(
        settled['remindAt'],
        DateTime(2026, 9, 15, 8, 30).toIso8601String(),
      );
      expect(settled['reminderFired'], isFalse);
      expect(settled['deadline'], deadlineBefore);
    });

    test(
      'a snooze into the past is refused locally, not by the server',
      () async {
        await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
        await database.delete(database.outboxTable).go();
        final DateTime past = DateTime.now().subtract(const Duration(hours: 1));
        expect(await repository.snoozeReminder('local-1', past), isFalse);
        // Nothing queued: finding this out from a parked op minutes later is
        // no way to tell a user their snooze did not take.
        expect(await outbox(), isEmpty);
      },
    );

    test(
      'a server that claims it moved the deadline is not believed',
      () async {
        final _StubBackend backend = useBackend();
        backend.replies['api.projects.sync_personal_task'] = <String, dynamic>{
          'name': 'TASK-2026-00042',
          'client_id': cid,
          'status': 'Open',
        };
        backend.replies['api.projects.snooze_task_reminder'] =
            <String, dynamic>{
              'name': 'TASK-2026-00042',
              'client_id': cid,
              'remind_at': '2026-09-15 08:30:00',
              'reminder_fired': 0,
              'exp_end_date': '2026-09-30',
              'deadline_moved': 1,
            };
        await repository.saveTodos(<Map<String, dynamic>>[aTask()]);
        await settle();

        final DateTime later = DateTime.now().add(const Duration(days: 1));
        await repository.snoozeReminder('local-1', later);
        await settle();

        // The response is refused rather than applied: better a reminder that
        // did not move than a deadline that did.
        final OutboxEntry op = (await outbox()).firstWhere(
          (OutboxEntry o) => o.opType == TaskSnoozeSyncHandler.opType,
        );
        expect(op.status, OutboxStatus.failed.name);
        expect(
          (await repository.loadTodos()).single['remindAt'],
          later.toIso8601String(),
        );
      },
    );
  });

  // ───────────────────────── the backfill on upgrade ───────────────────────

  test('tasks that predate client ids get one and are queued', () async {
    // A row written the way the table looked before this change.
    await database
        .into(database.tasksTable)
        .insert(
          TasksTableCompanion.insert(
            id: Value('legacy-1'),
            title: 'Written before sync existed',
            data: const Value(
              '{"id":"legacy-1","title":"Written before sync existed"}',
            ),
          ),
        );
    expect((await repository.loadTodos()).single['clientId'], isNull);

    await repository.syncNow();

    final Map<String, dynamic> migrated = (await repository.loadTodos()).single;
    expect((migrated['clientId'] as String?) ?? '', isNotEmpty);
    final List<OutboxEntry> ops = await outbox();
    expect(
      ops.map((OutboxEntry o) => o.opType),
      contains(TaskUpsertSyncHandler.opType),
    );
  });

  // ──────────────────────────── the DTO contract ───────────────────────────

  group('TaskRequest', () {
    test('omits fields the caller said nothing about', () {
      final Map<String, dynamic> json = const TaskRequest(
        clientId: 'abc',
      ).toJson();
      expect(json, <String, dynamic>{'client_id': 'abc'});
      // Not `'title': null`. The server reads a present key as an
      // instruction and an absent one as silence, so a partial update MUST
      // omit rather than null.
      expect(json.containsKey('is_done'), isFalse);
    });

    test('formats datetimes the way Frappe parses them', () {
      final Map<String, dynamic> json = TaskRequest(
        clientId: 'abc',
        deadline: DateTime(2026, 9, 14, 8, 30, 5),
      ).toJson();
      expect(json['deadline'], '2026-09-14 08:30:05');
    });

    test('a snoozed reminder wins over the deadline-derived one', () {
      final Map<String, dynamic> json = TaskRequest.fromTodo(<String, dynamic>{
        'title': 'x',
        'reminder': true,
        'deadline': DateTime(2026, 9, 14, 8).toIso8601String(),
        'remindAt': DateTime(2026, 9, 15, 8).toIso8601String(),
      }, 'abc').toJson();
      expect(json['deadline'], '2026-09-14 08:00:00');
      expect(json['remind_at'], '2026-09-15 08:00:00');
    });

    test('no reminder switch means no remind_at, deadline or not', () {
      final Map<String, dynamic> json = TaskRequest.fromTodo(<String, dynamic>{
        'title': 'x',
        'reminder': false,
        'deadline': DateTime(2026, 9, 14, 8).toIso8601String(),
      }, 'abc').toJson();
      expect(json['deadline'], '2026-09-14 08:00:00');
      expect(json.containsKey('remind_at'), isFalse);
    });
  });

  group('TaskResponse', () {
    test('reads Frappe Check fields as 0/1', () {
      final TaskResponse task = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'abc',
        'status': 'Completed',
        'reminder_fired': 1,
        'is_long_term': 0,
      });
      expect(task.isDone, isTrue);
      expect(task.reminderFired, isTrue);
      expect(task.isLongTerm, isFalse);
    });

    test('Cancelled is not done', () {
      // The device has no vocabulary for cancelled, and showing it ticked
      // would claim the work happened.
      expect(
        TaskResponse.fromMap(<String, dynamic>{
          'name': 'TASK-1',
          'client_id': 'abc',
          'status': 'Cancelled',
        }).isDone,
        isFalse,
      );
    });
  });
}
