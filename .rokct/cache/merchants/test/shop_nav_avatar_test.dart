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


// The manager shell's profile-tab avatar (ShopNavAvatar): an avatar URL
// that cannot be resolved (demo / offline shells — paas_manager guided
// tour 33952102598) degrades to the profile header's initials-on-brand
// fallback, never to a broken-image glyph.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';

import 'package:base_sdk/src/constants/demo_images.dart';
import 'package:merchants_sdk/src/manager/presentation/main/shop_nav_avatar.dart';

/// An image provider whose every load fails — what an unreachable host
/// looks like to [Image], without a network in the test.
class _ThrowingImage extends ImageProvider<_ThrowingImage> {
  const _ThrowingImage();

  @override
  Future<_ThrowingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ThrowingImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _ThrowingImage key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('unresolvable avatar')),
      );
}

const Key _fallback = Key('shopNavAvatarFallback');

Future<void> _pump(WidgetTester tester, Widget avatar) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        home: Scaffold(body: Center(child: avatar)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void _expectNoBrokenGlyph() {
  expect(find.byIcon(Remix.image_line), findsNothing);
  expect(find.byIcon(Remix.file_unknow_line), findsNothing);
}

void main() {
  testWidgets(
      'a provider that throws: the shop\'s initial on the brand circle, '
      'no broken-image glyph', (tester) async {
    await _pump(
      tester,
      const ShopNavAvatar(
        url: 'https://shop.invalid/logo.png',
        name: 'Corner Kitchen',
        size: 40,
        image: _ThrowingImage(),
      ),
    );
    expect(find.byKey(_fallback), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    _expectNoBrokenGlyph();
    expect(tester.takeException(), isNull);
  });

  testWidgets('no URL at all: the initial straight away, no image widget',
      (tester) async {
    await _pump(
      tester,
      const ShopNavAvatar(url: '', name: 'corner kitchen', size: 40),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(_fallback), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    _expectNoBrokenGlyph();
  });

  testWidgets('no URL and no name: the person glyph', (tester) async {
    await _pump(
      tester,
      const ShopNavAvatar(url: null, name: null, size: 40),
    );
    expect(find.byKey(_fallback), findsOneWidget);
    expect(find.byIcon(Remix.user_3_fill), findsOneWidget);
    _expectNoBrokenGlyph();
  });

  testWidgets('an inline data: logo (the demo shop\'s) still draws the '
      'artwork itself', (tester) async {
    await _pump(
      tester,
      const ShopNavAvatar(
        url: DemoImages.shopMark,
        name: 'Corner Kitchen',
        size: 40,
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byKey(_fallback), findsNothing);
    _expectNoBrokenGlyph();
  });
}
