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

// THE PRODUCTIVITY PLUS IS ON THE FLOATING NAV, on productivity's own page
// (Ray, 2026-09-20: "i think productivity plus should be in the floating nav
// when you in its page. floating nav already accept modes and buttons").
//
// The bar is base_sdk's own FloatingBottomNav in FloatingNavControlsMode and
// the plus is one FloatingNavAction in its leadingActions — the slot whose
// own doc names this case ("a tasks app's 'new task'"). Nothing new was
// drawn, and the page no longer carries a control of its own.
//
//   * the plus is ON the bar, and it is base_sdk's bar;
//   * a tap opens a new item of the list the page is drawing;
//   * a long press is still Ray's tasks/notes shortcut ("plus opens new but
//     i think hlding it should give me option like tasks notes"), carried
//     across on FloatingNavAction.onLongPress;
//   * no FloatingActionButton is drawn anywhere — one plus per screen;
//   * the label goes through translation, because base_sdk paints it as the
//     accessibility label and the long-press tooltip (adaptive_bar.md §8:
//     "no hardcoded user-facing strings, including accessibility labels"),
//     and unserved it still renders the sheet's own word for the list, so
//     the button and the sheet it opens cannot drift apart;
//   * the bar is STACKED OVER the page body, the slot base_sdk's host
//     contract and adaptive_bar.md §3 both ask for, never the Scaffold slot
//     that would dock it in a reserved strip;
//   * the installed /tasks page mounts THIS widget, and keeps no plus of its
//     own. The template imports the composed app's comms_sdk and cannot be
//     pumped here, so that half is pinned on its SOURCE — the same way
//     template_page_theme_mode_test.dart pins the pages' theme reads.

import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

// The package barrel is NOT imported. It pulls in this SDK's drift
// repositories, whose generated code a bare checkout does not carry, so
// every test file here reaches for the `src/` paths it actually needs -
// exactly as tasks_planes_test.dart and the other workspace tests do.
import 'package:productivity_sdk/src/common/presentation/notes/notes_list_controls.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/new_item_sheet.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/productivity_plus_nav.dart';

/// The real host composition: the bar STACKED OVER THE PAGE BODY, inside the
/// page's own SafeArea, which is what base_sdk asks its hosts for ("Hosts
/// place it in a Stack over the page body and hand it a FloatingNavMode",
/// floating_bottom_nav.dart) and the slot adaptive_bar.md §3 names - "a
/// full-size Stack slot (Positioned.fill, or the usual full-size Align)".
/// NOT Scaffold.bottomNavigationBar, which reserves the pill's height as body
/// inset and docks the bar in a strip of its own. ProviderScope because the
/// bar watches floatingProvider, ScreenUtilInit mirroring the app root.
Widget host(Widget bar) {
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (BuildContext context, _) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                // The page body the bar floats OVER, sized like a real one:
                // a zero-height body would leave the Stack no height to fill
                // and the fitted housing nothing to scale into.
                const SizedBox.expand(),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: bar,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get plus => find.descendant(
      of: find.byKey(ProductivityPlusNav.navKey),
      matching: find.byIcon(ProductivityPlusNav.plusIcon),
    );

void main() {
  group('ProductivityPlusNav - the plus rides the bar', () {
    testWidgets('the plus is on base_sdk\'s own floating nav, in controls mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(ProductivityPlusNav(
        list: WorkspaceList.tasks,
        onNew: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(ProductivityPlusNav.navKey), findsOneWidget);
      expect(find.byType(FloatingBottomNav), findsOneWidget);
      expect(plus, findsOneWidget);

      final FloatingBottomNav bar =
          tester.widget<FloatingBottomNav>(find.byType(FloatingBottomNav));
      expect(bar.mode, isA<FloatingNavControlsMode>());
      final FloatingNavControlsMode mode =
          bar.mode as FloatingNavControlsMode;
      // The plus LEADS, which is where the reference composer's "+" sits and
      // the slot the mode's own doc reserves for a primary action.
      expect(mode.leadingActions, hasLength(1));
      expect(mode.actions, isEmpty);
      // No composer and no panel: the bar stays the round pill of round
      // buttons.
      expect(mode.input, isNull);
      expect(mode.panel, isNull);
    });

    testWidgets('and NO FloatingActionButton is drawn - one plus per screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(ProductivityPlusNav(
        list: WorkspaceList.tasks,
        onNew: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('a tap opens a new item of the list on screen',
        (WidgetTester tester) async {
      int newItems = 0;
      await tester.pumpWidget(host(ProductivityPlusNav(
        list: WorkspaceList.tasks,
        onNew: () => newItems++,
      )));
      await tester.pumpAndSettle();

      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(newItems, 1);
    });

    testWidgets('a long press is the tasks/notes shortcut, not a second tap',
        (WidgetTester tester) async {
      int newItems = 0;
      int chooses = 0;
      await tester.pumpWidget(host(ProductivityPlusNav(
        list: WorkspaceList.notes,
        onNew: () => newItems++,
        onChooseList: () => chooses++,
      )));
      await tester.pumpAndSettle();

      await tester.longPress(plus);
      await tester.pumpAndSettle();
      expect(chooses, 1);
      expect(newItems, 0, reason: 'a long press must not also open a new item');
    });

    testWidgets('no shortcut offered leaves the plus with its tap alone',
        (WidgetTester tester) async {
      int newItems = 0;
      await tester.pumpWidget(host(ProductivityPlusNav(
        list: WorkspaceList.tasks,
        onNew: () => newItems++,
      )));
      await tester.pumpAndSettle();

      await tester.longPress(plus);
      await tester.pumpAndSettle();
      expect(newItems, 0);

      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(newItems, 1);
    });

    // adaptive_bar.md §8: "No hardcoded user-facing strings, including
    // accessibility labels", and §7 item 6: every string routed through
    // TrKeys + AppHelpers.getTranslation. This label IS an accessibility
    // label - base_sdk feeds it to Semantics(label:) and Tooltip(message:) -
    // so it goes through translation, and English stays exactly what it was.
    test('the label is TRANSLATED, by key, never a bare literal', () {
      expect(ProductivityPlusNav.labelKeyFor(WorkspaceList.tasks), 'new_task');
      expect(ProductivityPlusNav.labelKeyFor(WorkspaceList.notes), 'new_note');
      for (final WorkspaceList list in WorkspaceList.values) {
        final String key = ProductivityPlusNav.labelKeyFor(list);
        // The label is whatever translation answers for the key - not a
        // literal the widget carries. Serve a row and the bar follows it.
        expect(
          ProductivityPlusNav(list: list, onNew: () {}).label,
          AppHelpers.getTranslation(key),
        );
      }
    });

    test('and with no row served it still reads the sheet\'s own word', () {
      // Behaviour-identical in English: unserved, getTranslation falls
      // through humanizeTrKey, which renders these two as exactly the words
      // the sheet uses - so the button and the sheet it opens cannot drift
      // apart, which is why the keys are spelled the way they are.
      for (final WorkspaceList list in WorkspaceList.values) {
        expect(
          AppHelpers.humanizeTrKey(ProductivityPlusNav.labelKeyFor(list)),
          newItemSheetLabelFor(list),
        );
        expect(
          ProductivityPlusNav(list: list, onNew: () {}).label,
          newItemSheetLabelFor(list),
        );
      }
    });
  });

  group('the installed /tasks page', () {
    /// The template's source. It imports the composed app's comms_sdk, so it
    /// cannot be pumped in this package's tests; what CAN be pinned is what
    /// it mounts.
    final String source =
        File('templates/pages/tasks/tasks_page.dart').readAsStringSync();

    /// The same source with runs of whitespace collapsed, so an assertion can
    /// pin the widget NESTING without also pinning the indentation a
    /// formatter owns.
    final String flat = source.replaceAll(RegExp(r'\s+'), ' ');

    test('mounts the plus on the nav, in a Stack over the page body', () {
      // base_sdk's host contract: "Hosts place it in a Stack over the page
      // body and hand it a FloatingNavMode" (floating_bottom_nav.dart), and
      // the slot adaptive_bar.md §3 names - "a full-size Stack slot
      // (Positioned.fill, or the usual full-size Align)". This is the form
      // every other host in the fleet uses (comms setting_page.dart).
      expect(
        flat,
        contains(
          'Positioned.fill( child: Align( '
          'alignment: Alignment.bottomCenter, '
          'child: ProductivityPlusNav(',
        ),
      );
      expect(source, contains('onChooseList: _chooseNewItem'));
    });

    test('and NOT in the Scaffold slot, which docks it in a strip', () {
      // Scaffold.bottomNavigationBar reserves the pill's height as body
      // inset, so the bar is docked in a lane of its own - against a housing
      // specified to float "with a margin above the bottom edge, never
      // docked flush" - the frosted BlurWrap gets a flat background colour to
      // blur instead of the list, and the keyboard inset is counted twice.
      // A move back to that slot fails HERE rather than on a screenshot.
      expect(source, isNot(contains('bottomNavigationBar:')));
    });

    test('and keeps no plus of its own', () {
      // The FloatingActionButton and the GestureDetector that gave it a long
      // press are GONE, not merely unreachable: a deleted widget cannot be
      // asserted on any other way.
      expect(source, isNot(contains('floatingActionButton:')));
      expect(source, isNot(contains('FloatingActionButton(')));
      expect(source, isNot(contains("ValueKey<String>('compose-fab-gestures')")));
      expect(source, isNot(contains("'tasks-compose'")));
      expect(source, isNot(contains("'notes-compose'")));
    });
  });
}
