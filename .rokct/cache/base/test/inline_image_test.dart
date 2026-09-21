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

// Inline ("data:") images must never reach the network layer.
//
// The demo seed data across the commerce SDKs used to point at a public
// placeholder host. A demo build talks to no backend, and the emulator that
// walks the guided tour in CI has no dependable route to that host either, so
// every seeded shop/product/category/brand/banner image fell through to
// CachedNetworkImage's error state and the tour published store screenshots
// full of broken-image glyphs. DemoImages carries its pixels inline instead;
// these tests pin the routing that makes that work.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/constants/demo_images.dart';
import 'package:base_sdk/src/presentation/components/custom_network_image.dart';
import 'package:base_sdk/src/services/app_helpers.dart';

void main() {
  group('AppHelpers inline-image detection', () {
    test('recognises data: image URIs and nothing else', () {
      expect(AppHelpers.isInlineImage(DemoImages.shopCover), isTrue);
      expect(AppHelpers.isInlineImage('data:image/png;base64,AAAA'), isTrue);
      expect(AppHelpers.isInlineImage('https://example.test/a.png'), isFalse);
      expect(AppHelpers.isInlineImage(null), isFalse);
      expect(AppHelpers.isInlineImage(''), isFalse);
    });

    test('separates inline SVG markup from inline raster payloads', () {
      expect(AppHelpers.isInlineSvg(DemoImages.product), isTrue);
      expect(AppHelpers.isInlineSvg('data:image/png;base64,AAAA'), isFalse);
    });

    test('decodes plain and base64 payloads, and survives malformed ones', () {
      const String markup = '<svg xmlns="http://www.w3.org/2000/svg"/>';
      expect(
        AppHelpers.inlineImagePayload('data:image/svg+xml;utf8,$markup'),
        markup,
      );
      final String encoded = base64.encode(utf8.encode(markup));
      expect(
        AppHelpers.inlineImagePayload('data:image/svg+xml;base64,$encoded'),
        markup,
      );
      // No comma: not a data URI at all.
      expect(AppHelpers.inlineImagePayload('data:image/png;base64'), '');
      // Base64 that cannot decode returns empty rather than throwing.
      expect(AppHelpers.inlineImagePayload('data:image/png;base64,!!!'), '');
      expect(AppHelpers.inlineImagePayload(null), '');
    });

    test('returns bytes for a base64 raster payload', () {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final String uri = 'data:image/png;base64,${base64.encode(bytes)}';
      expect(AppHelpers.inlineImageBytes(uri), bytes);
      expect(AppHelpers.inlineImageBytes('https://example.test/a.png'), isNull);
      expect(AppHelpers.inlineImageBytes(null), isNull);
    });
  });

  group('DemoImages', () {
    test('every constant is inline SVG markup', () {
      final Map<String, String> all = <String, String>{
        'shopCover': DemoImages.shopCover,
        'shopMark': DemoImages.shopMark,
        'product': DemoImages.product,
        'category': DemoImages.category,
        'promoBanner': DemoImages.promoBanner,
        'avatar': DemoImages.avatar,
      };
      all.forEach((String name, String uri) {
        expect(AppHelpers.isInlineSvg(uri), isTrue, reason: name);
        final String markup = AppHelpers.inlineImagePayload(uri);
        expect(markup, startsWith('<svg '), reason: name);
        expect(markup, endsWith('</svg>'), reason: name);
        // The only URL in the markup is the SVG namespace (never fetched).
        // Anything else would mean the "inline" image still needed the
        // network, which would defeat the point.
        expect(markup.contains('xmlns="http://www.w3.org/2000/svg"'), isTrue,
            reason: name);
        expect(
          RegExp(r'(href|xlink:href|url\(https?)').hasMatch(markup),
          isFalse,
          reason: name,
        );
      });
    });

    test('the constants are visually distinct from one another', () {
      final Set<String> unique = <String>{
        DemoImages.shopCover,
        DemoImages.shopMark,
        DemoImages.product,
        DemoImages.category,
        DemoImages.promoBanner,
        DemoImages.avatar,
      };
      expect(unique.length, 6);
    });
  });

  group('CustomNetworkImage', () {
    testWidgets('does not build a network image for an inline URL',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomNetworkImage(
            url: DemoImages.shopCover,
            radius: 8,
            width: 120,
            height: 80,
          ),
        ),
      ));
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('renders the inline SVG itself', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomNetworkImage(
            url: DemoImages.shopMark,
            radius: 8,
            width: 120,
            height: 120,
          ),
        ),
      ));
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
