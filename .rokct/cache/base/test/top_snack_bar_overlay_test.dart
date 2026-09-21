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


// The top-snackbar helpers are decoration: handed a context with no Overlay
// ancestor they must do nothing, not throw. `Overlay.of` asserts in that case,
// and an asserting toast takes its caller down with it — which is how a single
// unreachable overlay killed a whole guided-tour run at its sign-in step.

import 'package:base_sdk/base_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

void main() {
  group('top snackbar helpers without an Overlay ancestor', () {
    late BuildContext overlayless;

    Future<void> pumpOverlayless(WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            overlayless = context;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    testWidgets('showCheckTopSnackBar is a no-op', (tester) async {
      await pumpOverlayless(tester);
      AppHelpers.showCheckTopSnackBar(overlayless, 'boom');
      await tester.pump();
    });

    testWidgets('showCheckTopSnackBarInfo is a no-op', (tester) async {
      await pumpOverlayless(tester);
      AppHelpers.showCheckTopSnackBarInfo(overlayless, 'boom');
      await tester.pump();
    });

    testWidgets('showCheckTopSnackBarDone is a no-op', (tester) async {
      await pumpOverlayless(tester);
      AppHelpers.showCheckTopSnackBarDone(overlayless, 'boom');
      await tester.pump();
    });

    testWidgets('showCheckTopSnackBarInfoCustom is a no-op', (tester) async {
      await pumpOverlayless(tester);
      AppHelpers.showCheckTopSnackBarInfoCustom(overlayless, 'boom');
      await tester.pump();
    });

    testWidgets('errorSnackBar alias is a no-op', (tester) async {
      await pumpOverlayless(tester);
      AppHelpers.errorSnackBar(overlayless, text: 'boom');
      await tester.pump();
    });
  });

  testWidgets('a toast still shows when an Overlay IS in scope', (
    tester,
  ) async {
    late BuildContext withOverlay;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            withOverlay = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    AppHelpers.showCheckTopSnackBarDone(withOverlay, 'saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CustomSnackBar), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
