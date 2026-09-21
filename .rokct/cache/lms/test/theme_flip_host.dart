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


// The one host shape the theme-mode tests in this package all need, mirroring
// base_sdk's own test/theme_flip_host.dart (that file lives in core's test
// tree, which is not publishable, so the shape is carried here rather than
// imported).
//
// The shape that matters: the theme mode flips app-wide, and the subject sits
// inside a `const` child, so the flip rebuilds everything ABOVE it and nothing
// below. A `const` child is handed back the identical widget instance, so its
// element is not rebuilt. Only a dependency of the subject's own on the
// inherited theme restyles it here - which is exactly how these pages are
// mounted in the product: an auto_route page holds the instance the route
// builder made, and a dialog or bottom sheet holds the one its builder made,
// so no ancestor rebuild reaches them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';

/// Mounts [child] under a flippable Material theme. Flip with
/// [ThemeFlipHostState.flip] through the [GlobalKey] the test holds.
class ThemeFlipHost extends StatefulWidget {
  const ThemeFlipHost(
      {super.key, required this.child, this.wrapInScaffold = false});

  /// Pass this `const` from the test, so the flip cannot reach the subject
  /// through a parent rebuild.
  final Widget child;

  /// A page subject brings its own [Scaffold] and asks for none; a bare
  /// widget that uses ink needs one above it.
  final bool wrapInScaffold;

  @override
  State<ThemeFlipHost> createState() => ThemeFlipHostState();
}

class ThemeFlipHostState extends State<ThemeFlipHost> {
  bool dark = true;

  /// Mirrors what the profile theme toggle does: AppStyle's statics are
  /// synced and the Material themeMode flips, in that order.
  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: widget.wrapInScaffold
          ? Scaffold(body: Center(child: widget.child))
          : widget.child,
    );
  }
}

/// Pumps [child] dark, settles, reads [read], flips to light WITHOUT
/// remounting and returns the reading again, asserting it moved to the value
/// [expected] names for each mode.
///
/// [child] must be `const` (or otherwise the identical instance across the
/// host's rebuild), so the only thing that can restyle the subject is a
/// dependency of its own on the inherited theme.
Future<void> expectRestylesOnFlip(
  WidgetTester tester, {
  required Widget child,
  required Object? Function(WidgetTester tester) read,
  required Object? Function(Brightness brightness) expected,
  Future<void> Function(WidgetTester tester)? afterPump,
  bool wrapInScaffold = false,
  String? reason,
}) async {
  AppStyle.setBrightness(Brightness.dark);

  final GlobalKey<ThemeFlipHostState> host = GlobalKey<ThemeFlipHostState>();
  await tester.pumpWidget(ThemeFlipHost(
      key: host, wrapInScaffold: wrapInScaffold, child: child));
  await tester.pumpAndSettle();

  // Subjects that are only reachable through an interaction - a dialog the
  // page opens - are opened here, BEFORE the flip, so the flip still lands
  // on a mounted subject.
  if (afterPump != null) {
    await afterPump(tester);
    await tester.pumpAndSettle();
  }

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

  // Leave the statics where every other suite in this package expects them.
  AppStyle.setBrightness(Brightness.dark);
}

/// The [Scaffold] a page subject painted, found inside [subject].
Color? scaffoldFill(WidgetTester tester, Type subject) => tester
    .widget<Scaffold>(
        find.descendant(of: find.byType(subject), matching: find.byType(Scaffold)))
    .backgroundColor;

/// The fill of the [AlertDialog] currently on screen.
Color? dialogFill(WidgetTester tester) =>
    tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor;

/// The colour a [Text] names for itself - null where the widget left its ink
/// to whatever ambient default it happened to sit under, which is itself a
/// form of the defect.
Color? textInk(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

/// The colour a [Text] found by prefix names for itself.
Color? textInkContaining(WidgetTester tester, String part) =>
    tester.widget<Text>(find.textContaining(part)).style?.color;

/// The colour an [Icon] names for itself.
Color? iconInk(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;
