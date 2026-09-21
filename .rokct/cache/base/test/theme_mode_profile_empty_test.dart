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


// The generic profile host's EMPTY placeholder, restyling itself the moment
// the theme mode changes (Ray, 2026-09-19: "glance doesnt change test
// immediately untill you come back if you switched theme mode").
//
// This one is the const-child boundary at its starkest. The host page
// watches the persisted dark-mode flag, so it DOES rebuild when the theme
// toggle on it is used - but it mounts the placeholder as `const`, and a
// parent handing back the identical widget instance does not rebuild that
// child's element. The placeholder's own ink came from AppStyle's app-wide
// isDark static, which is not an inherited widget either, so nothing
// restyled it at all: an empty profile sat in the previous mode's grey
// until the page was built again from scratch.
//
// Flipping the MaterialApp's themeMode here - and NOT the persisted flag -
// is what isolates that: the host's ref.watch does not fire, so only the
// placeholder's own theme dependency can restyle it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/base_profile_footer.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

/// The host, with its theme mode flippable from the test. Mirrors
/// AppNotifier.changeTheme's order: AppStyle's statics, then the Material
/// themeMode.
class _ThemedProfileHost extends StatefulWidget {
  const _ThemedProfileHost({super.key});

  @override
  State<_ThemedProfileHost> createState() => _ThemedProfileHostState();
}

class _ThemedProfileHostState extends State<_ThemedProfileHost> {
  bool dark = true;

  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 1400),
      builder: (context, _) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const GenericProfilePage(),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() async {
    // The anonymous composition: no account facades at all, so the host
    // never fetches. And the default footer slot is hidden the documented
    // way - a section registered under its id whose visibility gate
    // resolves false - which is what leaves the page with no sections and
    // so renders the placeholder.
    await getIt.reset();
    ProfileSectionRegistry.I.reset();
    GenericProfilePage.resetAnonymousModeReport();
    ProfileSectionRegistry.I.register(ProfileSection(
      id: BaseProfileFooter.sectionId,
      order: BaseProfileFooter.sectionOrder,
      builder: (_) => const SizedBox.shrink(),
      visible: () async => false,
    ));
  });

  tearDown(() async {
    ProfileSectionRegistry.I.reset();
    GenericProfilePage.resetAnonymousModeReport();
    await getIt.reset();
    AppStyle.isDark = wasDark;
  });

  testWidgets('the empty-profile placeholder restyles itself on a mode flip',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_ThemedProfileHostState> host =
        GlobalKey<_ThemedProfileHostState>();
    await tester.pumpWidget(
      ProviderScope(child: _ThemedProfileHost(key: host)),
    );
    await tester.pumpAndSettle();

    final Finder glyph = find.byIcon(Remix.list_settings_line);
    expect(glyph, findsOneWidget,
        reason: 'the page did not land on its empty placeholder');

    Color? glyphInk() => tester.widget<Icon>(glyph).color;
    Color? labelInk() => tester
        .widget<Text>(find.text(AppHelpers.getTranslation(TrKeys.noData)))
        .style
        ?.color;

    expect(glyphInk(), AppStyle.secondaryInkFor(Brightness.dark));
    expect(labelInk(), AppStyle.secondaryInkFor(Brightness.dark));

    // The theme toggle lives on this very page, so the flip happens with
    // the placeholder MOUNTED. No remount follows - only a pump.
    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(glyphInk(), AppStyle.secondaryInkFor(Brightness.light),
        reason: "the empty placeholder's glyph kept the previous mode's ink");
    expect(labelInk(), AppStyle.secondaryInkFor(Brightness.light),
        reason: "the empty placeholder's label kept the previous mode's ink");
  });
}
