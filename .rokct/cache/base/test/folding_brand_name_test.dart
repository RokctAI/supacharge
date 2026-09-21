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

// The splash wordmark's fold. A dotted name is on screen in full at the
// first frame; after the delay the dot and what follows slide into the
// stem - the suffix's clipped box closes to zero width while the stem's
// glyphs stay where they were laid out. A name without a dot is plain text
// that never changes. Ruled on the value ("if value of x has a dot, do
// this"), so the fixture is a made-up name.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/pages/initial/splash/folding_brand_name.dart';

const TextStyle _style = TextStyle(fontSize: 40, fontWeight: FontWeight.bold);

Widget _host(String name) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.centerLeft,
        child: FoldingBrandName(name: name, style: _style),
      ),
    ),
  );
}

void main() {
  testWidgets('a dotted name shows in full, then its suffix slides into the '
      'stem', (tester) async {
    await tester.pumpWidget(_host('acme.school'));

    // First frame: both halves are on screen, the suffix at full width,
    // sitting right after the stem.
    expect(find.text('acme'), findsOneWidget);
    expect(find.text('.school'), findsOneWidget);
    final Size suffixBox = tester.getSize(find.byKey(FoldingBrandName.suffixKey));
    final Size suffixText = tester.getSize(find.text('.school'));
    expect(suffixBox.width, suffixText.width);
    expect(suffixBox.width, greaterThan(0));
    final Offset stemBefore = tester.getTopLeft(find.text('acme'));
    final Offset fullRight = tester.getTopRight(find.text('.school'));

    // Still in full just before the delay elapses.
    await tester.pump(FoldingBrandName.defaultFoldDelay -
        const Duration(milliseconds: 1));
    expect(tester.getSize(find.byKey(FoldingBrandName.suffixKey)).width,
        suffixText.width);

    // Mid-fold: the box has narrowed, the suffix is pinned to the box's
    // trailing edge (so its glyphs have moved toward the stem), and the
    // stem has not moved.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    final double midWidth =
        tester.getSize(find.byKey(FoldingBrandName.suffixKey)).width;
    expect(midWidth, lessThan(suffixText.width));
    expect(midWidth, greaterThan(0));
    expect(tester.getTopRight(find.text('.school')).dx, lessThan(fullRight.dx));
    expect(tester.getTopLeft(find.text('acme')), stemBefore);

    // Settled: only the stem is visible - the suffix box is closed.
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(FoldingBrandName.suffixKey)).width, 0);
    expect(tester.getTopLeft(find.text('acme')), stemBefore);
    expect(find.text('acme'), findsOneWidget);
  });

  testWidgets('a name without a dot is plain text and never changes',
      (tester) async {
    await tester.pumpWidget(_host('acme'));
    expect(find.text('acme'), findsOneWidget);
    expect(find.byKey(FoldingBrandName.suffixKey), findsNothing);
    final Size before = tester.getSize(find.text('acme'));

    await tester.pump(FoldingBrandName.defaultFoldDelay * 2);
    await tester.pumpAndSettle();
    expect(find.text('acme'), findsOneWidget);
    expect(find.byKey(FoldingBrandName.suffixKey), findsNothing);
    expect(tester.getSize(find.text('acme')), before);
  });

  testWidgets('with animations disabled the suffix goes in one step after '
      'the delay', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: FoldingBrandName(name: 'acme.school', style: _style),
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(FoldingBrandName.suffixKey)).width,
        greaterThan(0));
    await tester.pump(FoldingBrandName.defaultFoldDelay);
    await tester.pump();
    expect(tester.getSize(find.byKey(FoldingBrandName.suffixKey)).width, 0);
  });
}
