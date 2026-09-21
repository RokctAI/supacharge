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


// The OTHER profile toast. `profile_offline_toast_test.dart` covers the
// radio guard in `ProfileNotifier.fetchUser` and its
// `showNoConnectionSnackBar` ("No internet connection"), which fires WITHOUT
// attempting a fetch. This file covers what happens when that guard PASSES
// and the request then fails.
//
// Ray, 2026-09-19, correcting the wording he was shown: "not check your
// connection but check your network connection", and "im thinking it could
// be that the backend is unreachable rather than the phone being offline".
// Both details were right. The guard had already found a network, the fetch
// was attempted, the backend did not answer, and the top red toast told him
// to check the connection the guard had just verified.
//
// The repository below maps its caught exception exactly the way every
// repository in the fleet does - `AppHelpers.errorHandler(e)` into
// `ApiResult.failure(error:)` - so this test exercises the real funnel, not
// a hand-written string.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/handlers/network_exceptions.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/models/response/profile_response.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/storage_keys.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

/// A profile facade whose gateway call throws the way a dead backend makes
/// it throw, mapped through the fleet-standard catch block.
class _UnreachableUserRepository extends Fake implements UserRepositoryFacade {
  _UnreachableUserRepository(this.type);

  final DioExceptionType type;
  int profileCalls = 0;

  @override
  Future<ApiResult<ProfileResponse>> getProfileDetails() async {
    profileCalls++;
    final options = RequestOptions(
      path: kPlatformGatewayPath,
      data: {'cmd': 'api.user.get_profile'},
    );
    // No `response`: nothing ever answered.
    final e = DioException(requestOptions: options, type: type);
    return ApiResult<ProfileResponse>.failure(
      error: AppHelpers.errorHandler(e),
      statusCode: NetworkExceptions.getDioStatus(e),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  /// The radio says online, as it did on Ray's phone.
  void stubRadioOnline() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') return <String>['wifi'];
      return null;
    });
  }

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
    stubRadioOnline();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
    await getIt.reset();
  });

  Future<_UnreachableUserRepository> pumpProfile(
    WidgetTester tester,
    DioExceptionType type,
  ) async {
    final repository = _UnreachableUserRepository(type);
    getIt.registerSingleton<UserRepositoryFacade>(repository);
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 1400),
          builder: (context, _) => const MaterialApp(home: GenericProfilePage()),
        ),
      ),
    );
    // Post-frame fetch, async radio check, then the overlay animation.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));
    return repository;
  }

  group('the profile page when the guard passes and the backend does not '
      'answer', () {
    testWidgets('an attempted-and-refused fetch names the server, not the '
        "reader's connection", (tester) async {
      final repository =
          await pumpProfile(tester, DioExceptionType.connectionError);

      expect(
        repository.profileCalls,
        1,
        reason: 'the guard passed, so the fetch must have been attempted',
      );
      expect(
        find.text(AppHelpers.getTranslation(TrKeys.couldNotReachServer)),
        findsOneWidget,
        reason: 'an unreachable backend must say the server was unreachable',
      );
      // The regression Ray reported, verbatim wording and all.
      expect(
        find.text(
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        ),
        findsNothing,
        reason: 'the guard already found a network; do not blame the reader',
      );
      // And not the OTHER profile toast either: that one belongs to the
      // guard, which did not fire here.
      expect(find.text('No internet connection'), findsNothing);
    });

    testWidgets('a timeout says the server was too slow', (tester) async {
      await pumpProfile(tester, DioExceptionType.receiveTimeout);

      expect(
        find.text(AppHelpers.getTranslation(TrKeys.serverTookTooLong)),
        findsOneWidget,
      );
      expect(
        find.text(AppHelpers.getTranslation(TrKeys.couldNotReachServer)),
        findsNothing,
      );
    });
  });
}
