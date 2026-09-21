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


// The shared glance shell restyles itself the moment the theme mode changes,
// with its page still mounted (Ray, 2026-09-19: "glance doesnt change test
// immediately untill you come back if you switched theme mode").
//
// The shell used to resolve nothing from the BuildContext: its colours came
// from AppStyle's app-wide statics and its rows' ink from whatever ambient
// DefaultTextStyle a host happened to provide. Neither registers a
// dependency on the inherited theme, so a mode change scheduled no rebuild
// of the card and it kept the old mode's ink until the page was built again
// from scratch — leaving the launcher.

import 'package:base_sdk/base_sdk.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The host shape that matters: the theme mode flips app-wide, and the card
/// sits in a subtree the flip does not rebuild on its own account (a `const`
/// child is handed back identical, so its element is not rebuilt). Only a
/// dependency of the card's own on the inherited theme restyles it here.
class _ThemedHost extends StatefulWidget {
  const _ThemedHost({super.key});

  @override
  State<_ThemedHost> createState() => _ThemedHostState();
}

class _ThemedHostState extends State<_ThemedHost> {
  bool dark = true;

  /// Mirrors AppNotifier.changeTheme: AppStyle's statics are synced and the
  /// Material themeMode flips, in that order.
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
      home: const Scaffold(body: _GlanceRegion()),
    );
  }
}

class _GlanceRegion extends StatelessWidget {
  const _GlanceRegion();

  @override
  Widget build(BuildContext context) {
    return const GlanceCard(
      title: 'Glance',
      items: <GlanceCardItem>[
        GlanceCardItem(icon: Icons.notifications_none, text: 'One thing'),
      ],
    );
  }
}

void main() {
  final bool wasDark = AppStyle.isDark;
  tearDown(() => AppStyle.isDark = wasDark);

  /// The colour the row's OWN style names — null where the shell left the
  /// ink to whatever it happened to inherit.
  Color? namedInkOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  Color? inkOf(WidgetTester tester, String text) {
    final Element element = tester.element(find.text(text));
    final Text widget = element.widget as Text;
    // What actually paints: the row's own style over the ambient default.
    return DefaultTextStyle.of(element).style.merge(widget.style).color;
  }

  testWidgets(
      'a theme-mode change restyles the glance with its page still mounted',
      (WidgetTester tester) async {
    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester.pumpWidget(_ThemedHost(key: host));
    await tester.pumpAndSettle();

    final Color darkInk = AppStyle.inkFor(Brightness.dark);
    final Color lightInk = AppStyle.inkFor(Brightness.light);
    expect(darkInk, isNot(lightInk));

    expect(inkOf(tester, 'One thing'), darkInk);
    expect(inkOf(tester, 'Glance'), darkInk);

    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(inkOf(tester, 'One thing'), lightInk,
        reason: "the glance row kept the previous mode's ink");
    expect(inkOf(tester, 'Glance'), lightInk,
        reason: "the glance title kept the previous mode's ink");
    // And it is the card that names that ink, not an ambient default it
    // happens to sit under: that is what makes the mode change rebuild it.
    expect(namedInkOf(tester, 'One thing'), lightInk);
    expect(namedInkOf(tester, 'Glance'), lightInk);
  });

  testWidgets('a row that names its own colour keeps it across a mode change',
      (WidgetTester tester) async {
    // The active-order card's muted weather line passes a colour of its own;
    // the shell must not overwrite a caller's choice.
    AppStyle.setBrightness(Brightness.dark);
    final Color chosen = AppStyle.primary;

    Widget app(ThemeMode mode) => MaterialApp(
          theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
          darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
          themeMode: mode,
          home: Scaffold(
            body: GlanceCard(
              items: <GlanceCardItem>[
                GlanceCardItem(
                  icon: Icons.cloud_outlined,
                  text: 'Muted line',
                  textStyle: TextStyle(fontSize: 12, color: chosen),
                ),
              ],
            ),
          ),
        );

    await tester.pumpWidget(app(ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(inkOf(tester, 'Muted line'), chosen);

    AppStyle.setBrightness(Brightness.light);
    await tester.pumpWidget(app(ThemeMode.light));
    await tester.pumpAndSettle();
    expect(inkOf(tester, 'Muted line'), chosen);
  });
}
