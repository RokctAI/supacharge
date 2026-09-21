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

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/handlers/log_redaction.dart';

/// A credential is a credential whatever it is worth: this stand-in is
/// shaped like the real thing (40 hex characters) and is not one. Nothing
/// in this file, or in the log lines it captures, may ever be a real key.
const String kFakeCredential = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

/// The contract under test: NOTHING that prints a request may print a
/// credential that travelled with it.
///
/// A request URI reaches a log from several directions — Dio's own
/// `LogInterceptor` on every request and every failure, the network error
/// funnel forwarding it to telemetry — and a debug console is copied
/// verbatim into CI job logs. So the redactor is asserted on the emitted
/// STRING, not on an intermediate object: the test fails if the secret
/// survives anywhere in what would have been written down.
void main() {
  group('redactUri', () {
    test('hides a credential parameter and keeps everything else', () {
      final Uri uri = Uri.parse(
        'https://api.example.org/v2/directions/driving-car'
        '?api_key=$kFakeCredential&start=8.68,49.41&end=8.69,49.42',
      );

      final String redacted = redactUri(uri).toString();

      expect(redacted, isNot(contains(kFakeCredential)));
      expect(redacted, contains('api_key=$kRedactedValue'));
      // The rest of the request is exactly as it was — a redacted URI is
      // still worth reading when the failure is real.
      expect(redacted, contains('api.example.org'));
      expect(redacted, contains('/v2/directions/driving-car'));
      expect(redacted, contains('start=8.68,49.41'));
      expect(redacted, contains('end=8.69,49.42'));
    });

    test('covers the other credential parameter names in use', () {
      for (final String name in <String>[
        'apikey',
        'api-key',
        'key',
        'token',
        'access_token',
        'API_KEY',
        'Token',
      ]) {
        final Uri uri =
            Uri.parse('https://example.org/p?$name=$kFakeCredential&keep=1');
        final String redacted = redactUri(uri).toString();
        expect(redacted, isNot(contains(kFakeCredential)), reason: name);
        expect(redacted, contains('keep=1'), reason: name);
      }
    });

    test('leaves a URI with nothing sensitive in it untouched', () {
      final Uri uri = Uri.parse('https://example.org/p?start=1&end=2');
      expect(redactUri(uri), same(uri));
    });
  });

  group('redactLogText', () {
    test('redacts a credential inside running text and JSON', () {
      final String line = redactLogText(
        'DioException: GET https://api.example.org/v2/directions/driving-car'
        '?api_key=$kFakeCredential&start=8.68,49.41 failed with 403',
      );
      expect(line, isNot(contains(kFakeCredential)));
      expect(line, contains('start=8.68,49.41'));
      expect(line, contains('403'));

      final String payload = redactLogText(
        '{"type":"network_unreachable","context":'
        '{"url":"https://api.example.org/p?token=$kFakeCredential"}}',
      );
      expect(payload, isNot(contains(kFakeCredential)));
      expect(payload, contains('network_unreachable'));
    });

    test('redacts a header line but not a header name inside a body', () {
      expect(
        redactLogText('authorization: Bearer $kFakeCredential'),
        'authorization: $kRedactedValue',
      );
      // The provider header names the feature SDKs actually send.
      for (final String header in <String>[
        'X-Goog-Api-Key',
        'X-RapidAPI-Key',
        'x-api-key',
        'Cookie',
      ]) {
        final String line = redactLogText('$header: $kFakeCredential');
        expect(line, isNot(contains(kFakeCredential)), reason: header);
        expect(line, startsWith('$header:'), reason: header);
      }
      // The provider's own 401 body names the header; that is not a value.
      const String body = '{"error": "Authorization field missing"}';
      expect(redactLogText(body), body);
    });

    test('a null or empty object never blows up the logger', () {
      expect(redactLogText(null), '');
      expect(redactLogText(''), '');
    });
  });

  group('the Dio logging path', () {
    late List<String> printed;
    late DebugPrintCallback original;

    setUp(() {
      printed = <String>[];
      original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        printed.add(message ?? '');
      };
    });

    tearDown(() => debugPrint = original);

    Dio loggingDio() {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.org'))
        ..httpClientAdapter = _QuotaExceededAdapter()
        ..interceptors.add(
          LogInterceptor(
            responseHeader: false,
            requestHeader: true,
            responseBody: true,
            requestBody: true,
            logPrint: logRedactedLine,
          ),
        );
      return dio;
    }

    test(
        'a failing request with a credential query parameter logs the URI '
        'without the credential', () async {
      // A quota-limited provider answers 403 several times a day, so
      // this is the ordinary path, not the rare one: every one of those
      // failures writes a request line and an error line.
      await expectLater(
        loggingDio().get<dynamic>(
          '/v2/directions/driving-car',
          queryParameters: <String, dynamic>{
            'api_key': kFakeCredential,
            'start': '8.68,49.41',
            'end': '8.69,49.42',
          },
        ),
        throwsA(isA<DioException>()),
      );

      final String log = printed.join('\n');
      // The request line AND the error line were emitted...
      expect(log, contains('/v2/directions/driving-car'));
      // Dio percent-encodes the comma it builds the query with; the point
      // is that the coordinates are still there to read.
      expect(log, contains('start=8.68'));
      expect(log, contains('end=8.69'));
      expect(log, contains('403'));
      // ...and neither of them carries the credential.
      expect(log, isNot(contains(kFakeCredential)));
      expect(log, contains('api_key=$kRedactedValue'));
    });

    test('a credential moved into the Authorization header is not logged '
        'either', () async {
      final Dio dio = loggingDio()
        ..options.headers['Authorization'] = kFakeCredential;

      await expectLater(
        dio.get<dynamic>('/v2/directions/driving-car'),
        throwsA(isA<DioException>()),
      );

      final String log = printed.join('\n');
      expect(log, contains('/v2/directions/driving-car'));
      expect(log, isNot(contains(kFakeCredential)));
    });
  });

  group('RoutingCredentialInterceptor', () {
    test('promotes api_key out of the query string into the header',
        () async {
      final _CapturingAdapter adapter = _CapturingAdapter();
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.org'))
        ..httpClientAdapter = adapter
        ..interceptors.add(const RoutingCredentialInterceptor());

      await dio.get<dynamic>(
        '/v2/directions/driving-car',
        queryParameters: <String, dynamic>{
          'api_key': kFakeCredential,
          'start': '8.68,49.41',
        },
      );

      final RequestOptions sent = adapter.captured!;
      // The wire URL — what every proxy, server access log and CI log
      // downstream of here would see.
      expect(sent.uri.toString(), isNot(contains(kFakeCredential)));
      expect(sent.uri.queryParameters, isNot(contains('api_key')));
      expect(sent.uri.queryParameters['start'], '8.68,49.41');
      expect(sent.headers['Authorization'], kFakeCredential);
    });

    test('strips a credential appended to the path as well', () async {
      final _CapturingAdapter adapter = _CapturingAdapter();
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.org'))
        ..httpClientAdapter = adapter
        ..interceptors.add(const RoutingCredentialInterceptor());

      await dio.get<dynamic>(
        '/v2/directions/driving-car?api_key=$kFakeCredential&start=1,2',
      );

      final RequestOptions sent = adapter.captured!;
      expect(sent.uri.toString(), isNot(contains(kFakeCredential)));
      expect(sent.uri.toString(), contains('start=1,2'));
      expect(sent.headers['Authorization'], kFakeCredential);
    });

    test('an explicit key wins and a request without one is left alone',
        () async {
      final _CapturingAdapter adapter = _CapturingAdapter();
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.org'))
        ..httpClientAdapter = adapter
        ..interceptors.add(const RoutingCredentialInterceptor(apiKey: 'k'));
      await dio.get<dynamic>('/v2/directions/driving-car');
      expect(adapter.captured!.headers['Authorization'], 'k');

      final _CapturingAdapter bare = _CapturingAdapter();
      final Dio unkeyed = Dio(BaseOptions(baseUrl: 'https://api.example.org'))
        ..httpClientAdapter = bare
        ..interceptors.add(const RoutingCredentialInterceptor(apiKey: ''));
      await unkeyed.get<dynamic>('/v2/directions/driving-car');
      expect(bare.captured!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('HttpService wiring', () {
    test('the routing client strips the key and redacts what it logs', () {
      final Dio dio = HttpService().client(routing: true);

      expect(
        dio.interceptors.whereType<RoutingCredentialInterceptor>(),
        isNotEmpty,
        reason: 'routing requests must not carry a credential in the URL',
      );
      // kDebugMode is true under `flutter test`, so the log interceptor is
      // present here exactly as it is in a debug/guided-tour build.
      final Iterable<LogInterceptor> logs =
          dio.interceptors.whereType<LogInterceptor>();
      expect(logs, isNotEmpty);
      for (final LogInterceptor log in logs) {
        expect(
          log.logPrint,
          same(logRedactedLine),
          reason: 'no LogInterceptor may print a raw request',
        );
      }
    });

    test('the ordinary client redacts what it logs too', () {
      final Dio dio = HttpService().client();
      expect(
        dio.interceptors.whereType<RoutingCredentialInterceptor>(),
        isEmpty,
      );
      for (final LogInterceptor log
          in dio.interceptors.whereType<LogInterceptor>()) {
        expect(log.logPrint, same(logRedactedLine));
      }
    });
  });
}

/// Answers every request the way the routing provider answers a free-tier
/// caller that has run out of quota.
class _QuotaExceededAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error":"Quota exceeded"}',
      403,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Keeps the request as it would have gone out on the wire.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? captured;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
