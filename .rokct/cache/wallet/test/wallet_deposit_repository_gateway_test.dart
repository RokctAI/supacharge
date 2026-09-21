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

// Wire-level guard for WalletDepositRepository (design strip frames
// 49g/49h/49i): every deposit call must be a POST to the one platform
// gateway path carrying `{cmd, payload}` where `cmd` is a key wallet's
// frappe manifest whitelists under `{app_name}.api.wallet.*`, and the typed
// records must read the defs' real answer shapes. The money-model facts
// the client draws from — submit moves nothing, the balance on the wire is
// NOT net of the pending deposit, a rejection carries its reason — are
// pinned here so a later edit cannot quietly invert them.

import 'dart:convert';
import 'dart:typed_data';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:wallet_sdk/wallet_sdk.dart';

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

/// One row exactly as `list_deposit_requests` serves it. Dummy reference,
/// dummy file path — nothing here names a real person or account.
const _pending = {
  'id': 'WDR-0001',
  'amount': 1240.0,
  'method': 'Bank Deposit',
  'reference': 'TM-0831-1642',
  'slip': '/files/slip-0831-1642.jpg',
  'note': null,
  'status': 'Pending',
  'rejection_reason': null,
  'balance_at_submit': -1240.0,
  'submitted_at': '2026-08-31 16:58:00.000000',
  'resolved_at': null,
  'credited': 0,
};

const _rejected = {
  'id': 'WDR-0002',
  'amount': 600.0,
  'method': 'Bank Deposit',
  'reference': 'TM-0829-0812',
  'slip': '/files/slip-0829-0812.jpg',
  'status': 'Rejected',
  'rejection_reason': 'Slip says R 600.00, the bank received R 300.00.',
  'submitted_at': '2026-08-29 08:20:00',
  'resolved_at': '2026-08-29 10:00:00',
  'credited': 0,
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

  RequestOptions single() {
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.path, kPlatformGatewayPath);
    expect(request.path, isNot(contains('paas.api')));
    return request;
  }

  setUp(() => requests = []);

  group('WalletDepositRepository', () {
    test('getDepositDestination posts api.wallet.get_deposit_destination',
        () async {
      install((_) => _json({
            'message': {
              'accepting': true,
              'account_holder_name': 'Test Operations',
              'bank_name': 'Test Bank',
              'account_number': '0000004417',
              'branch_code': '000000',
              'account_type': 'Cheque',
              'instructions': 'Write your reference on the slip.',
              'methods': ['Bank Deposit', 'EFT'],
            },
          }));

      final result = await WalletDepositRepository().getDepositDestination();

      final body = single().data as Map;
      expect(body['cmd'], 'api.wallet.get_deposit_destination');
      expect(body.containsKey('payload'), isFalse);
      final destination =
          (result as Success<WalletDepositDestination>).data;
      expect(destination.accepting, isTrue);
      expect(destination.accountNumber, '0000004417');
      expect(destination.maskedAccountNumber, '•••• 4417');
      expect(destination.methods, ['Bank Deposit', 'EFT']);
    });

    test('submitDepositRequest sends amount, method and slip; keeps the '
        'wire balance un-netted', () async {
      install((_) => _json({
            'success': true,
            'request_id': 'WDR-0001',
            'reference': 'TM-0831-1642',
            'amount': 1240.0,
            'method': 'Bank Deposit',
            'status': 'Pending',
            'submitted_at': '2026-08-31 16:58:00',
            'balance': -1240.0,
          }));

      final result = await WalletDepositRepository().submitDepositRequest(
        amount: 1240,
        slipUrl: '/files/slip-0831-1642.jpg',
        reference: '  TM-0831-1642 ',
        note: '',
      );

      final body = single().data as Map;
      expect(body['cmd'], 'api.wallet.submit_deposit_request');
      expect(body['payload'], {
        'amount': 1240.0,
        'method': 'Bank Deposit',
        'slip': '/files/slip-0831-1642.jpg',
        'reference': 'TM-0831-1642',
      });
      final answer = (result as Success<WalletDepositSubmitResponse>).data;
      expect(answer.success, isTrue);
      expect(answer.status, WalletDepositStatus.pending);
      expect(answer.reference, 'TM-0831-1642');
      // Submit moves NOTHING: the balance the server reports is still the
      // debt, and the client must draw it as such.
      expect(answer.balance, -1240.0);
    });

    test('listDepositRequests posts the cmd and parses every state',
        () async {
      install((_) => _json([_pending, _rejected]));

      final result = await WalletDepositRepository().listDepositRequests();

      expect((single().data as Map)['cmd'], 'api.wallet.list_deposit_requests');
      final rows = (result as Success<List<WalletDepositRecord>>).data;
      expect(rows, hasLength(2));
      expect(rows.first.status, WalletDepositStatus.pending);
      expect(rows.first.isLive, isTrue);
      expect(rows.first.reference, 'TM-0831-1642');
      expect(rows.first.balanceAtSubmit, -1240.0);
      expect(rows.first.submittedAt, DateTime(2026, 8, 31, 16, 58));
      expect(rows.last.status, WalletDepositStatus.rejected);
      expect(rows.last.status.isTerminal, isTrue);
      expect(rows.last.rejectionReason, contains('R 300.00'));
    });

    test('a non-list answer parses to no rows', () async {
      install((_) => _json({'message': 'nothing'}));
      final result = await WalletDepositRepository().listDepositRequests();
      expect((result as Success<List<WalletDepositRecord>>).data, isEmpty);
    });

    test('listPendingDepositRequests carries the payer', () async {
      install((_) => _json([
            {..._pending, 'user': 'driver@example.com', 'user_name': 'Thabo M'},
          ]));

      final result =
          await WalletDepositRepository().listPendingDepositRequests();

      expect(
        (single().data as Map)['cmd'],
        'api.wallet.list_pending_deposit_requests',
      );
      final rows = (result as Success<List<WalletDepositRecord>>).data;
      expect(rows.single.userName, 'Thabo M');
      expect(rows.single.userId, 'driver@example.com');
    });

    test('approveDepositRequest posts the request id and reads the credit',
        () async {
      install((_) => _json({
            'approved': true,
            'request_id': 'WDR-0001',
            'amount': 1240.0,
            'new_balance': 0.0,
          }));

      final result =
          await WalletDepositRepository().approveDepositRequest('WDR-0001');

      final body = single().data as Map;
      expect(body['cmd'], 'api.wallet.approve_deposit_request');
      expect(body['payload'], {'request_id': 'WDR-0001'});
      final resolution = (result as Success<WalletDepositResolution>).data;
      expect(resolution.status, WalletDepositStatus.approved);
      expect(resolution.newBalance, 0.0);
    });

    test('rejectDepositRequest posts the trimmed reason', () async {
      install((_) => _json({
            'rejected': true,
            'request_id': 'WDR-0002',
            'reason': 'Slip says R 600.00, the bank received R 300.00.',
          }));

      final result = await WalletDepositRepository().rejectDepositRequest(
        'WDR-0002',
        reason: ' Slip says R 600.00, the bank received R 300.00. ',
      );

      final body = single().data as Map;
      expect(body['cmd'], 'api.wallet.reject_deposit_request');
      expect(body['payload'], {
        'request_id': 'WDR-0002',
        'reason': 'Slip says R 600.00, the bank received R 300.00.',
      });
      final resolution = (result as Success<WalletDepositResolution>).data;
      expect(resolution.status, WalletDepositStatus.rejected);
      expect(resolution.reason, contains('R 300.00'));
    });

    test('a server refusal surfaces as ApiResult.failure with its status',
        () async {
      install((_) => _json({'message': 'You are not allowed to review deposits.'}, 500));

      final result =
          await WalletDepositRepository().approveDepositRequest('WDR-0001');

      final failure = result as Failure<WalletDepositResolution>;
      expect(failure.statusCode, 500);
      expect(failure.error, isNotEmpty);
    });
  });

  group('WalletSdkDependencies', () {
    test('registers the deposit facade, guarded', () {
      final scoped = GetIt.asNewInstance();
      WalletSdkDependencies.register(scoped);
      expect(scoped.isRegistered<WalletDepositRepositoryFacade>(), isTrue);
      WalletSdkDependencies.register(scoped);
      expect(scoped<WalletDepositRepositoryFacade>(),
          isA<WalletDepositRepository>());
    });
  });
}
