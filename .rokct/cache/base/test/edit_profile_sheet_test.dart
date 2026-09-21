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

// The shared edit-own-details sheet (approved frame 4d, chips 725-734):
// promoted verbatim from marketplace_sdk's customer EditProfileScreen so
// every GenericProfilePage host can wire the user-card pencil (chip 109)
// to it. Pins the shipped field set rendering from profileProvider's
// user, and Save driving base_sdk's own EditProfileNotifier end to end
// into UserRepositoryFacade.editProfile (the self-scoped
// update_user_profile plumbing) — recording fake repository, stubbed
// connectivity radio.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/models.dart';
import 'package:base_sdk/src/models/request/edit_profile.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underline_drop_down.dart';
import 'package:base_sdk/src/presentation/pages/profile/edit_profile_sheet.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:base_sdk/src/application/profile/profile_provider.dart';

/// Records the [editProfile] call the Save button must produce; every
/// other member is unused by this sheet's flow.
class _RecordingUserRepository extends Fake implements UserRepositoryFacade {
  final List<EditProfile?> editCalls = [];

  @override
  Future<ApiResult<ProfileResponse>> editProfile(
      {required EditProfile? user}) async {
    editCalls.add(user);
    return ApiResult.success(
      data: ProfileResponse(
        data: ProfileData(
          firstname: user?.firstname,
          lastname: user?.lastname,
          email: user?.email,
          phone: user?.phone,
          birthday: user?.birthday,
          gender: user?.gender,
        ),
      ),
    );
  }
}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  late _RecordingUserRepository userRepo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    userRepo = _RecordingUserRepository();
    getIt.registerSingleton<UserRepositoryFacade>(userRepo);
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt
        .registerSingleton<GalleryRepositoryFacade>(_FakeGalleryRepository());
  });

  setUp(() {
    userRepo.editCalls.clear();
    // The notifier's Save path radio-checks connectivity first; report
    // wifi so it proceeds to the repository (same stub as
    // app_connectivity_test.dart).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') return ['wifi'];
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
  });

  ProfileData seedUser() => ProfileData(
        firstname: 'Renda',
        lastname: 'Sinyage',
        email: 'seller@example.com',
        phone: '+27810000000',
        birthday: '1990-04-12',
        gender: 'male',
        img: '',
      );

  /// Pumps a host page, seeds [profileProvider]'s user, then opens the
  /// sheet on a PUSHED route (the sheet's success path pops itself —
  /// exactly how the bottom-sheet presentation hosts it).
  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 1400),
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: EditProfileScreen(controller: controller),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.text('open'));
    ProviderScope.containerOf(context, listen: false)
        .read(profileProvider.notifier)
        .setUser(seedUser());
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String label(String key) => AppHelpers.getTranslation(key).toUpperCase();

  testWidgets('renders the shipped field set from the profile user',
      (tester) async {
    await openSheet(tester);

    // Title + the shipped labels, exactly the promoted field list (the
    // title renders through TitleAndIcon's RichText).
    expect(
        find.text(AppHelpers.getTranslation(TrKeys.profileSettings),
            findRichText: true),
        findsOneWidget);
    expect(find.text(label(TrKeys.email)), findsOneWidget);
    expect(find.text(label(TrKeys.firstname)), findsOneWidget);
    expect(find.text(label(TrKeys.surname)), findsOneWidget);
    expect(find.text(label(TrKeys.phoneNumber)), findsOneWidget);
    expect(find.text(label(TrKeys.dateOfBirth)), findsOneWidget);
    // The gender dropdown owns its own label rendering (it re-translates
    // and stars the label), so pin the widget itself.
    expect(find.byType(UnderlineDropDown), findsOneWidget);
    expect(find.text(AppHelpers.getTranslation(TrKeys.save)), findsOneWidget);

    // Seeded values render into the fields.
    expect(find.text('Renda'), findsOneWidget);
    expect(find.text('Sinyage'), findsOneWidget);
    expect(find.text('seller@example.com'), findsOneWidget);
    expect(find.text('+27810000000'), findsOneWidget);
    expect(find.text('1990-04-12'), findsOneWidget);
  });

  testWidgets('Save validates and drives the notifier into the repository',
      (tester) async {
    await openSheet(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Renda'), 'Umukhulu');
    await tester.ensureVisible(
        find.text(AppHelpers.getTranslation(TrKeys.save)));
    await tester.tap(find.text(AppHelpers.getTranslation(TrKeys.save)));
    await tester.pumpAndSettle();

    // One editProfile call, carrying the edited first name and the
    // untouched seeded fields (the notifier back-fills them from the
    // profile user).
    expect(userRepo.editCalls, hasLength(1));
    final sent = userRepo.editCalls.single;
    expect(sent?.firstname, 'Umukhulu');
    expect(sent?.lastname, 'Sinyage');
    expect(sent?.email, 'seller@example.com');
    expect(sent?.phone, '+27810000000');
    expect(sent?.gender, 'male');

    // Success pops the sheet route back to the host page.
    expect(find.text('open'), findsOneWidget);
  });
}
