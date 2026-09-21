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

// Dark-mode legibility gate for the manager profile hub.
//
// When the hub moved onto base_sdk's GenericProfilePage its scaffold became
// AppStyle.surfaceDark (#101010 in dark mode). The shop block at the head of
// the page was repointed to the mode-resolving ink tokens; the blocks BELOW
// it were not, so on a dark build the bottom two-thirds of the hub painted:
//
//   * every Sections/PRODUCTIVITY row title in AppStyle.blackColor
//     (#000000) -> 1.10:1 against the page. Invisible.
//   * both group titles in TitleAndIcon's pinned default AppStyle.black
//     (#232B2F) -> 1.32:1. Invisible.
//   * the working-hours pill hairline in AppStyle.borderColor (#E6E6E6),
//     which is the inverse failure: 15.25:1 on the dark page (a near-white
//     outline shouting off a screen whose every other stroke is #2E2E2E)
//     and 1.06:1 on the light page (#ECECEF), where it all but vanishes.
//
// Two kinds of check, because the hub spans two testable surfaces:
//
//   1. WIDGET PUMPS for SectionsItem and base_sdk's TitleAndIcon, which
//      carry no `${package}` imports and so can be driven directly (same
//      contract as profile_productivity_gate_test.dart). These resolve the
//      real painted colour in each polarity and assert WCAG contrast.
//   2. A SOURCE GATE over templates/.../restaurant_page.dart. That file
//      imports `package:${package}/presentation/routes/app_router.dart`, so
//      it cannot be pumped from this package at all — the pill's stroke and
//      the group-title call sites are only reachable by reading the
//      template, the same way tr_keys_injection_guard_test.dart reads its
//      inputs off disk. The gate pins that every colour the page paints is
//      either a mode-resolving AppStyle getter or a deliberately
//      polarity-pinned brand accent, and that both TitleAndIcon call sites
//      pass titleColor explicitly.
//
// On why the SHARED default in base_sdk's title_icon.dart is left alone:
// TitleAndIcon's `titleColor = AppStyle.black` is correct for the ~90 fleet
// call sites that sit on ModalWrap's white sheet (AppStyle.white @ 0.9) —
// including the two sheets this very hub opens, edit_restaurant_modal and
// working_time_modal. Flipping the default to textPrimary would paint those
// titles white-on-white in dark mode: it trades this bug for its mirror. A
// widget cannot resolve ink it does not know the background of, so the dark
// host passes the token; the pinned default is pinned here as such.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';

import '../templates/pages/manager/restaurant/widgets/sections_item.dart';

// ---------------------------------------------------------------------------
// WCAG 2.1 relative luminance / contrast ratio (1.4.3). Text on this page is
// body copy, so the bar is 4.5:1.
// ---------------------------------------------------------------------------
const double _kTextContrastFloor = 4.5;

double _channel(int v) {
  final c = v / 255.0;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
}

double _luminance(Color c) =>
    0.2126 * _channel((c.r * 255).round()) +
    0.7152 * _channel((c.g * 255).round()) +
    0.0722 * _channel((c.b * 255).round());

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${((c.a * 255).round() << 24 | (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Pumps [child] on the host's own page surface in the given polarity.
Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        themeMode: AppStyle.isDark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          // Exactly what GenericProfilePage paints behind these blocks.
          backgroundColor: AppStyle.surfaceDark,
          body: child,
        ),
      ),
    );

void _expectLegible(Color ink, Color surface, String what) {
  final ratio = _contrast(ink, surface);
  expect(
    ratio,
    greaterThanOrEqualTo(_kTextContrastFloor),
    reason: '$what paints ${_hex(ink)} on ${_hex(surface)} — '
        '${ratio.toStringAsFixed(2)}:1, below the ${_kTextContrastFloor}:1 '
        'body-text floor. Use a mode-resolving AppStyle token '
        '(textPrimary / textDarkSecondary), not a polarity-pinned constant.',
  );
}

/// Every colour identifier the hub template is allowed to paint with.
///
/// Mode-resolving surface/ink getters (app_style.dart:95-104) — these flip
/// with AppStyle.isDark and are the correct choice for anything structural.
const Set<String> _resolvingTokens = {
  'textPrimary',
  'textDarkSecondary',
  'textDarkFaint',
  'surfaceDark',
  'cardDark',
  'cardDarkAlt',
  'strokeDark',
  'strokeDarkSubtle',
};

/// Deliberately polarity-PINNED, and correct as such: brand and semantic
/// accents that must read the same in both modes.
///   primary    — the injected brand orange (app_style.dart:43)
///   red/white  — the promo badge: white glyph on the red disc (:197)
///   starColor  — the rating star (:192)
///   transparent
///   textGrey   — the 4px separator dot between shop title and rating. A
///                decorative mid-grey that clears 5.44:1 on the dark page and
///                2.97:1 on the light one; not the reported defect, and
///                restyling it is a design call, not a bug fix.
const Set<String> _pinnedAccents = {
  'primary',
  'red',
  'white',
  'starColor',
  'transparent',
  'textGrey',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() => AppStyle.isDark = wasDark);

  // -------------------------------------------------------------------------
  // 1. The hub rows (SectionsItem) — Sections list + the PRODUCTIVITY gate.
  // -------------------------------------------------------------------------
  group('SectionsItem row ink', () {
    Future<List<Color>> pumpRow(WidgetTester tester,
        {String? subtitle}) async {
      await tester.pumpWidget(_host(SectionsItem(
        title: 'Income',
        subtitle: subtitle,
        icon: Remix.line_chart_line,
        onTap: () {},
      )));
      final title = tester.widget<Text>(find.text('Income'));
      return [title.style!.color!];
    }

    testWidgets('a single-line row stays legible on the dark page',
        (tester) async {
      AppStyle.setBrightness(Brightness.dark);
      final inks = await pumpRow(tester);
      _expectLegible(inks.first, AppStyle.surfaceDark, 'SectionsItem title');
    });

    testWidgets('a two-line glance row stays legible on the dark page',
        (tester) async {
      AppStyle.setBrightness(Brightness.dark);
      final inks = await pumpRow(tester, subtitle: '3 open · 1 due today');
      _expectLegible(
          inks.first, AppStyle.surfaceDark, 'SectionsItem title (glance row)');
    });

    testWidgets('the same row stays legible on the light page — the fix '
        'must not merely invert the bug', (tester) async {
      AppStyle.setBrightness(Brightness.light);
      final inks = await pumpRow(tester);
      _expectLegible(inks.first, AppStyle.surfaceDark, 'SectionsItem title');
    });

    testWidgets('row ink actually tracks the mode', (tester) async {
      AppStyle.setBrightness(Brightness.dark);
      final dark = (await pumpRow(tester)).first;
      AppStyle.setBrightness(Brightness.light);
      final light = (await pumpRow(tester)).first;
      expect(dark, isNot(equals(light)),
          reason: 'SectionsItem paints ${_hex(dark)} in both polarities — '
              'that is a pinned constant, not a resolving token.');
    });
  });

  // -------------------------------------------------------------------------
  // 2. The group titles (base_sdk TitleAndIcon), as the hub calls them.
  // -------------------------------------------------------------------------
  group('group title ink', () {
    Future<Color> pumpTitle(WidgetTester tester, {Color? titleColor}) async {
      await tester.pumpWidget(_host(TitleAndIcon(
        title: 'Sections',
        titleColor: titleColor ?? AppStyle.black,
      )));
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      return (rich.text as TextSpan).children!.isEmpty
          ? (rich.text as TextSpan).style!.color!
          : ((rich.text as TextSpan).children!.first as TextSpan)
              .style!
              .color!;
    }

    testWidgets('the token the hub passes is legible in dark mode',
        (tester) async {
      AppStyle.setBrightness(Brightness.dark);
      final ink = await pumpTitle(tester, titleColor: AppStyle.textPrimary);
      _expectLegible(ink, AppStyle.surfaceDark, 'TitleAndIcon group title');
    });

    testWidgets('the token the hub passes is legible in light mode',
        (tester) async {
      AppStyle.setBrightness(Brightness.light);
      final ink = await pumpTitle(tester, titleColor: AppStyle.textPrimary);
      _expectLegible(ink, AppStyle.surfaceDark, 'TitleAndIcon group title');
    });

    testWidgets(
        "the widget's OWN default is pinned black and is NOT dark-safe — "
        'pinned here so nobody "fixes" it in base_sdk and blanks the '
        'white-sheet call sites instead', (tester) async {
      AppStyle.setBrightness(Brightness.dark);
      final ink = await pumpTitle(tester);
      expect(ink, AppStyle.black);
      expect(_contrast(ink, AppStyle.surfaceDark),
          lessThan(_kTextContrastFloor));
      // ...and correct where it is meant to be used: ModalWrap's white sheet.
      _expectLegible(ink, AppStyle.white, 'TitleAndIcon default on a sheet');
    });
  });

  // -------------------------------------------------------------------------
  // 3. The template source gate — the working-hours pill stroke and the
  //    group-title call sites, neither of which can be pumped from here.
  // -------------------------------------------------------------------------
  group('restaurant_page.dart template paint gate', () {
    late String source;

    setUpAll(() {
      source = File(
        'templates/pages/manager/restaurant/restaurant_page.dart',
      ).readAsStringSync();
    });

    // Strip comments first: the doc comments above deliberately NAME the
    // retired constants, and the gate must read code, not prose.
    String code() => source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//') &&
            !l.trimLeft().startsWith('///'))
        .join('\n');

    test('every colour the hub paints resolves with the mode '
        '(or is an approved pinned accent)', () {
      // `AppStyle.foo` NOT followed by `(` — i.e. a colour, not a text-style
      // helper such as interRegular(...).
      final used = RegExp(r'AppStyle\.([A-Za-z_][A-Za-z0-9_]*)\s*(\()?')
          .allMatches(code())
          .where((m) => m.group(2) == null)
          .map((m) => m.group(1)!)
          .toSet();

      final offenders =
          used.difference(_resolvingTokens).difference(_pinnedAccents).toList()
            ..sort();

      expect(
        offenders,
        isEmpty,
        reason: 'restaurant_page.dart paints with polarity-pinned '
            'constant(s) $offenders. The page is hosted on '
            'AppStyle.surfaceDark (#101010 in dark mode), so structural ink '
            'and strokes must use the mode-resolving getters '
            '(textPrimary / strokeDark / ...). If one of these really is a '
            'brand accent that must not flip, add it to _pinnedAccents with '
            'the reason.',
      );
    });

    test('the working-hours pill strokes with the resolving stroke token', () {
      expect(
        code(),
        contains('color: AppStyle.strokeDark'),
        reason: 'MerchantWorkingHoursSection lost its mode-resolving '
            'hairline. AppStyle.borderColor (#E6E6E6) is 15.25:1 on the dark '
            'page and 1.06:1 on the light one; strokeDark is the token '
            'GenericProfilePage strokes its own cards with.',
      );
      expect(code(), isNot(contains('AppStyle.borderColor')));
    });

    /// Every `TitleAndIcon(...)` argument list in [src], sliced by matching
    /// parens (the calls nest `getTranslation(...)`, so a regex would stop
    /// at the first `)`).
    List<String> titleAndIconCalls(String src) {
      final calls = <String>[];
      for (final m in RegExp(r'TitleAndIcon\(').allMatches(src)) {
        var depth = 1;
        var i = m.end;
        while (i < src.length && depth > 0) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') depth--;
          i++;
        }
        calls.add(src.substring(m.end, i - 1));
      }
      return calls;
    }

    test('both group titles pass titleColor explicitly', () {
      final calls = titleAndIconCalls(code());

      expect(calls, hasLength(2),
          reason: 'expected the PRODUCTIVITY and Sections group titles; '
              'found ${calls.length} TitleAndIcon call site(s).');

      for (final call in calls) {
        expect(
          call,
          contains('titleColor:'),
          reason: 'a TitleAndIcon on this dark-surfaced page relies on the '
              "widget's pinned-black titleColor default (#232B2F, 1.32:1 on "
              '#101010). Pass titleColor: AppStyle.textPrimary. The shared '
              'default must stay black for the white-sheet call sites.',
        );
      }
    });
  });
}
