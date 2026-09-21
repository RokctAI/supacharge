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


// The shared INPUT surfaces, restyling themselves the moment the theme mode
// changes. Each named its ink, its menu fill or its key greys from AppStyle's
// app-wide isDark static and resolved nothing from its BuildContext, so the
// flip scheduled no rebuild of them at all - and these are the widgets a user
// is most likely to be looking straight at (and typing into) when they flip
// the mode, since the toggle lives one page away on the profile.
//
// Every subject here is mounted as the host's `const` child, so a parent
// rebuild provably cannot deliver the flip: only a dependency of the
// subject's own on the inherited theme can restyle it. Nothing is remounted -
// the host flips AppStyle.setBrightness plus themeMode exactly as
// AppNotifier.changeTheme does, and the test only pumps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/presentation/components/keypad/money_keypad.dart';
import 'package:base_sdk/src/presentation/components/text_fields/outline_bordered_text_field.dart';
import 'package:base_sdk/src/presentation/components/text_fields/search_text_field.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underline_drop_down.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';

import 'theme_flip_host.dart';

// Top-level callbacks so every subject below can be a `const` instance.
void _onString(String _) {}
void _onVoid() {}

/// The [TextField] a [TextFormField]-shaped subject builds.
TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    // AppHelpers.getTranslation (the drop-down's hint, a field's default
    // placeholder) reads LocalStorage.
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() => AppStyle.isDark = wasDark);

  testWidgets('a search field restyles its ink, cursor and icon on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const SearchTextField(hintText: 'Search'),
      read: (WidgetTester t) => _field(t).style?.color,
      expected: AppStyle.inkFor,
    );

    // The cursor and the leading glyph come from the same read.
    expect(_field(tester).cursorColor, AppStyle.inkFor(Brightness.light));
    expect(iconInk(tester, Remix.search_eye_line),
        AppStyle.inkFor(Brightness.light));
  });

  testWidgets("a search field keeps the caller's bgColor across a flip",
      (WidgetTester tester) async {
    // bgColor is the CALLER's colour: the field tints it and must not start
    // resolving it with the mode.
    await expectPinnedOnFlip(
      tester,
      child: const SearchTextField(hintText: 'Search', bgColor: AppStyle.red),
      read: (WidgetTester t) => _field(t).decoration?.fillColor,
    );
  });

  testWidgets('an outlined-border field restyles its label on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const OutlinedBorderTextField(
        label: 'EMAIL',
        hint: 'you@example.com',
      ),
      read: (WidgetTester t) => textInk(t, 'EMAIL'),
      expected: AppStyle.inkFor,
    );

    // The text being typed resolves from the same read.
    expect(_field(tester).style?.color, AppStyle.inkFor(Brightness.light));
  });

  testWidgets('an underline drop-down restyles its menu fill on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const UnderlineDropDown(
        list: <String>[],
        onChanged: _onString,
        hint: 'gender',
      ),
      read: (WidgetTester t) => t
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .dropdownColor,
      expected: AppStyle.cardFor,
    );

    // The selected-value ink and the drop-down glyph resolve with it.
    final DropdownButton<String> button = tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(button.style?.color, AppStyle.inkFor(Brightness.light));
    expect(button.iconEnabledColor, AppStyle.inkFor(Brightness.light));
    // The hint renders through the same resolving ink.
    expect(find.text(AppHelpers.getTranslation('gender')), findsOneWidget);
  });

  testWidgets('the money keypad restyles its key fill on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const MoneyKeypad(
        onDigit: _onString,
        onBackspace: _onVoid,
        onOk: _onVoid,
        onDecimal: _onVoid,
      ),
      read: (WidgetTester t) => containerFill(t, _keyFinder('moneyKey1')),
      expected: AppStyle.cardAltFor,
    );

    // The hairline and the digit ink resolve from the same read.
    expect(containerStroke(tester, _keyFinder('moneyKey1')),
        AppStyle.subtleStrokeFor(Brightness.light));
    expect(textInk(tester, '1'), AppStyle.inkFor(Brightness.light));
  });

  testWidgets("the money keypad keeps the OK key's brand fill across a flip",
      (WidgetTester tester) async {
    // AppStyle.primary is polarity-pinned brand, not a mode role.
    await expectPinnedOnFlip(
      tester,
      child: const MoneyKeypad(
        onDigit: _onString,
        onBackspace: _onVoid,
        onOk: _onVoid,
        onDecimal: _onVoid,
      ),
      read: (WidgetTester t) => containerFill(t, _keyFinder('moneyKeyOk')),
    );
  });
}

/// The decorated [Container] a keypad key draws.
Finder _keyFinder(String keyId) => find.descendant(
      of: find.byKey(Key(keyId)),
      matching: find.byWidgetPredicate(
          (Widget w) => w is Container && w.decoration is BoxDecoration),
    );
