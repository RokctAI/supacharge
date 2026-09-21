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

// AppUsageService over the telemetry lane: the once-per-day `app_open`
// day-marker guard (send exactly once per day, and only burn the day's
// slot when delivery actually happened), the gateway stats read
// (tenant.api.get_app_usage_stats) with its cached-offline fallback, and
// the local ISO-week counter that fills days_in_app_this_week when the
// backend does not serve it.

import 'dart:convert';

import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/storage_keys.dart';
import 'package:base_sdk/src/services/telemetry.dart';
import 'package:base_sdk/src/utils/app_usage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HttpService whose Dio never touches the network: every request resolves
/// (or throws) through [respond] — the same stubbing shape as
/// token_refresh_service_test's stubbedDio.
class _StubHttpService extends HttpService {
  _StubHttpService(this.respond);

  final dynamic Function(RequestOptions options) respond;

  @override
  Dio client({bool requireAuth = false, bool routing = false}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://unit.test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        try {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: respond(options),
            ),
            true,
          );
        } on DioException catch (e) {
          handler.reject(e, true);
        }
      },
    ));
    return dio;
  }
}

Future<void> _initStorage({String token = 'unit-test-token'}) async {
  SharedPreferences.setMockInitialValues({StorageKeys.keyToken: token});
  await LocalStorage.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'TestApp',
      packageName: 'test.app',
      version: '9.9.9',
      buildNumber: '77',
      buildSignature: '',
      installerStore: null,
    );
  });

  tearDown(() {
    // Both seams are app-global; never let one test's wiring leak.
    TelemetryClient.configure(transport: null);
    final getIt = GetIt.instance;
    if (getIt.isRegistered<HttpService>()) {
      getIt.unregister<HttpService>();
    }
  });

  group('recordAppOpenIfNeeded day-marker guard', () {
    test('sends app_open once, marks the day, counts the week', () async {
      await _initStorage();
      final delivered = <Map<String, dynamic>>[];
      TelemetryClient.configure(transport: (cmd, payload) async {
        delivered.add({'cmd': cmd, ...payload});
      });

      await AppUsageService.recordAppOpenIfNeeded();

      expect(delivered, hasLength(1));
      expect(delivered.single['cmd'], TelemetryClient.trackCmd);
      expect(delivered.single['event'], AppUsageService.appOpenEvent);
      final context =
          jsonDecode(delivered.single['context'] as String) as Map;
      expect(context['properties']['app_version'], '9.9.9');
      expect(context['properties']['build_number'], '77');
      expect(context['properties']['platform'], isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      expect(prefs.getString('last_usage_recorded'), today);
      expect(prefs.getInt('app_usage_days_this_week'), 1);

      // Same day again: the marker holds, nothing more is sent.
      await AppUsageService.recordAppOpenIfNeeded();
      expect(delivered, hasLength(1));
      expect(prefs.getInt('app_usage_days_this_week'), 1);
    });

    test('a failed delivery does not burn the day slot', () async {
      await _initStorage();
      var attempts = 0;
      var fail = true;
      TelemetryClient.configure(transport: (cmd, payload) async {
        attempts++;
        if (fail) throw Exception('offline');
      });

      await AppUsageService.recordAppOpenIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      // Two attempts per failed send: the tenant cmd, then the one-shot
      // control-role fallback (TranslationSeeder's retry shape).
      expect(attempts, 2);
      expect(prefs.getString('last_usage_recorded'), isNull);
      expect(prefs.getInt('app_usage_days_this_week'), isNull);

      // Connectivity back: the same day retries and then marks.
      fail = false;
      await AppUsageService.recordAppOpenIfNeeded();
      expect(attempts, 3);
      final today = DateTime.now().toIso8601String().split('T')[0];
      expect(prefs.getString('last_usage_recorded'), today);
      expect(prefs.getInt('app_usage_days_this_week'), 1);
    });

    test('control-role fallback: a rejected tenant cmd retries once with '
        'the control: prefix and still marks the day', () async {
      await _initStorage();
      final cmds = <String>[];
      TelemetryClient.configure(transport: (cmd, payload) async {
        cmds.add(cmd);
        // A control-role gateway rejects the unprefixed tenant cmd; the
        // control-role key is accepted.
        if (cmd == TelemetryClient.trackCmd) {
          throw Exception('control gateway: unknown cmd');
        }
      });

      await AppUsageService.recordAppOpenIfNeeded();

      expect(cmds,
          [TelemetryClient.trackCmd, TelemetryClient.controlTrackCmd]);
      // Delivered via the control twin: the day slot IS burned.
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      expect(prefs.getString('last_usage_recorded'), today);
      expect(prefs.getInt('app_usage_days_this_week'), 1);
    });

    test('anonymous launch records nothing (auth-required lane)', () async {
      await _initStorage(token: '');
      var attempts = 0;
      TelemetryClient.configure(transport: (cmd, payload) async {
        attempts++;
      });

      await AppUsageService.recordAppOpenIfNeeded();
      expect(attempts, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_usage_recorded'), isNull);
    });
  });

  group('getAppUsageStats over the gateway', () {
    test('parses the stats payload and caches it', () async {
      await _initStorage();
      late Map<String, dynamic> sentBody;
      GetIt.instance.registerSingleton<HttpService>(
        _StubHttpService((options) {
          sentBody = Map<String, dynamic>.from(options.data as Map);
          return {
            'status': 'success',
            'data': {
              'days_in_app_this_week': 3,
              'days_in_app_this_year': 45,
            },
          };
        }),
      );

      final stats = await AppUsageService.getAppUsageStats();

      expect(sentBody['cmd'], AppUsageService.statsCmd);
      expect(stats['days_in_app_this_year'], 45);
      // Backend-served week figure wins over the local counter.
      expect(stats[AppUsageService.weekStatKey], 3);

      final prefs = await SharedPreferences.getInstance();
      final cached =
          jsonDecode(prefs.getString('app_usage_stats')!) as Map;
      expect(cached['days_in_app_this_year'], 45);
    });

    test('missing week figure falls back to the local counter', () async {
      await _initStorage();
      final delivered = <String>[];
      TelemetryClient.configure(transport: (cmd, payload) async {
        delivered.add(payload['event'] as String);
      });
      // Today's app_open puts 1 in the local ISO-week counter.
      await AppUsageService.recordAppOpenIfNeeded();
      expect(delivered, ['app_open']);

      GetIt.instance.registerSingleton<HttpService>(
        _StubHttpService((options) => {
              'status': 'success',
              'data': {'days_in_app_this_year': 45},
            }),
      );

      final stats = await AppUsageService.getAppUsageStats();
      expect(stats['days_in_app_this_year'], 45);
      expect(stats[AppUsageService.weekStatKey], 1);
    });

    test('control-role fallback: a rejected tenant cmd retries once with '
        'the control: prefix and parses its stats', () async {
      await _initStorage();
      final cmds = <String>[];
      GetIt.instance.registerSingleton<HttpService>(
        _StubHttpService((options) {
          final cmd = (options.data as Map)['cmd'] as String;
          cmds.add(cmd);
          if (cmd == AppUsageService.statsCmd) {
            // A control-role gateway rejects the unprefixed tenant cmd.
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
            );
          }
          return {
            'status': 'success',
            'data': {
              'days_in_app_this_week': 2,
              'days_in_app_this_year': 9,
            },
          };
        }),
      );

      final stats = await AppUsageService.getAppUsageStats();

      expect(cmds,
          [AppUsageService.statsCmd, AppUsageService.controlStatsCmd]);
      expect(stats['days_in_app_this_year'], 9);
      expect(stats[AppUsageService.weekStatKey], 2);
    });

    test('a failing gateway call answers from the cache', () async {
      await _initStorage();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'app_usage_stats',
        jsonEncode({'days_in_app_this_year': 12}),
      );
      GetIt.instance.registerSingleton<HttpService>(
        _StubHttpService((options) => throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            )),
      );

      final stats = await AppUsageService.getAppUsageStats();
      expect(stats['days_in_app_this_year'], 12);
      // No week figure served and no local count: 0, not absent.
      expect(stats[AppUsageService.weekStatKey], 0);
    });
  });

  group('isoWeekKey', () {
    test('keys by the ISO week of the date\'s Thursday', () {
      // 2026-01-01 is a Thursday: ISO week 1 of 2026.
      expect(AppUsageService.isoWeekKey(DateTime(2026, 1, 1)), '2026-W1');
      // 2024-12-30 (Monday) belongs to 2025's week 1.
      expect(AppUsageService.isoWeekKey(DateTime(2024, 12, 30)), '2025-W1');
      // Mid-year sanity: 2026-08-28 is in ISO week 35.
      expect(AppUsageService.isoWeekKey(DateTime(2026, 8, 28)), '2026-W35');
    });
  });
}
