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


// The boot path with no backend behind it.
//
// AppConstants.baseUrl is empty in a test process, so every gateway call
// this page makes is a call to an unreachable host - the same shape as an
// app shipped before its tenant site is deployed. What these tests hold
// down is that such a launch ends on a real screen, that the reason rides
// telemetry instead of the screen, and that a composition missing a route
// can no longer strand the app on the splash artwork (the failure mode that
// hid for as long as it did precisely because the throw happened inside an
// un-awaited future, where no test and no catch could see it).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/application/splash/splash_notifier.dart';
import 'package:base_sdk/src/application/splash/splash_provider.dart';
import 'package:base_sdk/src/domain/interface/settings.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/response/global_settings_response.dart';
import 'package:base_sdk/src/models/response/mobile_translations_response.dart';
import 'package:base_sdk/src/navigation/app_routes.dart';
import 'package:base_sdk/src/presentation/pages/initial/splash/splash_page.dart';
import 'package:base_sdk/src/services/telemetry.dart';

/// Stands in for the host's `_HostAppRoutes`: records every destination the
/// boot path asks for, and throws exactly the way that generated class's
/// `noSuchMethod` does for destinations no installed SDK declares.
class _HostRoutesDouble implements AppRoutes {
  _HostRoutesDouble({this.undeclared = const <String>{}});

  /// Method names that behave as if no installed SDK declared them.
  final Set<String> undeclared;

  final List<String> calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName
        .toString()
        .replaceAll('Symbol("', '')
        .replaceAll('")', '');
    calls.add(name);
    if (undeclared.contains(name) || undeclared.contains('*')) {
      throw StateError(
        'AppRoutes.I.$name has not been implemented - no installed SDK '
        'declares it in "app_routes"',
      );
    }
    return Future<Object?>.value();
  }
}

/// A settings backend that is simply not there. Counts its calls so a test
/// can prove the boot path did not queue up doomed requests.
class _DeadSettingsRepository implements SettingsRepositoryFacade {
  int translationCalls = 0;
  int settingsCalls = 0;

  @override
  Future<ApiResult<MobileTranslationsResponse>> getMobileTranslations() async {
    translationCalls++;
    return const ApiResult.failure(
      error: 'DioException: Connection refused',
      statusCode: 500,
    );
  }

  @override
  Future<ApiResult<GlobalSettingsResponse>> getGlobalSettings() async {
    settingsCalls++;
    return const ApiResult.failure(
      error: 'DioException: Connection refused',
      statusCode: 500,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used by boot');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppRoutes originalRoutes;
  late List<Map<String, dynamic>> telemetry;

  /// Everything the app sends through the one telemetry door, decoded.
  void captureTelemetry() {
    telemetry = <Map<String, dynamic>>[];
    TelemetryClient.configure(transport: (cmd, payload) async {
      final context = payload['context'];
      telemetry.add(<String, dynamic>{
        'cmd': cmd,
        'error_message': payload['error_message'],
        if (context is String) ...jsonDecode(context) as Map<String, dynamic>,
      });
    });
  }

  Map<String, dynamic>? eventOfType(String type) {
    for (final event in telemetry) {
      if (event['type'] == type) return event;
      if (event['error_message'] == type) return event;
    }
    return null;
  }

  // The device radio is on: this is an app whose tenant site is not
  // deployed, not a phone in a tunnel. connectivity_plus answers through a
  // platform channel whose reply never lands inside a widget test's fake
  // clock, so it has to be stubbed for the boot path to run at all.
  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() {
    originalRoutes = AppRoutes.I;
    captureTelemetry();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') return <String>['wifi'];
      return null;
    });
  });

  tearDown(() {
    AppRoutes.I = originalRoutes;
    TelemetryClient.configure();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
  });

  Future<void> pumpSplash(WidgetTester tester,
      {required SettingsRepositoryFacade settings}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          splashProvider.overrideWith((ref) => SplashNotifier(settings)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => const MaterialApp(home: SplashPage()),
        ),
      ),
    );
    // The boot path runs from a post-frame callback and awaits real
    // timeouts (the 5s api_status probe, the 2s offline hold). Widget tests
    // run on fake time, so those only elapse while we pump - 60s of it,
    // comfortably past every bound on the path.
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
  }

  /// Nothing the person at the screen can read may carry admin-grade detail.
  void expectNoDiagnosticsOnScreen(WidgetTester tester) {
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' | ')
        .toLowerCase();
    for (final leak in ['stateerror', 'exception', 'dioexception',
      'nosuchmethod', 'connection refused', 'app_routes']) {
      expect(shown.contains(leak), isFalse,
          reason: 'diagnostic detail leaked to the screen: $shown');
    }
  }

  group('splash with an unreachable backend', () {
    testWidgets('reaches a real screen instead of staying on the splash',
        (tester) async {
      final routes = _HostRoutesDouble();
      AppRoutes.I = routes;
      final settings = _DeadSettingsRepository();

      await pumpSplash(tester, settings: settings);

      // No token was ever stored, so the boot path routes to login - the
      // destination a radio-style app points at its own home page. What
      // matters is that it asked for SOMETHING.
      expect(routes.calls, isNotEmpty,
          reason: 'the boot path never left the splash page');
      expect(routes.calls, contains('replaceLoginRoute'));
    });

    testWidgets('does not spend the dio timeouts on a backend already known '
        'to be down', (tester) async {
      final routes = _HostRoutesDouble();
      AppRoutes.I = routes;
      final settings = _DeadSettingsRepository();

      await pumpSplash(tester, settings: settings);

      // api_status already answered "down"; asking the same dead host for
      // translations cost two 30s dio timeouts and changed nothing.
      expect(settings.translationCalls, 0);
      // ...and neither did asking it for global settings, which getToken
      // awaited before it routed anywhere.
      expect(settings.settingsCalls, 0);
      expect(eventOfType('splash_backend_unreachable'), isNotNull,
          reason: 'the skip must still be visible to admins');
    });

    testWidgets('sends the cause to telemetry, never to the screen',
        (tester) async {
      AppRoutes.I = _HostRoutesDouble();

      await pumpSplash(tester, settings: _DeadSettingsRepository());

      final event = eventOfType('splash_backend_unreachable');
      expect(event, isNotNull);
      expect(event!['cmd'], anyOf(TelemetryClient.cmd, TelemetryClient.controlCmd));
      final context = event['context'] as Map<String, dynamic>;
      expect(context['stage'], 'splash');
      expect(context['detail'], isNotEmpty);
      // Empty BASE_URL is the "not configured" case, and the event says so
      // without carrying the URL itself.
      expect(context['base_url_configured'], isFalse);

      expectNoDiagnosticsOnScreen(tester);
    });
  });

  group('SplashNotifier.getToken with the radio off', () {
    testWidgets('hands control back instead of leaving the caller waiting',
        (tester) async {
      // The device dropped its network between the splash's own check and
      // this one. connectivityWithDialog puts a dialog up - but a dialog is
      // not a destination, and with no branch here the caller's callbacks
      // were never invoked at all: the splash simply stayed.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(connectivityChannel, (call) async {
        if (call.method == 'check') return <String>['none'];
        return null;
      });

      final notifier = SplashNotifier(_DeadSettingsRepository());
      final reached = <String>[];
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Builder(builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );
      await tester.pump();

      await notifier.getToken(
        capturedContext,
        goMain: () => reached.add('main'),
        goLogin: () => reached.add('login'),
        goNoInternet: () => reached.add('no_connection'),
      );
      await tester.pump();

      expect(reached, ['no_connection']);
    });
  });

  group('SplashNotifier.getToken with the radio up and no backend', () {
    testWidgets('routes off the stored token without asking the backend',
        (tester) async {
      // The radio is up (the channel stub answers 'wifi') but the splash's
      // api_status probe already answered "down". getToken used to fall
      // straight into getGlobalSettings() here and the caller waited out the
      // dio timeout before any callback fired.
      final settings = _DeadSettingsRepository();
      final notifier = SplashNotifier(settings);
      final reached = <String>[];
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Builder(builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );
      await tester.pump();

      await notifier.getToken(
        capturedContext,
        backendUp: false,
        goMain: () => reached.add('main'),
        goLogin: () => reached.add('login'),
        goNoInternet: () => reached.add('no_connection'),
      );
      await tester.pump();

      // No token is stored in a test process, so login is the destination.
      expect(reached, ['login']);
      expect(settings.settingsCalls, 0);
    });
  });

  group('splash with a composition that declares no route', () {
    testWidgets('falls back to the no-connection page rather than stranding',
        (tester) async {
      // Exactly the radio composition before its manifest declared
      // app_routes: no home SDK route and no auth SDK route.
      final routes = _HostRoutesDouble(
        undeclared: {'replaceLoginRoute', 'replaceMainRoute'},
      );
      AppRoutes.I = routes;

      await pumpSplash(tester, settings: _DeadSettingsRepository());

      expect(routes.calls, contains('replaceLoginRoute'));
      expect(routes.calls, contains('replaceNoConnectionRoute'),
          reason: 'a failed navigation must still land somewhere');

      final event = eventOfType('splash_navigation_failed');
      expect(event, isNotNull);
      final context = event!['context'] as Map<String, dynamic>;
      expect(context['destination'], 'login');
      expect(context['detail'], contains('has not been implemented'));

      expectNoDiagnosticsOnScreen(tester);
    });

    testWidgets('renders an in-place screen when no route resolves at all',
        (tester) async {
      final routes = _HostRoutesDouble(undeclared: {'*'});
      AppRoutes.I = routes;

      await pumpSplash(tester, settings: _DeadSettingsRepository());

      // The last resort: a friendly line and a way to try again, on a page
      // the host cannot fail to provide.
      expect(find.byType(TextButton), findsOneWidget);
      expect(eventOfType('splash_fallback_route_failed'), isNotNull);

      expectNoDiagnosticsOnScreen(tester);
    });
  });
}
