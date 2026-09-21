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

// Wire-level guard for WalletRepository's gateway calls (fix-wave
// 2026-09-02, P1): every wallet call must be a POST to the one platform
// gateway path carrying `{cmd, payload}`, where `cmd` is an alias some
// composed frappe manifest whitelists. The legacy per-method
// `/api/method/paas.api.user.get_wallet_history` GET this replaced is not
// served by any composed backend, so a regression here is a silent 404 in
// production, not a compile error.

import 'dart:convert';
import 'dart:typed_data';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/models/data/wallet_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_sdk/src/common/infrastructure/repositories/wallet_repository.dart';

/// [HttpService] whose Dio answers every request from [handle] — the same
/// substitution seam production uses (`getIt<HttpService>` via `dioHttp`),
/// so the REAL PlatformGateway + repository code runs against a scripted
/// backend and the actual wire path/body are captured.
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

ResponseBody _json(Object? body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// One Frappe `Wallet History` row exactly as
/// users.tenant.api.user.get_wallet_history returns it.
const _row = {
  'name': 'WH-0001',
  'transaction_type': 'Topup',
  'amount': 250.0,
  'status': 'Processed',
  'creation': '2026-09-01 10:00:00.000000',
  'description': 'Wallet top-up',
};

void main() {
  late List<RequestOptions> requests;

  void install(ResponseBody Function(RequestOptions options) handle) {
    if (getIt.isRegistered<HttpService>()) {
      getIt.unregister<HttpService>();
    }
    getIt.registerSingleton<HttpService>(_FakeHttpService((options) {
      requests.add(options);
      return handle(options);
    }));
    addTearDown(() => getIt.unregister<HttpService>());
  }

  setUp(() => requests = []);

  group('WalletRepository.getWalletHistory', () {
    test('POSTs cmd api.user.get_wallet_history to the platform gateway',
        () async {
      // Interceptor-less fake: the body still carries Frappe's `message`
      // envelope, which the repository tolerates (same as walletTopUp).
      install((_) => _json({
            'message': {
              'data': [_row],
              'status_code': 200,
            },
          }));

      final result = await WalletRepository().getWalletHistory();

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.path, kPlatformGatewayPath);
      expect(request.path, isNot(contains('paas.api')));
      final body = request.data as Map;
      expect(body['cmd'], 'api.user.get_wallet_history');
      // The server's own kwargs, defaults matching its signature.
      expect(body['payload'], {'start': 0, 'limit': 20});

      expect(result, isA<Success<List<WalletHistoryData>>>());
      final rows = (result as Success<List<WalletHistoryData>>).data;
      expect(rows, hasLength(1));
      expect(rows.single.status, 'Processed');
    });

    test('forwards explicit start/limit paging kwargs', () async {
      install((_) => _json({'data': <Object>[], 'status_code': 200}));

      final result =
          await WalletRepository().getWalletHistory(start: 40, limit: 10);

      final body = requests.single.data as Map;
      expect(body['payload'], {'start': 40, 'limit': 10});
      expect(result, isA<Success<List<WalletHistoryData>>>());
      expect((result as Success<List<WalletHistoryData>>).data, isEmpty);
    });

    test('accepts the interceptor-unwrapped {data: [...]} shape', () async {
      // What the production Dio stack hands over: FrappeResponseInterceptor
      // has already stripped `message`, leaving api_response's own map.
      install((_) => _json({
            'data': [_row, _row],
            'status_code': 200,
          }));

      final result = await WalletRepository().getWalletHistory();

      expect(result, isA<Success<List<WalletHistoryData>>>());
      expect((result as Success<List<WalletHistoryData>>).data, hasLength(2));
    });

    test('a server error surfaces as ApiResult.failure with its status',
        () async {
      install((_) => _json({'message': 'Wallet not found'}, 500));

      final result = await WalletRepository().getWalletHistory();

      expect(result, isA<Failure<List<WalletHistoryData>>>());
      final failure = result as Failure<List<WalletHistoryData>>;
      expect(failure.statusCode, 500);
      expect(failure.error, isNotEmpty);
    });
  });
}
