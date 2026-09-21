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

// Design strip section 41 — the M2 vision cluster, the read half.
//
// The reader goes through the real PlatformGateway; only the socket is a
// stub Dio adapter, the same way test/objectives_repository_test.dart
// drives frame 44c's reader. The stub records every cmd so a test can
// assert that the six productivity endpoints are the ones being asked,
// by their gateway names, with no payload.
//
// This file imports the reader and its models DIRECTLY rather than the
// package barrel, on purpose: the barrel reaches the drift tables, whose
// generated sources exist only in a composed app, so a barrel-importing
// test cannot load on a bare checkout (test/objectives_repository_test.dart
// is that case). Kept free of generated code, this suite runs anywhere.
// The DI hook's registration of the facade is guarded exactly like the
// two before it in productivity_di.dart and is exercised by the composed
// app's install path.
//
// What a later edit could quietly undo:
//   * the masthead is the Plan On A Page doc's OWN link, falling back to
//     the one vision the tenant has only when the link is unset;
//   * pillars and objectives are required; the masthead and the KPI
//     count are dress and a failure there costs only the dress;
//   * `get_kpis` failing draws NO count, which is not zero;
//   * `todos` are read when the row carries them and NULL when it does
//     not — the endpoint is a get_all and sends no child rows today.

import 'dart:convert';

import 'package:base_sdk/base_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:productivity_sdk/src/common/infrastructure/repositories/objectives_repository_impl.dart';
import 'package:productivity_sdk/src/common/infrastructure/repositories/vision_repository_impl.dart';
import 'package:productivity_sdk/src/common/models/data/vision_data.dart';

class _StubBackend implements HttpClientAdapter {
  final List<String> cmds = <String>[];
  final List<Map<String, dynamic>?> payloads = <Map<String, dynamic>?>[];

  /// cmd -> reply: the method's return value (200) or an int status to
  /// fail with.
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

const Map<String, dynamic> _plan = <String, dynamic>{
  'name': 'Plan On A Page',
  'vision': 'VIS-1',
};

const List<Map<String, dynamic>> _visions = <Map<String, dynamic>>[
  {
    'name': 'VIS-1',
    'title': 'Vision 2028',
    'description': '<div>A refill within reach.</div>',
  },
  {'name': 'VIS-0', 'title': 'Vision 2024', 'description': null},
];

const List<Map<String, dynamic>> _pillars = <Map<String, dynamic>>[
  {
    'name': 'PIL-CUS',
    'title': 'Customers',
    'description': 'Refill with us first.',
    'vision': 'VIS-1',
  },
  {
    'name': 'PIL-OPS',
    'title': 'Operations',
    'description': '',
    'vision': 'VIS-1',
  },
  {
    'name': 'PIL-OLD',
    'title': 'Retired',
    'description': null,
    'vision': 'VIS-0',
  },
  {'name': 'PIL-NEW', 'title': 'Unlinked', 'description': null, 'vision': null},
];

const List<Map<String, dynamic>> _objectives = <Map<String, dynamic>>[
  {
    'name': 'OBJ-1',
    'title': 'Launch refill loyalty cards',
    'pillar': 'PIL-CUS',
  },
  {'name': 'OBJ-3', 'title': 'RO uptime above 95%', 'pillar': 'PIL-OPS'},
];

const List<Map<String, dynamic>> _kpis = <Map<String, dynamic>>[
  {
    'name': 'KPI-4',
    'title': 'Uptime hours logged',
    'strategic_objective': 'OBJ-3',
  },
  {
    'name': 'KPI-5',
    'title': 'Services on schedule',
    'strategic_objective': 'OBJ-3',
  },
  {'name': 'KPI-9', 'title': 'Orphan', 'strategic_objective': null},
];

const List<Map<String, dynamic>> _goals = <Map<String, dynamic>>[
  {
    'name': 'PMG-1',
    'title': 'Master the numbers',
    'description': '<p>Read the P&amp;L.</p>',
  },
  {
    'name': 'PMG-2',
    'title': 'Coach, don\'t fix',
    'description': null,
    'todos': <Map<String, dynamic>>[
      {
        'name': 'TD-1',
        'description': 'Block the Tuesday slots',
        'status': 'Closed',
        'date': null,
      },
      {
        'name': 'TD-2',
        'description': 'Run four weeks',
        'status': 'Open',
        'date': '2026-09-26',
      },
    ],
  },
  {'name': '', 'title': 'ghost'},
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

  void seedPlan() {
    backend.replies[ObjectiveCmds.pillars] = _pillars;
    backend.replies[ObjectiveCmds.objectives] = _objectives;
    backend.replies[VisionCmds.plan] = _plan;
    backend.replies[VisionCmds.visions] = _visions;
    backend.replies[ObjectiveCmds.kpis] = _kpis;
  }

  group('VisionRepositoryImpl.loadPlan', () {
    test(
      'asks the five productivity endpoints by their gateway names',
      () async {
        seedPlan();
        final ApiResult<PlanBoard> result = await const VisionRepositoryImpl()
            .loadPlan();
        expect(backend.cmds, <String>[
          'tenant.api.get_pillars',
          'tenant.api.get_strategic_objectives',
          'tenant.api.get_plan_on_a_page',
          'tenant.api.get_visions',
          'tenant.api.get_kpis',
        ]);
        // Plain reads: no kwargs go out.
        expect(backend.payloads.every((p) => p == null), isTrue);
        expect(result, isA<Success<PlanBoard>>());
      },
    );

    test('the masthead is the plan doc\'s OWN linked vision', () async {
      seedPlan();
      final PlanBoard board =
          ((await const VisionRepositoryImpl().loadPlan())
                  as Success<PlanBoard>)
              .data;
      expect(board.vision?.name, 'VIS-1');
      expect(board.vision?.title, 'Vision 2028');
      expect(board.vision?.description, 'A refill within reach.');
    });

    test(
      'the board is the plan for ITS vision: other visions\' pillars are not on it',
      () async {
        seedPlan();
        final PlanBoard board =
            ((await const VisionRepositoryImpl().loadPlan())
                    as Success<PlanBoard>)
                .data;
        expect(
          board.pillars.map((p) => p.name),
          ['PIL-CUS', 'PIL-OPS', 'PIL-NEW'],
          reason: 'VIS-0\'s pillar is off the board; an unlinked pillar stays',
        );
        expect(board.objectives.map((o) => o.name), ['OBJ-1', 'OBJ-3']);
        expect(
          board.pillarNamed('PIL-OPS')!.description,
          isNull,
          reason: 'an empty description is no description',
        );
      },
    );

    test('an unset link falls back to the one vision, and only then', () async {
      seedPlan();
      backend.replies[VisionCmds.plan] = <String, dynamic>{'vision': null};
      PlanBoard board =
          ((await const VisionRepositoryImpl().loadPlan())
                  as Success<PlanBoard>)
              .data;
      expect(
        board.vision,
        isNull,
        reason: 'two visions, no link: nobody chose',
      );

      backend.replies[VisionCmds.visions] = <Map<String, dynamic>>[
        _visions.first,
      ];
      board =
          ((await const VisionRepositoryImpl().loadPlan())
                  as Success<PlanBoard>)
              .data;
      expect(board.vision?.name, 'VIS-1');
    });

    test('the KPI count is DERIVED by counting get_kpis', () async {
      seedPlan();
      final PlanBoard board =
          ((await const VisionRepositoryImpl().loadPlan())
                  as Success<PlanBoard>)
              .data;
      expect(board.kpisRead, isTrue);
      expect(board.kpiCountFor('OBJ-3'), 2);
      expect(board.kpiCountFor('OBJ-1'), 0);
      expect(board.kpisOf('OBJ-3').map((k) => k.title), [
        'Uptime hours logged',
        'Services on schedule',
      ]);
    });

    test('get_kpis failing costs the count, never the board', () async {
      seedPlan();
      backend.replies[ObjectiveCmds.kpis] = 500;
      final ApiResult<PlanBoard> result = await const VisionRepositoryImpl()
          .loadPlan();
      expect(result, isA<Success<PlanBoard>>());
      final PlanBoard board = (result as Success<PlanBoard>).data;
      expect(board.kpisRead, isFalse);
      expect(board.kpiCountFor('OBJ-3'), isNull);
      expect(board.pillars, isNotEmpty);
    });

    test(
      'the plan doc or the visions failing costs the masthead, never the board',
      () async {
        seedPlan();
        backend.replies[VisionCmds.plan] = 404;
        backend.replies[VisionCmds.visions] = 500;
        final ApiResult<PlanBoard> result = await const VisionRepositoryImpl()
            .loadPlan();
        expect(result, isA<Success<PlanBoard>>());
        final PlanBoard board = (result as Success<PlanBoard>).data;
        expect(board.vision, isNull);
        expect(board.pillars, hasLength(4), reason: 'no vision to scope by');
      },
    );

    test('the pillars failing is a failure with the status', () async {
      seedPlan();
      backend.replies[ObjectiveCmds.pillars] = 403;
      final ApiResult<PlanBoard> result = await const VisionRepositoryImpl()
          .loadPlan();
      expect(result, isA<Failure<PlanBoard>>());
      expect((result as Failure<PlanBoard>).statusCode, 403);
      // Nothing after the failed read is asked for.
      expect(backend.cmds, ['tenant.api.get_pillars']);
    });
  });

  group('VisionRepositoryImpl.loadMasteryGoals', () {
    test(
      'asks get_personal_mastery_goals and reads exactly its fields',
      () async {
        backend.replies[VisionCmds.masteryGoals] = _goals;
        final ApiResult<List<MasteryGoal>> result =
            await const VisionRepositoryImpl().loadMasteryGoals();
        expect(backend.cmds, ['tenant.api.get_personal_mastery_goals']);
        final List<MasteryGoal> goals =
            (result as Success<List<MasteryGoal>>).data;
        expect(goals.map((g) => g.name), [
          'PMG-1',
          'PMG-2',
        ], reason: 'a row without a name is dropped rather than drawn blank');
        expect(goals.first.description, 'Read the P&L.');
      },
    );

    test(
      'todos are NULL when the row does not carry them, read when it does',
      () async {
        backend.replies[VisionCmds.masteryGoals] = _goals;
        final List<MasteryGoal> goals =
            ((await const VisionRepositoryImpl().loadMasteryGoals())
                    as Success<List<MasteryGoal>>)
                .data;
        expect(goals[0].todos, isNull);
        expect(goals[0].progress, isNull);
        expect(goals[1].todos, hasLength(2));
        expect(goals[1].todosDone, 1);
        expect(goals[1].todos![1].date, DateTime(2026, 9, 26));
      },
    );

    test('a failed read is a failure with the status, not a throw', () async {
      backend.replies[VisionCmds.masteryGoals] = 500;
      final ApiResult<List<MasteryGoal>> result =
          await const VisionRepositoryImpl().loadMasteryGoals();
      expect(result, isA<Failure<List<MasteryGoal>>>());
      expect((result as Failure<List<MasteryGoal>>).statusCode, 500);
    });
  });
}
