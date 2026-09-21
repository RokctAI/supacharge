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

// SYNC ISSUES in the standard list language (approved frame 38c, Ray
// 2026-08-30 12:23Z — "the box tabs are IN"):
//
//   * 710 — the box filter tabs are All + the three manager local-first
//     boxes, in that order; each filters to its own box and reports its
//     own count for its pill, and All shows everything (including a box
//     that has no tab of its own, so nothing can vanish from the list);
//   * the tab colours are the 33a set — Shop = base blue, Product = rate
//     yellow (light, so its pill text flips dark), Order = primary — and
//     a card wears its own box's colour, so card and tab always read as
//     the same thing;
//   * 708/709 — the card carries the box label, the record summary, the
//     server's rejection message, and the shipped Try again / Discard
//     pair.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:merchants_sdk/src/manager/infrastructure/services/sync_issues_service.dart';
import 'package:merchants_sdk/src/manager/presentation/sync_issues/sync_issue_boxes.dart';
import 'package:merchants_sdk/src/manager/presentation/sync_issues/sync_issue_card.dart';

SyncIssue _issue(String box, String localId, {String? error}) => SyncIssue(
  box: box,
  localId: localId,
  record: const {},
  error: error,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  final issues = <SyncIssue>[
    _issue('manager_shops', 'offline:s1'),
    _issue('manager_products', 'offline:p1'),
    _issue('manager_products', 'offline:p2'),
    _issue('manager_products', 'offline:p3'),
    _issue('manager_orders', 'offline:o1'),
  ];

  group('710 — the box filter tabs', () {
    test('are All + the three manager boxes, in that order', () {
      expect(SyncIssueBox.values.map((t) => t.box), [
        null,
        'manager_shops',
        'manager_products',
        'manager_orders',
      ]);
      // The tabbed boxes are exactly the service's own box list.
      expect(
        SyncIssueBox.values
            .map((t) => t.box)
            .whereType<String>()
            .toList(),
        SyncIssuesService.boxes,
      );
    });

    test('each tab filters to its box and counts it — All counts them all',
        () {
      expect(SyncIssueBox.all.countIn(issues), 5);
      expect(SyncIssueBox.shop.countIn(issues), 1);
      expect(SyncIssueBox.product.countIn(issues), 3);
      expect(SyncIssueBox.order.countIn(issues), 1);
      expect(
        SyncIssueBox.product.apply(issues).map((i) => i.localId),
        ['offline:p1', 'offline:p2', 'offline:p3'],
      );
    });

    test('a record from an untabbed box still shows under All', () {
      final withUnknown = [...issues, _issue('manager_widgets', 'offline:w1')];
      expect(SyncIssueBox.isTabbed('manager_widgets'), isFalse);
      expect(SyncIssueBox.all.countIn(withUnknown), 6);
      expect(SyncIssueBox.shop.countIn(withUnknown), 1);
    });

    test('colours are the 33a set and only the light one flips its pill '
        'text', () {
      expect(SyncIssueBox.shop.color, AppStyle.blue);
      expect(SyncIssueBox.product.color, AppStyle.rate);
      expect(SyncIssueBox.order.color, AppStyle.primary);
      expect(SyncIssueBox.product.darkPillText, isTrue);
      expect(SyncIssueBox.order.darkPillText, isFalse);
    });

    test('a card wears its own box colour', () {
      expect(syncIssueBoxColor('manager_products'), AppStyle.rate);
      expect(syncIssueBoxColor('manager_orders'), AppStyle.primary);
    });
  });

  group('708/709 — the sync-issue card', () {
    testWidgets('carries the box label, the summary, the rejection message '
        'and the shipped action pair', (tester) async {
      var retried = 0;
      var discarded = 0;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(841, 701),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: SyncIssueCard(
                issue: _issue(
                  'manager_products',
                  'offline:p1',
                  error: 'Price must be greater than zero',
                ),
                boxLabel: 'Product',
                retryLabel: 'Try again',
                discardLabel: 'Discard',
                onRetry: () => retried++,
                onDiscard: () => discarded++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Product'), findsOneWidget);
      expect(find.text('offline:p1'), findsOneWidget);
      expect(find.text('Price must be greater than zero'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Discard'));
      expect(retried, 1);
      expect(discarded, 1);
    });
  });
}
