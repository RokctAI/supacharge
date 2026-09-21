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


// Ray, 2026-09-19, on the launcher build that first carried the account
// menu's Profile item: "going  to profile i get offline toast" - on a phone
// that was online.
//
// The launcher's Profile item pushes base_sdk's own `/generic-profile`
// route, and the page's first act is `ProfileNotifier.fetchUser`, which
// gates the fetch on `AppConnectivity.connectivity()` and, on false, shows
// `AppHelpers.showNoConnectionSnackBar` ("No internet connection") without
// attempting anything. That gate admitted only mobile/ethernet/wifi, while
// connectivity_plus names the active network `vpn` on a phone with a VPN up
// and `other` for any internet-capable transport it has no name for - so a
// device with a perfectly good network was told it had none.
//
// Two assertions, one bug: the radio definition itself, and the profile
// page that shows the toast when it says no.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/models/response/profile_response.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/app_connectivity.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/storage_keys.dart';

/// The one account facade the profile host needs, recording whether the
/// page ever got as far as asking for the profile.
class _RecordingUserRepository extends Fake implements UserRepositoryFacade {
  int profileCalls = 0;

  @override
  Future<ApiResult<ProfileResponse>> getProfileDetails() async {
    profileCalls++;
    return ApiResult<ProfileResponse>.success(
      // A real person: the page persists whatever comes back, and a null
      // payload would leave an unparseable cached user behind.
      data: ProfileResponse(
        data: ProfileData(id: '1', firstname: 'Ray', email: 'ray@example.com'),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  /// Stubs the connectivity_plus radio check ('check') to report [results]
  /// (the plugin's own wire strings, e.g. ['vpn'] or ['none']).
  void stubRadio(List<String> results) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') return results;
      return null;
    });
  }

  // A signed-in session is the fixture: the launcher's account control only
  // offers Profile once there is one, and fetchUser does nothing without a
  // stored token. Seeded through the prefs mock rather than
  // LocalStorage.setToken, which also reaches for flutter_secure_storage.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{StorageKeys.keyToken: 'a-real-session-token'},
    );
    await LocalStorage.init();
  });

  setUp(() async {
    await getIt.reset();
    ProfileSectionRegistry.I.reset();
    GenericProfilePage.resetAnonymousModeReport();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
    await getIt.reset();
  });

  group('the online definition', () {
    test('every answer but none is online', () {
      expect(AppConnectivity.isOnline([ConnectivityResult.wifi]), isTrue);
      expect(AppConnectivity.isOnline([ConnectivityResult.mobile]), isTrue);
      expect(AppConnectivity.isOnline([ConnectivityResult.ethernet]), isTrue);
      // The three the old whitelist called offline.
      expect(AppConnectivity.isOnline([ConnectivityResult.vpn]), isTrue);
      expect(AppConnectivity.isOnline([ConnectivityResult.other]), isTrue);
      expect(AppConnectivity.isOnline([ConnectivityResult.bluetooth]), isTrue);
      // A VPN whose underlying transport the plugin also reports.
      expect(
        AppConnectivity.isOnline(
          [ConnectivityResult.vpn, ConnectivityResult.wifi],
        ),
        isTrue,
      );
    });

    test('none, and no answer at all, are offline', () {
      expect(AppConnectivity.isOnline([ConnectivityResult.none]), isFalse);
      expect(AppConnectivity.isOnline(const []), isFalse);
    });

    test('connectivity() reads the radio through that definition', () async {
      stubRadio(['vpn']);
      expect(await AppConnectivity.connectivity(), isTrue);
      stubRadio(['other']);
      expect(await AppConnectivity.connectivity(), isTrue);
      stubRadio(['none']);
      expect(await AppConnectivity.connectivity(), isFalse);
    });
  });

  group('the generic profile page on a signed-in phone', () {
    Future<_RecordingUserRepository> pumpProfile(WidgetTester tester) async {
      final repository = _RecordingUserRepository();
      getIt.registerSingleton<UserRepositoryFacade>(repository);
      expect(LocalStorage.getToken(), isNotEmpty);
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: const Size(390, 1400),
            builder: (context, _) =>
                const MaterialApp(home: GenericProfilePage()),
          ),
        ),
      );
      // The fetch is a post-frame callback and the radio check is async:
      // two frames plus a beat is what it takes for either the fetch or
      // the snackbar to land.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return repository;
    }

    testWidgets('a VPN is not "No internet connection"', (tester) async {
      stubRadio(['vpn']);

      final repository = await pumpProfile(tester);

      expect(
        find.text('No internet connection'),
        findsNothing,
        reason: 'the offline toast fired on a phone that had a network',
      );
      expect(
        repository.profileCalls,
        1,
        reason: 'the profile was never fetched on a device that was online',
      );
    });

    testWidgets('a radio that reports none still says so', (tester) async {
      stubRadio(['none']);

      final repository = await pumpProfile(tester);

      expect(find.text('No internet connection'), findsOneWidget);
      expect(repository.profileCalls, 0);
    });
  });
}
