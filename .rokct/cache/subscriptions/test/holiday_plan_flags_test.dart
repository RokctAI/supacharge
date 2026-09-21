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


import 'package:flutter_test/flutter_test.dart';
import 'package:subscriptions_sdk/subscriptions_sdk.dart';

/// Holiday Programme plan flags (business doc §2, holiday brief item 2).
/// The three-way access model is PER-PLAN FLAGS, not a tier hierarchy — no
/// tier structure exists anywhere, so plans carry their own entitlements.
void main() {
  group('SubscriptionData holiday flags', () {
    test('parses all three access shapes plus the catch-up entitlement', () {
      final bundled = SubscriptionData.fromJson({
        'id': 1,
        'bundles_holiday': 1,
        'personalized_catch_up': 'true',
      });
      expect(bundled.bundlesHoliday, isTrue);
      expect(bundled.personalizedCatchUp, isTrue);
      expect(bundled.holidayStandalone, isNull);

      final addOn = SubscriptionData.fromJson({
        'id': 2,
        'bundles_holiday': 0,
        'holiday_add_on_price': '149',
      });
      expect(addOn.bundlesHoliday, isFalse);
      expect(addOn.holidayAddOnPrice, 149);

      final standalone = SubscriptionData.fromJson({
        'id': 3,
        'holiday_standalone': true,
      });
      expect(standalone.holidayStandalone, isTrue);
    });

    test('absent fields stay null — every pre-existing plan row unchanged',
        () {
      final legacy = SubscriptionData.fromJson({'id': 1, 'price': 299});
      expect(legacy.bundlesHoliday, isNull);
      expect(legacy.holidayAddOnPrice, isNull);
      expect(legacy.holidayStandalone, isNull);
      expect(legacy.personalizedCatchUp, isNull);
    });

    test('round-trips through toJson and survives copyWith', () {
      final plan = SubscriptionData(
        id: 1,
        bundlesHoliday: true,
        holidayAddOnPrice: 149,
        holidayStandalone: false,
        personalizedCatchUp: true,
      );
      final json = plan.toJson();
      expect(json['bundles_holiday'], isTrue);
      expect(json['holiday_add_on_price'], 149);
      expect(json['personalized_catch_up'], isTrue);

      final copied = plan.copyWith(price: 249);
      expect(copied.bundlesHoliday, isTrue);
      expect(copied.holidayAddOnPrice, 149);
      expect(copied.personalizedCatchUp, isTrue);
    });

    test('malformed add-on price resolves to null rather than throwing', () {
      final plan = SubscriptionData.fromJson(
          {'id': 1, 'holiday_add_on_price': 'not-a-number'});
      expect(plan.holidayAddOnPrice, isNull);
    });
  });
}
