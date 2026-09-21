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

// Design strip frame 44c — the M2 bridge, the read half and the wire.
//
// The plan reader goes through the real PlatformGateway; only the socket
// is a stub Dio adapter, the same way test/task_sync_test.dart drives the
// push path. The stub records every cmd so a test can assert that the
// three productivity endpoints — which had ZERO Dart callers before this
// frame — are the ones being asked, by their gateway names, with no
// payload.
//
// What a later edit could quietly undo:
//   * the KPI count is DERIVED by counting get_kpis; there is no count
//     field and a card that read one would be lying;
//   * get_kpis failing costs the chip, never the list;
//   * `strategicObjective` has THREE wire states — absent, "" (unlink),
//     a name — and the request must keep them apart;
//   * a pull that says the link is gone must win over a stale local one,
//     while a handshake, which never carries the column, must not clear
//     it.

import 'dart:convert';

import 'package:base_sdk/base_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

class _StubBackend implements HttpClientAdapter {
  final List<String> cmds = <String>[];
  final List<Map<String, dynamic>?> payloads = <Map<String, dynamic>?>[];

  /// cmd -> reply: a List (200, the method's return value) or an int
  /// status to fail with.
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
    cmds.add(cmd);
    payloads.add((body['payload'] as Map?)?.cast<String, dynamic>());
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
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'message': reply ?? <Object?>[]}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StubHttpService extends HttpService {
  _StubHttpService(this.backend);

  final _StubBackend backend;

  @override
  Dio client({bool requireAuth = false, bool routing = false}) {
    return Dio(BaseOptions(baseUrl: 'https://plan.invalid'))
      ..interceptors.add(const FrappeResponseInterceptor())
      ..httpClientAdapter = backend;
  }
}

const List<Map<String, dynamic>> _pillars = <Map<String, dynamic>>[
  {'name': 'PIL-OPS', 'title': 'Operations', 'description': null, 'vision': 'VIS-1'},
  {'name': 'PIL-GRW', 'title': 'Growth', 'description': '', 'vision': 'VIS-1'},
  {'name': 'PIL-PPL', 'title': 'People', 'description': null, 'vision': 'VIS-1'},
];

const List<Map<String, dynamic>> _objectives = <Map<String, dynamic>>[
  {'name': 'OBJ-1', 'title': 'Cut plant downtime under 2%', 'pillar': 'PIL-OPS'},
  {'name': 'OBJ-2', 'title': 'Open two new depot routes', 'pillar': 'PIL-GRW'},
  {'name': 'OBJ-3', 'title': 'Every driver ROK-certified by Q2', 'pillar': 'PIL-PPL'},
  {'name': 'OBJ-4', 'title': 'Bottle cost under R4.10 landed', 'pillar': 'PIL-OPS'},
];

const List<Map<String, dynamic>> _kpis = <Map<String, dynamic>>[
  {'name': 'KPI-1', 'title': 'Downtime %', 'strategic_objective': 'OBJ-1'},
  {'name': 'KPI-2', 'title': 'MTBF', 'strategic_objective': 'OBJ-1'},
  {'name': 'KPI-3', 'title': 'Callouts', 'strategic_objective': 'OBJ-1'},
  {'name': 'KPI-4', 'title': 'Routes live', 'strategic_objective': 'OBJ-2'},
  {'name': 'KPI-5', 'title': 'Orphan', 'strategic_objective': null},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubBackend backend;

  setUp(() {
    backend = _StubBackend();
    if (GetIt.I.isRegistered<HttpService>()) {
      GetIt.I.unregister<HttpService>();
    }
    GetIt.I.registerSingleton<HttpService>(_StubHttpService(backend));
  });

  group('ObjectivesRepositoryImpl.loadCatalog', () {
    test('asks the three productivity endpoints by their gateway names', () async {
      backend.replies[ObjectiveCmds.objectives] = _objectives;
      backend.replies[ObjectiveCmds.pillars] = _pillars;
      backend.replies[ObjectiveCmds.kpis] = _kpis;

      final ApiResult<ObjectiveCatalog> result =
          await const ObjectivesRepositoryImpl().loadCatalog();

      expect(backend.cmds, <String>[
        'tenant.api.get_strategic_objectives',
        'tenant.api.get_pillars',
        'tenant.api.get_kpis',
      ]);
      // Plain get_all reads: no kwargs go out.
      expect(backend.payloads.every((p) => p == null), isTrue);
      expect(result, isA<Success<ObjectiveCatalog>>());
    });

    test('reads exactly the fields the endpoints return', () async {
      backend.replies[ObjectiveCmds.objectives] = _objectives;
      backend.replies[ObjectiveCmds.pillars] = _pillars;
      backend.replies[ObjectiveCmds.kpis] = _kpis;

      final ObjectiveCatalog catalog =
          ((await const ObjectivesRepositoryImpl().loadCatalog())
                  as Success<ObjectiveCatalog>)
              .data;

      expect(catalog.objectives.map((o) => o.name), ['OBJ-1', 'OBJ-2', 'OBJ-3', 'OBJ-4']);
      expect(catalog.objectives.first.title, 'Cut plant downtime under 2%');
      expect(catalog.objectives.first.pillar, 'PIL-OPS');
      expect(catalog.pillars.map((p) => p.title), ['Operations', 'Growth', 'People']);
      expect(catalog.pillarNamed('PIL-GRW')!.title, 'Growth');
      expect(catalog.pillarNamed('PIL-GRW')!.description, isNull,
          reason: 'an empty description is no description');
      expect(catalog.objectivesIn('PIL-OPS').map((o) => o.name), ['OBJ-1', 'OBJ-4']);
      expect(catalog.objectivesIn(null), hasLength(4));
    });

    test('the KPI count is DERIVED by counting get_kpis', () async {
      backend.replies[ObjectiveCmds.objectives] = _objectives;
      backend.replies[ObjectiveCmds.pillars] = _pillars;
      backend.replies[ObjectiveCmds.kpis] = _kpis;

      final ObjectiveCatalog catalog =
          ((await const ObjectivesRepositoryImpl().loadCatalog())
                  as Success<ObjectiveCatalog>)
              .data;

      expect(catalog.kpiCountByObjective, {'OBJ-1': 3, 'OBJ-2': 1});
      expect(catalog.kpiCountFor(catalog.objectives[0]), 3);
      expect(catalog.kpiCountFor(catalog.objectives[2]), 0);
    });

    test('get_kpis failing costs the count, never the list', () async {
      backend.replies[ObjectiveCmds.objectives] = _objectives;
      backend.replies[ObjectiveCmds.pillars] = _pillars;
      backend.replies[ObjectiveCmds.kpis] = 500;

      final ApiResult<ObjectiveCatalog> result =
          await const ObjectivesRepositoryImpl().loadCatalog();

      expect(result, isA<Success<ObjectiveCatalog>>());
      final ObjectiveCatalog catalog = (result as Success<ObjectiveCatalog>).data;
      expect(catalog.objectives, hasLength(4));
      expect(catalog.kpiCountByObjective, isEmpty);
    });

    test('the objectives failing is a failure with the status', () async {
      backend.replies[ObjectiveCmds.objectives] = 403;
      backend.replies[ObjectiveCmds.pillars] = _pillars;

      final ApiResult<ObjectiveCatalog> result =
          await const ObjectivesRepositoryImpl().loadCatalog();

      expect(result, isA<Failure<ObjectiveCatalog>>());
      expect((result as Failure<ObjectiveCatalog>).statusCode, 403);
      // Nothing after the failed read is asked for.
      expect(backend.cmds, ['tenant.api.get_strategic_objectives']);
    });

    test('no backend at all is a failure, not a throw', () async {
      GetIt.I.unregister<HttpService>();
      GetIt.I.registerSingleton<HttpService>(
        _StubHttpService(_StubBackend()..replies[ObjectiveCmds.objectives] = 500),
      );
      final ApiResult<ObjectiveCatalog> result =
          await const ObjectivesRepositoryImpl().loadCatalog();
      expect(result, isA<Failure<ObjectiveCatalog>>());
    });

    test('rows without a name are dropped rather than drawn blank', () async {
      backend.replies[ObjectiveCmds.objectives] = <Map<String, dynamic>>[
        {'name': '', 'title': 'ghost'},
        {'name': 'OBJ-9', 'title': 'real'},
      ];
      backend.replies[ObjectiveCmds.pillars] = <Map<String, dynamic>>[];
      backend.replies[ObjectiveCmds.kpis] = <Map<String, dynamic>>[];

      final ObjectiveCatalog catalog =
          ((await const ObjectivesRepositoryImpl().loadCatalog())
                  as Success<ObjectiveCatalog>)
              .data;
      expect(catalog.objectives.map((o) => o.name), ['OBJ-9']);
      expect(catalog.pillars, isEmpty);
    });
  });

  group('the facade is wired', () {
    test('the DI hook registers a reader, once', () {
      if (GetIt.I.isRegistered<ObjectivesRepositoryFacade>()) {
        GetIt.I.unregister<ObjectivesRepositoryFacade>();
      }
      if (!GetIt.I.isRegistered<AppDatabase>()) {
        GetIt.I.registerSingleton<AppDatabase>(AppDatabase());
      }
      ProductivitySdkDependencies.register(GetIt.I);
      ProductivitySdkDependencies.register(GetIt.I);
      expect(GetIt.I<ObjectivesRepositoryFacade>(), isA<ObjectivesRepositoryImpl>());
    });
  });

  group('TaskRequest carries the link in three states', () {
    test('a task that never had a link stays silent', () {
      final TaskRequest request = TaskRequest.fromTodo(
        <String, dynamic>{'title': 'x'},
        'c1',
      );
      expect(request.strategicObjective, isNull);
      expect(request.toJson().containsKey('strategic_objective'), isFalse);
    });

    test('a linked task sends the name', () {
      final TaskRequest request = TaskRequest.fromTodo(
        <String, dynamic>{'title': 'x', 'strategicObjective': ' OBJ-1 '},
        'c1',
      );
      expect(request.toJson()['strategic_objective'], 'OBJ-1');
    });

    test('a cleared link sends the empty string that unlinks', () {
      final TaskRequest request = TaskRequest.fromTodo(
        <String, dynamic>{'title': 'x', 'strategicObjective': null},
        'c1',
      );
      expect(request.toJson()['strategic_objective'], '');
    });

    test('the display pair never goes to the wire', () {
      final Map<String, dynamic> json = TaskRequest.fromTodo(
        <String, dynamic>{
          'title': 'x',
          'strategicObjective': 'OBJ-1',
          'strategicObjectiveTitle': 'Cut plant downtime under 2%',
          'strategicObjectivePillar': 'Operations',
        },
        'c1',
      ).toJson();
      expect(json.keys.where((k) => k.contains('Title') || k.contains('Pillar')), isEmpty);
    });
  });

  group('TaskResponse reads the link back', () {
    test('a pulled row carries the column, null included', () {
      final TaskResponse linked = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'c1',
        'strategic_objective': 'OBJ-1',
      });
      expect(linked.hasStrategicObjective, isTrue);
      expect(linked.strategicObjective, 'OBJ-1');

      final TaskResponse unlinked = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'c1',
        'strategic_objective': null,
      });
      expect(unlinked.hasStrategicObjective, isTrue);
      expect(unlinked.strategicObjective, isNull);
    });

    test('a pull that unlinked wins over a stale local link', () {
      final Map<String, dynamic> todo = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'c1',
        'strategic_objective': null,
      }).toTodo(existing: <String, dynamic>{
        'strategicObjective': 'OBJ-1',
        'strategicObjectiveTitle': 'old',
        'strategicObjectivePillar': 'Operations',
      });
      expect(todo.containsKey('strategicObjective'), isTrue);
      expect(todo['strategicObjective'], isNull);
      expect(todo['strategicObjectiveTitle'], isNull);
      expect(todo['strategicObjectivePillar'], isNull);
    });

    test('a pull of the same link keeps the display pair', () {
      final Map<String, dynamic> todo = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'c1',
        'strategic_objective': 'OBJ-1',
      }).toTodo(existing: <String, dynamic>{
        'strategicObjective': 'OBJ-1',
        'strategicObjectiveTitle': 'Cut plant downtime under 2%',
        'strategicObjectivePillar': 'Operations',
      });
      expect(todo['strategicObjectiveTitle'], 'Cut plant downtime under 2%');
    });

    test('the handshake, which never carries the column, clears nothing', () {
      final TaskResponse ack = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'c1',
        'created': 1,
      });
      expect(ack.hasStrategicObjective, isFalse);
      final Map<String, dynamic> todo = ack.toTodo(
        existing: <String, dynamic>{'strategicObjective': 'OBJ-1'},
      );
      expect(todo['strategicObjective'], 'OBJ-1');
    });
  });
}
