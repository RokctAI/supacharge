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

// The one subject of this sweep that CANNOT be given a widget test, plus the
// net that keeps the rest of the package from drifting back.
//
// _WelcomeCarousel is gated behind `const bool kShowWelcomeCarousel = false`
// (Ray, 2026-08-22: the welcome step is just the app's name and motto now).
// A compile-time const false means no test in any package can mount the
// carousel: IntroPage's build never constructs it, and the flag is a top-level
// const with no seam to override. So its half of the fix is checked on the
// source instead — thoroughly, because nothing else can check it at all.
// Every other subject of this sweep has a real widget test in
// intro_page_theme_mode_test.dart or welcome_text_theme_mode_test.dart, which
// mount it, flip the theme mode without remounting and assert the colour
// moved.
//
// The second group is a regression net over the whole package: a build that
// decides a colour from one of AppStyle's mode-resolving statics is theme-
// blind unless something in its own build registers an inherited-widget
// dependency that the flip reschedules, and a mutable static never is one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The mode-resolving statics: each one answers from the app-wide
  /// AppStyle.isDark flag, which is a mutable static and not an inherited
  /// widget. The polarity-pinned members (white, black, blackColor, primary,
  /// green, red, transparent, bottomNavigationBarColor) and the deliberately
  /// mode-blind surfaceLightRaw/surfaceDarkRaw pair are NOT on this list and
  /// are meant to be read directly.
  const List<String> modeResolvingStatics = <String>[
    'isDark',
    'surfaceDark',
    'cardDark',
    'cardDarkAlt',
    'strokeDark',
    'strokeDarkSubtle',
    'textDarkSecondary',
    'textDarkFaint',
    'textPrimary',
  ];

  /// One file's source with its comment lines dropped: the fix's own
  /// explanatory notes name the statics they replaced and quote the builders
  /// the lookup has to sit outside of, so a check over raw text would read
  /// those prose mentions as code.
  String codeOf(File file) => file
      .readAsLinesSync()
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  /// Every Dart source file this package ships, comments dropped.
  Map<String, String> libSources() {
    final Map<String, String> sources = <String, String>{};
    for (final FileSystemEntity entity
        in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      sources[entity.path] = codeOf(entity);
    }
    return sources;
  }

  group('_WelcomeCarousel — gated off, so checked on the source', () {
    late String source;

    setUpAll(() {
      source = codeOf(
          File('lib/src/common/presentation/pages/intro/intro_page.dart'));
    });

    test('the flag that makes it unmountable is still a const false', () {
      expect(source, contains('const bool kShowWelcomeCarousel = false;'),
          reason: 'if the carousel is switchable again, replace this guard '
              'with a real widget test that mounts it');
    });

    test('its build reads the mode from the inherited theme, once', () {
      final int start = source.indexOf('class _WelcomeCarouselState');
      expect(start, isNot(-1));
      final int end = source.indexOf('class _PostCarouselFlow', start);
      expect(end, isNot(-1));
      final String body = source.substring(start, end);

      expect(body, contains('Theme.of(context).brightness'),
          reason: 'the carousel must take the mode from the inherited theme, '
              'not from the AppStyle.isDark static');
      expect(
          'Theme.of(context).brightness'.allMatches(body).length, 1,
          reason: 'exactly one lookup, in build and outside the PageView '
              'itemBuilder — a lookup inside the builder would register the '
              'dependency on the PageView element instead of this one');

      // The lookup has to sit in build BEFORE the PageView it feeds, which is
      // what "outside every inner builder" means for this widget.
      expect(body.indexOf('Theme.of(context).brightness'),
          lessThan(body.indexOf('PageView.builder')));
    });

    test('and it names its colours through the brightness-taking helpers', () {
      final int start = source.indexOf('class _WelcomeCarouselState');
      final int end = source.indexOf('class _PostCarouselFlow', start);
      final String body = source.substring(start, end);

      expect(body, contains('AppStyle.inkFor(brightness)'));
      expect(body, contains('AppStyle.secondaryInkFor(brightness)'));
    });
  });

  group('the package as a whole', () {
    test('no build decides a colour from a mode-resolving AppStyle static',
        () {
      final List<String> offenders = <String>[];
      libSources().forEach((String path, String source) {
        for (final String name in modeResolvingStatics) {
          if (RegExp('AppStyle\\.$name\\b').hasMatch(source)) {
            offenders.add('$path reads AppStyle.$name');
          }
        }
      });
      expect(offenders, isEmpty,
          reason: 'these resolve the mode from the app-wide AppStyle.isDark '
              'flag, which is not an inherited widget, so a theme-mode flip '
              'schedules no rebuild and the widget keeps the previous mode\'s '
              'colours. Name the colour through the brightness-taking helper '
              'for its role (inkFor / secondaryInkFor / faintFor / surfaceFor '
              '/ cardFor / cardAltFor / strokeFor / subtleStrokeFor) and read '
              'Theme.of(context).brightness once in build instead');
    });

    test('every build that names a brightness looked it up on the context',
        () {
      final List<String> offenders = <String>[];
      libSources().forEach((String path, String source) {
        final int uses = RegExp(r'For\(brightness\)').allMatches(source).length;
        final int lookups =
            'Theme.of(context).brightness'.allMatches(source).length;
        if (uses > 0 && lookups == 0) {
          offenders.add('$path passes a brightness it never looked up');
        }
      });
      expect(offenders, isEmpty);
    });
  });
}
