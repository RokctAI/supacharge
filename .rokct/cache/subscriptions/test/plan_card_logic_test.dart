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

/// Approved section 40 (manager subscriptions): the pure decisions behind
/// the plan cards — the CURRENT-PLAN GUARD (chip 768, the before-tap
/// confirm guard that replaces the shipped after-tap error snackbar) and
/// the INCLUDES-on-the-card list (chip 763, which retires the "?" info
/// dialog) — plus the category slice and the derived cycle/trial labels.
void main() {
  String tr(String key) => key;

  group('current-plan guard (chip 768)', () {
    final plan = SubscriptionData(id: 3, ref: 'PLAN-A', title: 'Gold');

    test('no held subscription: nothing is guarded', () {
      expect(PlanCardLogic.isCurrentPlan(plan, null), isFalse);
    });

    test('matches the legacy nested plan object by id/ref/title', () {
      final byId = SubscriptionData(subscription: SubscriptionData(id: 3));
      final byRef =
          SubscriptionData(subscription: SubscriptionData(ref: 'PLAN-A'));
      final byTitle =
          SubscriptionData(subscription: SubscriptionData(title: 'Gold'));
      expect(PlanCardLogic.isCurrentPlan(plan, byId), isTrue);
      expect(PlanCardLogic.isCurrentPlan(plan, byRef), isTrue);
      expect(PlanCardLogic.isCurrentPlan(plan, byTitle), isTrue);
    });

    test('matches the composed-backend link string and legacy numeric id',
        () {
      // Frappe Shop Subscription rows carry the plan as a link STRING.
      final linkRow = SubscriptionData.fromJson({'subscription': 'PLAN-A'});
      expect(linkRow.subscriptionRef, 'PLAN-A');
      expect(PlanCardLogic.isCurrentPlan(plan, linkRow), isTrue);

      final idRow = SubscriptionData(subscriptionId: 3);
      expect(PlanCardLogic.isCurrentPlan(plan, idRow), isTrue);
    });

    test('a different held plan does not guard this card', () {
      final other = SubscriptionData(
        subscriptionId: 9,
        subscriptionRef: 'PLAN-B',
        subscription: SubscriptionData(id: 9, ref: 'PLAN-B', title: 'Silver'),
      );
      expect(PlanCardLogic.isCurrentPlan(plan, other), isFalse);
    });

    test('null fields never match null fields', () {
      // A held row with no identifying fields must not guard a plan that
      // also lacks them — null == null is not a match.
      final barePlan = SubscriptionData(price: 10);
      final bareHeld = SubscriptionData(subscription: SubscriptionData());
      expect(PlanCardLogic.isCurrentPlan(barePlan, bareHeld), isFalse);
    });
  });

  group('includes on the card face (chip 763)', () {
    test('features lines win when the row carries them', () {
      final plan = SubscriptionData.fromJson({
        'features': ['Line one', 'Line two'],
        'product_limit': 5,
      });
      expect(
        PlanCardLogic.includesFor(plan, translate: tr),
        const [PlanIncludeLine('Line one'), PlanIncludeLine('Line two')],
      );
    });

    test('embedded span markup becomes a mini-badge, other tags stripped',
        () {
      final line = PlanCardLogic.parseFeatureLine(
        'Delivery Platform <span class="text-[10px] bg-primary">White '
        'Label</span>',
      );
      expect(line.text, 'Delivery Platform');
      expect(line.badge, 'White Label');

      final noBadge = PlanCardLogic.parseFeatureLine('<b>Bold</b> claim');
      expect(noBadge.text, 'Bold claim');
      expect(noBadge.badge, isNull);
    });

    test('legacy limit fields fall back when no features are served', () {
      final plan = SubscriptionData(
        productLimit: 100,
        orderLimit: 500,
        withReport: true,
      );
      final lines = PlanCardLogic.includesFor(plan, translate: tr);
      expect(lines, hasLength(3));
      expect(lines[0].text, contains('100'));
      expect(lines[1].text, contains('500'));
    });

    test('a bare tenant catalog row yields no invented includes', () {
      final plan = SubscriptionData(price: 25, month: 1);
      expect(PlanCardLogic.includesFor(plan, translate: tr), isEmpty);
    });
  });

  group('category slice (tenant `type`, nextjs exact-equality semantics)',
      () {
    final list = [
      SubscriptionData(id: 1, type: 'orders'),
      SubscriptionData(id: 2, type: 'products'),
      SubscriptionData(id: 3),
    ];

    test('null/empty keeps the full catalog', () {
      expect(PlanCardLogic.filterByCategory(list, null), hasLength(3));
      expect(PlanCardLogic.filterByCategory(list, ''), hasLength(3));
    });

    test('exact match only — mirrors the backend filters equality', () {
      expect(
        PlanCardLogic.filterByCategory(list, 'orders').map((p) => p.id),
        [1],
      );
      // Not case-folded: the web/control filter is exact equality.
      expect(PlanCardLogic.filterByCategory(list, 'Orders'), isEmpty);
    });
  });

  group('derived labels', () {
    test('cycle from the real month field; absent month shows nothing', () {
      expect(
        PlanCardLogic.cycleLabel(SubscriptionData(month: 1), translate: tr),
        'per month',
      );
      expect(
        PlanCardLogic.cycleLabel(SubscriptionData(month: 12), translate: tr),
        'per year',
      );
      expect(
        PlanCardLogic.cycleLabel(SubscriptionData(month: 3), translate: tr),
        'per 3 months',
      );
      expect(
        PlanCardLogic.cycleLabel(SubscriptionData(), translate: tr),
        isNull,
      );
    });

    test('trial badge only for a positive trial_period_days', () {
      final withTrial = SubscriptionData.fromJson({'trial_period_days': 14});
      expect(withTrial.trialPeriodDays, 14);
      expect(
        PlanCardLogic.trialLabel(withTrial, translate: tr),
        '14-day.free.trial',
      );
      expect(
        PlanCardLogic.trialLabel(
          SubscriptionData.fromJson({'trial_period_days': 0}),
          translate: tr,
        ),
        isNull,
      );
      expect(
        PlanCardLogic.trialLabel(SubscriptionData(), translate: tr),
        isNull,
      );
    });
  });

  group('SubscriptionData new-field round trips', () {
    test('trial/features/link-string parse, survive copyWith and toJson',
        () {
      final plan = SubscriptionData.fromJson({
        'name': 'PLAN-A',
        'trial_period_days': '14',
        'features': ['A', 'B'],
      });
      expect(plan.ref, 'PLAN-A');
      expect(plan.trialPeriodDays, 14);
      expect(plan.features, ['A', 'B']);
      expect(plan.copyWith(price: 1).features, ['A', 'B']);
      expect(plan.toJson()['trial_period_days'], 14);
      expect(plan.toJson()['features'], ['A', 'B']);

      final held = SubscriptionData.fromJson({'subscription': 'PLAN-A'});
      expect(held.toJson()['subscription'], 'PLAN-A');
      expect(held.copyWith(price: 1).subscriptionRef, 'PLAN-A');
    });
  });
}
