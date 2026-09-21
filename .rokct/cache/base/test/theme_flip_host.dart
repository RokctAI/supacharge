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


// The one host shape the shared-component theme-mode tests all need, shared
// so each of them states its subject and nothing else.
//
// The shape that matters (see glance_card_theme_mode_test and
// theme_mode_statics_test, which each carry their own copy of it): the
// theme mode flips app-wide, and the subject sits inside a `const` child,
// so the flip rebuilds everything above it and NOTHING below. A `const`
// child is handed back the identical widget instance, so its element is
// not rebuilt. Only a dependency of the subject's own on the inherited
// theme restyles it here - which is exactly the property under test, and
// exactly how these components are mounted in the product (none of them
// has a mount site inside base_sdk at all, so no host rebuild can be
// assumed).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';

/// Mounts [child] under a flippable Material theme. Flip with
/// [ThemeFlipHostState.flip] through the [GlobalKey] the test holds.
class ThemeFlipHost extends StatefulWidget {
  const ThemeFlipHost({super.key, required this.child, this.wrapInScaffold = true});

  /// Pass this `const` from the test, so the flip cannot reach the subject
  /// through a parent rebuild.
  final Widget child;

  /// A subject that brings its own [Scaffold] (a whole page) asks for none.
  final bool wrapInScaffold;

  @override
  State<ThemeFlipHost> createState() => ThemeFlipHostState();
}

class ThemeFlipHostState extends State<ThemeFlipHost> {
  bool dark = true;

  /// Mirrors AppNotifier.changeTheme: AppStyle's statics are synced and the
  /// Material themeMode flips, in that order.
  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(800, 600),
      builder: (context, _) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: widget.wrapInScaffold
            ? Scaffold(body: Center(child: widget.child))
            : widget.child,
      ),
    );
  }
}

/// Pumps [child] dark, reads [read], flips to light without remounting, and
/// returns the two readings. [child] must be a `const` (or otherwise
/// identical across the host's rebuild) widget.
Future<void> expectRestylesOnFlip(
  WidgetTester tester, {
  required Widget child,
  required Object? Function(WidgetTester tester) read,
  required Object? Function(Brightness brightness) expected,
  bool wrapInScaffold = true,
  String? reason,
}) async {
  AppStyle.setBrightness(Brightness.dark);

  final GlobalKey<ThemeFlipHostState> host = GlobalKey<ThemeFlipHostState>();
  await tester.pumpWidget(ThemeFlipHost(
    key: host,
    wrapInScaffold: wrapInScaffold,
    child: child,
  ));
  await tester.pumpAndSettle();

  final Object? inDark = expected(Brightness.dark);
  final Object? inLight = expected(Brightness.light);
  expect(inDark, isNot(inLight),
      reason: 'the two modes must want different values for this to test '
          'anything');

  expect(read(tester), inDark, reason: 'dark mode, before the flip');

  // The theme toggle lives on the profile page the user is already looking
  // at, so the flip happens with the subject MOUNTED. Only a pump - no
  // remount - follows.
  host.currentState!.flip();
  await tester.pumpAndSettle();

  expect(read(tester), inLight,
      reason: reason ?? "the widget kept the previous mode's styling");
}

/// The mirror of [expectRestylesOnFlip]: pumps [child] dark, reads [read],
/// flips WITHOUT remounting and asserts the reading did NOT move. For a
/// colour the CALLER named (a search field's `bgColor`, a keypad's OK fill,
/// a wallet balance's green) - fixing the mode-blind roles must never start
/// overwriting a caller's own choice.
Future<void> expectPinnedOnFlip(
  WidgetTester tester, {
  required Widget child,
  required Object? Function(WidgetTester tester) read,
  bool wrapInScaffold = true,
  String? reason,
}) async {
  AppStyle.setBrightness(Brightness.dark);

  final GlobalKey<ThemeFlipHostState> host = GlobalKey<ThemeFlipHostState>();
  await tester.pumpWidget(ThemeFlipHost(
    key: host,
    wrapInScaffold: wrapInScaffold,
    child: child,
  ));
  await tester.pumpAndSettle();

  final Object? before = read(tester);
  expect(before, isNotNull, reason: 'nothing was read, so nothing is pinned');

  host.currentState!.flip();
  await tester.pumpAndSettle();

  expect(read(tester), before,
      reason: reason ?? "a caller's own colour moved with the theme mode");
}

/// The first [Container] inside [subject] that carries a [BoxDecoration] -
/// i.e. the one the subject itself decorated. Plain `Container(color: ...)`
/// wrappers (ButtonEffectAnimation puts a transparent one around its child)
/// leave `decoration` null and are skipped.
Finder decoratedIn(Type subject) => find.descendant(
      of: find.byType(subject),
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

/// The colour a [Text] names for itself - null where the widget left its ink
/// to whatever ambient default it happened to sit under, which is itself a
/// form of the defect.
Color? textInk(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

/// The colour an [Icon] names for itself.
Color? iconInk(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;
