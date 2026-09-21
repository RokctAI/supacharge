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

// The one host shape onboarding_sdk's theme-mode tests need, mirroring
// core's base/dart/test/theme_flip_host.dart — that file lives in base_sdk's
// test/ directory, which no other package can import, so its shape is
// reproduced here rather than duplicated feature by feature in every test.
//
// The shape that matters: the theme mode flips app-wide, and the subject is
// CAPTURED once and handed back byte-for-byte identical on every host
// rebuild, so Element.updateChild short-circuits and the flip provably
// reaches NOTHING below the capture through a parent rebuild. That is how
// onboarding is mounted in the product: the composer's embedded-widget slot
// hands auth_sdk's LoginPage `const OnboardingIntroRouteView()`, the login
// page paints the one captured `_slots.introPage!` instance it was given,
// and the installed route shell builds IntroPage from a `late final`
// IntroDeps so the run is not reset per frame. Only a dependency of the
// subject's own on the inherited theme restyles it here, which is exactly
// the property under test.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';

/// Mounts [child] under a flippable Material theme, inside the ProviderScope
/// and ScreenUtilInit a composed app's `main.dart` gives the tree. Flip with
/// [ThemeFlipHostState.flip] through the [GlobalKey] the test holds.
class ThemeFlipHost extends StatefulWidget {
  const ThemeFlipHost({
    super.key,
    required this.child,
    this.designSize = const Size(390, 844),
  });

  /// Captured once by the state below, so the flip cannot reach the subject
  /// through a parent rebuild.
  final Widget child;

  final Size designSize;

  @override
  State<ThemeFlipHost> createState() => ThemeFlipHostState();
}

class ThemeFlipHostState extends State<ThemeFlipHost> {
  bool dark = true;

  /// The identity pin: one instance, built once, handed back unchanged on
  /// every rebuild of this element.
  late final Widget _subject = widget.child;

  /// Mirrors AppNotifier.changeTheme: AppStyle's statics are synced and the
  /// Material themeMode flips, in that order.
  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: ScreenUtilInit(
        designSize: widget.designSize,
        builder: (context, _) => MaterialApp(
          theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
          darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: _subject,
        ),
      ),
    );
  }
}

/// Pumps [child] dark, lets [settle] drive it to the step under test, reads
/// [read], flips to light WITHOUT remounting, and asserts the reading moved
/// to what [expected] wants for the new mode.
Future<void> expectRestylesOnFlip(
  WidgetTester tester, {
  required Widget child,
  required Object? Function(WidgetTester tester) read,
  required Object? Function(Brightness brightness) expected,
  Future<void> Function(WidgetTester tester)? settle,
  Size designSize = const Size(390, 844),
  String? reason,
}) async {
  AppStyle.setBrightness(Brightness.dark);

  final GlobalKey<ThemeFlipHostState> host = GlobalKey<ThemeFlipHostState>();
  await tester.pumpWidget(ThemeFlipHost(
    key: host,
    designSize: designSize,
    child: child,
  ));
  await tester.pumpAndSettle();
  if (settle != null) {
    await settle(tester);
    await tester.pumpAndSettle();
  }

  final Object? inDark = expected(Brightness.dark);
  final Object? inLight = expected(Brightness.light);
  expect(inDark, isNot(inLight),
      reason: 'the two modes must want different values for this to test '
          'anything');

  expect(read(tester), inDark, reason: 'dark mode, before the flip');

  // The theme toggle lives on a surface the user reaches without leaving
  // first-run setup, so the flip happens with the step MOUNTED. Only a pump
  // — no remount — follows.
  host.currentState!.flip();
  await tester.pumpAndSettle();

  expect(read(tester), inLight,
      reason: reason ?? "the step kept the previous mode's styling");
}

/// Sizes the test window to a phone (frame 46h). The widget-test default of
/// 800x600 classes as a medium window and would draw the tablet layout.
void phoneWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Sizes the test window to a tablet (frame 46d), where the full rail moves
/// into the start side.
void tabletWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Every [Container] under [of] that carries a [BoxDecoration] — i.e. the
/// ones the subject itself decorated. Plain `Container(color: ...)` wrappers
/// leave `decoration` null and are skipped.
Finder decoratedUnder(Finder of) => find.descendant(
      of: of,
      matching: find.byWidgetPredicate(
          (Widget w) => w is Container && w.decoration is BoxDecoration),
    );

/// The nearest decorated [Container] wrapping [of] — the card a given piece
/// of copy sits in.
Finder decoratedAround(Finder of) => find.ancestor(
      of: of,
      matching: find.byWidgetPredicate(
          (Widget w) => w is Container && w.decoration is BoxDecoration),
    );

/// The fill a [Container]-shaped subject painted.
Color? containerFill(WidgetTester tester, Finder finder) {
  final BoxDecoration? decoration =
      tester.widget<Container>(finder).decoration as BoxDecoration?;
  return decoration?.color;
}

/// The border colour a [Container]-shaped subject painted.
Color? containerStroke(WidgetTester tester, Finder finder) {
  final BoxDecoration? decoration =
      tester.widget<Container>(finder).decoration as BoxDecoration?;
  final BoxBorder? border = decoration?.border;
  return border is Border ? border.top.color : null;
}

/// The colour a [Text] names for itself — null where the widget left its ink
/// to whatever ambient default it happened to sit under, which is itself a
/// form of the defect.
Color? textInk(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.color;

/// The colour an [Icon] names for itself.
Color? iconInk(WidgetTester tester, Finder finder) =>
    tester.widget<Icon>(finder).color;

/// One resolved colour out of a [ButtonStyle] property.
Color? buttonColor(WidgetStateProperty<Color?>? property) =>
    property?.resolve(const <WidgetState>{});

/// The stroke a [ButtonStyle]'s side names.
Color? buttonSide(ButtonStyle? style) =>
    style?.side?.resolve(const <WidgetState>{})?.color;

/// A bundle that answers every asset with a 1x1 transparent PNG, so a widget
/// that paints host artwork (which no SDK package ships) can still be mounted
/// here. Only the colours around the image are under test.
class OnePixelAssetBundle extends CachingAssetBundle {
  static final Uint8List _png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQAB'
      'DQottAAAAABJRU5ErkJggg==');

  /// An empty asset manifest: AssetImage asks the bundle for this before the
  /// image itself, to look for resolution variants. There are none, so the
  /// plain key is used and [_png] answers it.
  static final ByteData _emptyManifest =
      const StandardMessageCodec().encodeMessage(<String, Object>{})!;

  static const String _manifestKey = 'AssetManifest.bin';

  @override
  Future<ByteData> load(String key) async =>
      key == _manifestKey ? _emptyManifest : ByteData.sublistView(_png);

  @override
  Future<String> loadString(String key, {bool cache = true}) async => '';
}
