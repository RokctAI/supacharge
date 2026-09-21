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

// THE KEY PAD (chip 390, approved 11u/11y): the shared money-entry
// surface. Covers the 11u/11y layout contract (digits grid with the 00
// money key and ⌫, the optional . | OK confirm row), the
// pure-input-surface rule (no focusable text anywhere — the OS keyboard
// can never ride behind it), the MoneyEntry shared editing rules, and
// the KeySound gate (persisted, DEFAULT ON) staying fail-open under the
// test binding.

import 'package:base_sdk/base_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('MoneyKeypad (chip 390)', () {
    testWidgets(
        'renders the 11u/11y grid — 1..9, 00, 0, backspace — and emits '
        'each key', (tester) async {
      final pressed = <String>[];
      var backspaces = 0;
      await tester.pumpWidget(_host(MoneyKeypad(
        onDigit: pressed.add,
        onBackspace: () => backspaces++,
      )));

      for (final digit in [
        '1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', //
      ]) {
        expect(find.byKey(Key('moneyKey$digit')), findsOneWidget,
            reason: 'key $digit missing');
        await tester.tap(find.byKey(Key('moneyKey$digit')));
      }
      await tester.tap(find.byKey(const Key('moneyKeyBackspace')));
      await tester.pump();

      expect(pressed,
          ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0']);
      expect(backspaces, 1);
      // No confirm row unless wired.
      expect(find.byKey(const Key('moneyKeyDecimal')), findsNothing);
      expect(find.byKey(const Key('moneyKeyOk')), findsNothing);
    });

    testWidgets('the . | OK confirm row renders when wired and emits',
        (tester) async {
      var decimals = 0;
      var oks = 0;
      await tester.pumpWidget(_host(MoneyKeypad(
        onDigit: (_) {},
        onBackspace: () {},
        onDecimal: () => decimals++,
        onOk: () => oks++,
      )));
      await tester.tap(find.byKey(const Key('moneyKeyDecimal')));
      await tester.tap(find.byKey(const Key('moneyKeyOk')));
      await tester.pump();
      expect(decimals, 1);
      expect(oks, 1);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets(
        'pure input surface: the pad carries NO focusable text entry '
        '(the 11y ruling — the OS keyboard can never appear behind it)',
        (tester) async {
      await tester.pumpWidget(_host(MoneyKeypad(
        onDigit: (_) {},
        onBackspace: () {},
        onDecimal: () {},
        onOk: () {},
      )));
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('MoneyEntry shared editing rules', () {
    test('digits append; bare zero is replaced, 00 on empty stays 0', () {
      expect(MoneyEntry.appendDigit('', '5'), '5');
      expect(MoneyEntry.appendDigit('5', '0'), '50');
      expect(MoneyEntry.appendDigit('0', '7'), '7');
      expect(MoneyEntry.appendDigit('', '00'), '0');
      expect(MoneyEntry.appendDigit('0', '00'), '0');
      expect(MoneyEntry.appendDigit('2', '00'), '200');
    });

    test('one decimal point, at most two cents digits', () {
      expect(MoneyEntry.decimal('12'), '12.');
      expect(MoneyEntry.decimal('12.'), '12.');
      expect(MoneyEntry.decimal(''), '0.');
      expect(MoneyEntry.appendDigit('12.', '5'), '12.5');
      expect(MoneyEntry.appendDigit('12.5', '0'), '12.50');
      expect(MoneyEntry.appendDigit('12.50', '9'), '12.50');
      expect(MoneyEntry.appendDigit('12.', '00'), '12.00');
      expect(MoneyEntry.appendDigit('12.5', '00'), '12.50');
    });

    test('backspace removes the last character', () {
      expect(MoneyEntry.backspace('12.5'), '12.');
      expect(MoneyEntry.backspace('1'), '');
      expect(MoneyEntry.backspace(''), '');
    });
  });

  group('KeySound gate', () {
    test('defaults ON, persists OFF and back', () async {
      expect(KeySound.enabled, isTrue);
      await KeySound.setEnabled(false);
      expect(KeySound.enabled, isFalse);
      expect(LocalStorage.getKeypadSound(), isFalse);
      await KeySound.setEnabled(true);
      expect(KeySound.enabled, isTrue);
    });

    testWidgets('tap()/error() are fail-open under the test binding',
        (tester) async {
      // Must not throw (no audioplayers platform channel here) — and a
      // keypad press routes through the same call.
      KeySound.tap();
      KeySound.error();
      await tester.pumpWidget(_host(MoneyKeypad(
        onDigit: (_) {},
        onBackspace: () {},
      )));
      await tester.tap(find.byKey(const Key('moneyKey5')));
      await tester.pump();
    });
  });
}
