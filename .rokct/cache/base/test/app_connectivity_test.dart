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


import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/services/app_connectivity.dart';

/// Frappe wraps whitelisted-method returns under `message`; api_status's
/// api_response wrapper nests its payload under `data`.
String apiStatusBody(String status) => jsonEncode({
      'message': {
        'data': {'status': status, 'version': '15', 'user': 'Guest'},
        'status_code': 200,
      },
    });

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  /// Stubs the connectivity_plus radio check ('check') to report [results]
  /// (e.g. ['wifi'] or ['none']) so tests control the fast-path.
  void stubRadio(List<String> results) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') return results;
      return null;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
  });

  group('backendStatus', () {
    test('radio off short-circuits to down without probing the backend',
        () async {
      stubRadio(['none']);
      var probed = false;
      final client = MockClient((request) async {
        probed = true;
        return http.Response(apiStatusBody('ok'), 200);
      });

      expect(
        await AppConnectivity.backendStatus(client: client),
        BackendStatus.down,
      );
      expect(probed, isFalse);
      expect(await AppConnectivity.backendAvailability(client: client),
          isFalse);
    });

    test('HTTP 200 with status ok reports up', () async {
      stubRadio(['wifi']);
      late http.Request requested;
      final client = MockClient((request) async {
        requested = request;
        return http.Response(apiStatusBody('ok'), 200);
      });

      expect(
        await AppConnectivity.backendStatus(client: client),
        BackendStatus.up,
      );
      // The probe rides the universal gateway envelope: a POST to the
      // shared gateway path with the prefix-free dotted cmd.
      expect(requested.method, 'POST');
      expect(requested.url.path, endsWith(kPlatformGatewayPath));
      expect(
        jsonDecode(requested.body),
        {'cmd': 'api.system.api_status'},
      );
      expect(
          await AppConnectivity.backendAvailability(client: client), isTrue);
    });

    test('HTTP 200 with status maintenance reports maintenance', () async {
      stubRadio(['wifi']);
      final client = MockClient(
        (request) async => http.Response(apiStatusBody('maintenance'), 200),
      );

      expect(
        await AppConnectivity.backendStatus(client: client),
        BackendStatus.maintenance,
      );
      // The simple bool gate treats maintenance as unavailable.
      expect(
          await AppConnectivity.backendAvailability(client: client), isFalse);
    });

    test('non-200 reports down', () async {
      stubRadio(['wifi']);
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );

      expect(
        await AppConnectivity.backendStatus(client: client),
        BackendStatus.down,
      );
    });

    test('a 200 that is not the api_status JSON (captive portal) is down',
        () async {
      stubRadio(['wifi']);
      final client = MockClient(
        (request) async => http.Response('<html>login</html>', 200),
      );

      expect(
        await AppConnectivity.backendStatus(client: client),
        BackendStatus.down,
      );
    });

    test('a thrown client error reports down', () async {
      stubRadio(['wifi']);
      final client = MockClient(
        (request) async => throw http.ClientException('connection refused'),
      );

      expect(
        await AppConnectivity.backendStatus(client: client),
        BackendStatus.down,
      );
    });

    test('a hung request times out to down', () async {
      stubRadio(['wifi']);
      final never = Completer<http.Response>();
      final client = MockClient((request) => never.future);

      expect(
        await AppConnectivity.backendStatus(
          timeout: const Duration(milliseconds: 50),
          client: client,
        ),
        BackendStatus.down,
      );
    });
  });
}
