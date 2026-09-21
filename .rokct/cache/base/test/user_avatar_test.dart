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

// The shared avatar's three states, and the one thing it must never draw.
//
// Ray, 2026-09-18: "profile image is ? no image or letters why". Both avatar
// copies this widget replaced ended on `source.isEmpty ? '?' : ...`, so a
// signed-in session whose cached ProfileData carried no picture AND no name
// - what a restored session looks like before the profile fetch lands - got
// a question mark. The ladder is picture, then initials, then a neutral
// person glyph, and never a "?".

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/presentation/components/custom_network_image.dart';
import 'package:base_sdk/src/presentation/components/user_avatar.dart';

/// An inline SVG so the image state renders from its own bytes: a widget test
/// has no network, and a plain URL would only ever reach
/// CachedNetworkImage's error state.
const String _inlinePicture =
    'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" '
    'width="8" height="8"><rect width="8" height="8" fill="#123456"/></svg>';

/// AppStyle's type helpers scale with screenutil, so the widget needs the
/// same initialised ScreenUtil every app shell gives it.
Future<void> _pump(WidgetTester tester, ProfileData? user) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: Center(child: UserAvatar(user: user, size: 56)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('UserAvatar - state 1: the person has a picture', () {
    testWidgets('draws the picture, and neither initials nor glyph',
        (tester) async {
      await _pump(
        tester,
        ProfileData(firstname: 'Ray', lastname: 'Mokoena',
            img: _inlinePicture),
      );

      expect(find.byType(CustomNetworkImage), findsOneWidget);
      expect(find.byKey(UserAvatar.initialsKey), findsNothing);
      expect(find.byKey(UserAvatar.glyphKey), findsNothing);
    });
  });

  group('UserAvatar - state 2: no picture, but a name', () {
    testWidgets('draws the first letter of each of the first two words',
        (tester) async {
      await _pump(tester, ProfileData(firstname: 'Ray', lastname: 'Mokoena'));

      expect(find.byKey(UserAvatar.initialsKey), findsOneWidget);
      expect(find.text('RM'), findsOneWidget);
      expect(find.byKey(UserAvatar.glyphKey), findsNothing);
      expect(find.byType(CustomNetworkImage), findsNothing);
    });

    testWidgets('draws one letter for a one-word name', (tester) async {
      await _pump(tester, ProfileData(firstname: 'Ray'));

      expect(find.text('R'), findsOneWidget);
      expect(find.byKey(UserAvatar.glyphKey), findsNothing);
    });

    testWidgets('falls back to the email address when there is no name',
        (tester) async {
      await _pump(tester, ProfileData(email: 'ray@rokct.test'));

      expect(find.text('R'), findsOneWidget);
      expect(find.byKey(UserAvatar.glyphKey), findsNothing);
    });

    test('takes at most the first two words, and ignores extra spacing', () {
      expect(UserAvatar.initialsFromName('Ray  Thabo   Mokoena'), 'RT');
      expect(UserAvatar.initialsFromName('  Ray  '), 'R');
    });

    test('uppercases with Unicode default casing, keeping the whole letter',
        () {
      // A combining acute (U+0301) must ride along, so the letter keeps its
      // accent instead of being cut back to a bare "E". Decomposed in,
      // decomposed out: Unicode's default casing does not recompose.
      expect(UserAvatar.initialsFromName('éva nkosi'), 'ÉN');
      // The precomposed form (U+00E9) uppercases to U+00C9.
      expect(UserAvatar.initialsFromName('éva nkosi'), 'ÉN');
      // Cased scripts other than Latin uppercase normally.
      expect(UserAvatar.initialsFromName('ёж кот'), 'ЁК');
      // Caseless scripts pass through untouched rather than being mangled.
      expect(UserAvatar.initialsFromName('李 雷'), '李雷');
      // An astral-plane code point stays one whole character rather than
      // being sliced into a lone surrogate.
      expect(UserAvatar.initialsFromName('😀a'), '😀');
    });
  });

  group('UserAvatar - state 3: nothing to go on', () {
    testWidgets('draws the neutral person glyph for an empty profile',
        (tester) async {
      await _pump(tester, ProfileData());

      expect(find.byKey(UserAvatar.glyphKey), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byKey(UserAvatar.glyphKey)).icon,
        Icons.person_outline,
      );
      expect(find.byKey(UserAvatar.initialsKey), findsNothing);
      expect(find.byType(CustomNetworkImage), findsNothing);
    });

    testWidgets('draws the glyph for no profile at all', (tester) async {
      await _pump(tester, null);

      expect(find.byKey(UserAvatar.glyphKey), findsOneWidget);
    });

    testWidgets('never draws a question mark in any state', (tester) async {
      for (final ProfileData? user in <ProfileData?>[
        null,
        ProfileData(),
        ProfileData(firstname: '', lastname: '', email: ''),
        ProfileData(firstname: '   '),
        ProfileData(firstname: 'Ray', lastname: 'Mokoena'),
        ProfileData(img: _inlinePicture),
      ]) {
        await _pump(tester, user);
        expect(find.text('?'), findsNothing,
            reason: 'the avatar must never say "we do not know who you are"');
      }
    });

    test('initialsOf reports nothing to draw, so the glyph wins', () {
      expect(UserAvatar.initialsOf(null), '');
      expect(UserAvatar.initialsOf(ProfileData()), '');
      expect(
        UserAvatar.initialsOf(
            ProfileData(firstname: ' ', lastname: ' ', email: ' ')),
        '',
      );
      expect(UserAvatar.initialsFromName(''), '');
    });
  });
}
