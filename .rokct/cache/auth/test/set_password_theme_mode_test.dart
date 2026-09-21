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

// The set-password sheet restyles itself the moment the theme mode changes,
// with the sheet still mounted (Ray, 2026-09-19: "glance doesnt change test
// immediately untill you come back if you switched theme mode" — the same
// defect, found here by the fleet audit that followed).
//
// The sheet resolved nothing from its BuildContext that a theme-mode flip
// touches: its background came from AppStyle.surfaceDark, an app-wide static
// and not an inherited widget, and its only other context read is
// MediaQuery's view insets, which the mode does not change. So the flip
// scheduled no rebuild of this element and the previous mode's background
// stayed on screen for as long as the sheet was open. The
// resetPasswordProvider it watches is a feature notifier that a theme-mode
// change never notifies, so it is no rebuild trigger either.
//
// The host below mounts the sheet behind a `const` child boundary, so a
// parent rebuild provably cannot deliver the flip: the boundary hands back
// the identical widget instance and its element is never rebuilt. Only a
// dependency of the sheet's own on the inherited theme restyles it here.

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/auth.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auth_sdk/src/common/presentation/pages/auth/reset/set_password_page.dart';

/// The sheet's notifier is built from the two repository facades the host
/// registers at boot. Painting the sheet must not reach either of them, so
/// these stand-ins answer every call by failing the test loudly.
class _UnusedAuthRepository implements AuthRepositoryFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'painting the set-password sheet called AuthRepositoryFacade.'
      '${invocation.memberName}');
}

class _UnusedUserRepository implements UserRepositoryFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'painting the set-password sheet called UserRepositoryFacade.'
      '${invocation.memberName}');
}

/// The host shape that matters: the theme mode flips app-wide, and the sheet
/// sits in a subtree the flip does not rebuild on its own account (a `const`
/// child is handed back identical, so its element is not rebuilt).
class _ThemedHost extends StatefulWidget {
  const _ThemedHost({super.key, required this.startDark});

  final bool startDark;

  @override
  State<_ThemedHost> createState() => _ThemedHostState();
}

class _ThemedHostState extends State<_ThemedHost> {
  late bool dark = widget.startDark;

  /// Mirrors AppNotifier.changeTheme: AppStyle's statics are synced and the
  /// Material themeMode flips, in that order.
  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    // The sheet sizes its type and radii through ScreenUtil (base_sdk's
    // AppStyle), so the tree needs the same init a composed app's main.dart
    // gives it.
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: _SheetRegion()),
      ),
    );
  }
}

/// The `const` boundary. Its own build reads nothing from the context, and
/// it returns a `const` child, so nothing above the sheet can rebuild it.
class _SheetRegion extends StatelessWidget {
  const _SheetRegion();

  @override
  Widget build(BuildContext context) => const SetPasswordPage();
}

void main() {
  final bool wasDark = AppStyle.isDark;

  setUpAll(() {
    if (!getIt.isRegistered<AuthRepositoryFacade>()) {
      getIt.registerSingleton<AuthRepositoryFacade>(_UnusedAuthRepository());
    }
    if (!getIt.isRegistered<UserRepositoryFacade>()) {
      getIt.registerSingleton<UserRepositoryFacade>(_UnusedUserRepository());
    }
  });

  tearDown(() => AppStyle.isDark = wasDark);

  /// The sheet's own background: the first Container under the sheet's
  /// KeyboardDismisser, which is the one whose colour this build decides.
  Color? sheetSurfaceOf(WidgetTester tester) {
    final Finder surface = find
        .descendant(
          of: find.byType(KeyboardDismisser),
          matching: find.byType(Container),
        )
        .first;
    final Decoration? decoration = tester.widget<Container>(surface).decoration;
    return (decoration as BoxDecoration?)?.color;
  }

  testWidgets(
      'a theme-mode change restyles the set-password sheet with the sheet '
      'still mounted', (WidgetTester tester) async {
    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester
        .pumpWidget(ProviderScope(child: _ThemedHost(key: host, startDark: true)));
    await tester.pumpAndSettle();

    final Color darkSurface = AppStyle.surfaceFor(Brightness.dark);
    final Color lightSurface = AppStyle.surfaceFor(Brightness.light);
    expect(darkSurface, isNot(lightSurface));

    expect(find.byType(SetPasswordPage), findsOneWidget);
    expect(sheetSurfaceOf(tester), darkSurface);

    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(sheetSurfaceOf(tester), lightSurface,
        reason: "the set-password sheet kept the previous mode's surface");
  });

  testWidgets('and back again, light to dark, with no remount',
      (WidgetTester tester) async {
    AppStyle.setBrightness(Brightness.light);

    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester.pumpWidget(
        ProviderScope(child: _ThemedHost(key: host, startDark: false)));
    await tester.pumpAndSettle();

    expect(sheetSurfaceOf(tester), AppStyle.surfaceFor(Brightness.light));

    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(sheetSurfaceOf(tester), AppStyle.surfaceFor(Brightness.dark),
        reason: "the set-password sheet kept the previous mode's surface");
  });
}
