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

// The post-registration steps pipeline restyles itself the moment the theme
// mode changes, with its page still mounted (Ray, 2026-09-19: "glance doesnt
// change test immediately untill you come back if you switched theme mode" —
// the same defect, found here by the fleet audit that followed).
//
// The page resolved nothing from its BuildContext: its surface and its
// progress label came from AppStyle's app-wide statics, which are not an
// inherited widget, so a theme-mode change scheduled no rebuild of this
// element and the previous mode's colours stayed on screen until the page
// was built again from scratch. RegistrationStepsPage itself reads nothing
// from the context either, so the flip provably cannot reach the state
// through a parent rebuild.

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auth_sdk/src/common/presentation/pages/auth/registration/registration_step.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/registration/registration_steps_page.dart';

/// Stands in for the app's post-registration landing, which would otherwise
/// need the router this package's tests do not mount. A top-level function so
/// the deps below stay `const`.
void _noLanding(BuildContext context) {}

/// Two visible steps, so the pipeline renders its progress label and does not
/// fall straight through to the landing.
const RegistrationStepsDeps _twoSteps = RegistrationStepsDeps(
  steps: <RegistrationStep>[
    RegistrationStep(
      skippable: false,
      content: Text('step-one', textDirection: TextDirection.ltr),
    ),
    RegistrationStep(
      skippable: false,
      content: Text('step-two', textDirection: TextDirection.ltr),
    ),
  ],
  onComplete: _noLanding,
);

/// No contributions at all: the page shows its one-frame spinner surface.
const RegistrationStepsDeps _noSteps =
    RegistrationStepsDeps(onComplete: _noLanding);

/// The host shape that matters: the theme mode flips app-wide, and the page
/// sits in a subtree the flip does not rebuild on its own account (a `const`
/// child is handed back identical, so its element is not rebuilt). Only a
/// dependency of the page's own on the inherited theme restyles it here.
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
    // The page sizes its type through ScreenUtil (base_sdk's AppStyle), so
    // the tree needs the same init a composed app's main.dart gives it.
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const _StepsRegion(),
      ),
    );
  }
}

class _StepsRegion extends StatelessWidget {
  const _StepsRegion();

  @override
  Widget build(BuildContext context) =>
      const RegistrationStepsPage(deps: _twoSteps);
}

/// Same host, holding the empty pipeline instead.
class _EmptyThemedHost extends StatefulWidget {
  const _EmptyThemedHost({super.key});

  @override
  State<_EmptyThemedHost> createState() => _EmptyThemedHostState();
}

class _EmptyThemedHostState extends State<_EmptyThemedHost> {
  bool dark = true;

  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const _EmptyRegion(),
      ),
    );
  }
}

class _EmptyRegion extends StatelessWidget {
  const _EmptyRegion();

  @override
  Widget build(BuildContext context) =>
      const RegistrationStepsPage(deps: _noSteps);
}

void main() {
  final bool wasDark = AppStyle.isDark;
  tearDown(() {
    AppStyle.isDark = wasDark;
    RegistrationFlow.lastRegisteredUser = null;
  });

  Color? surfaceOf(WidgetTester tester) =>
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;

  Color? progressInkOf(WidgetTester tester) =>
      tester.widget<Text>(find.text('1/2')).style?.color;

  testWidgets(
      'a theme-mode change restyles the registration steps page with the page '
      'still mounted', (WidgetTester tester) async {
    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester.pumpWidget(_ThemedHost(key: host, startDark: true));
    await tester.pumpAndSettle();

    final Color darkSurface = AppStyle.surfaceFor(Brightness.dark);
    final Color lightSurface = AppStyle.surfaceFor(Brightness.light);
    final Color darkSecondary = AppStyle.secondaryInkFor(Brightness.dark);
    final Color lightSecondary = AppStyle.secondaryInkFor(Brightness.light);
    expect(darkSurface, isNot(lightSurface));
    expect(darkSecondary, isNot(lightSecondary));

    expect(find.text('step-one'), findsOneWidget);
    expect(surfaceOf(tester), darkSurface);
    expect(progressInkOf(tester), darkSecondary);

    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(surfaceOf(tester), lightSurface,
        reason: "the pipeline surface kept the previous mode's colour");
    expect(progressInkOf(tester), lightSecondary,
        reason: "the progress label kept the previous mode's ink");
  });

  testWidgets('the empty-pipeline surface follows the mode too',
      (WidgetTester tester) async {
    // No visible steps: the page draws the spinner surface while the
    // post-frame landing callback lands. Resolved in the same build, so it
    // must come from the same inherited-theme read. pump(), not
    // pumpAndSettle() — the progress indicator never stops animating — and
    // pumped past MaterialApp's 200ms theme animation, which is what carries
    // the new brightness down to the page.
    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_EmptyThemedHostState> host =
        GlobalKey<_EmptyThemedHostState>();
    await tester.pumpWidget(_EmptyThemedHost(key: host));
    await tester.pump();

    expect(surfaceOf(tester), AppStyle.surfaceFor(Brightness.dark));

    host.currentState!.flip();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(surfaceOf(tester), AppStyle.surfaceFor(Brightness.light),
        reason: "the empty pipeline kept the previous mode's surface");
  });
}
