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


import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:base_sdk/base_sdk.dart';
import 'package:subscriptions_sdk/subscriptions_sdk.dart';
import 'package:base_sdk/src/presentation/components/buttons/animation_button_effect2.dart';
import 'package:${package}/presentation/theme/theme.dart';

/// The PLAN CARD (approved section 40, chip 761): one tenant catalog row as
/// a plane-aligned card — title, big price + billing cycle, the INCLUDES
/// list ON the card face (chip 763, which retires the old "?" info dialog),
/// and the CTA row. Every fact on the card comes from the row itself
/// (`api.subscription.list_subscriptions` over the tenant `Subscription`
/// catalog) — nothing, least of all a price, is hardcoded here.
///
/// CTA states:
///  * default — the Purchase CTA (chip 764, primary fill + arrow);
///  * the shop already holds this plan — the CURRENT-PLAN GUARD (chip 768):
///    a disabled "Current plan" state instead of a tappable verb, so the
///    charge can never start from an accidental tap (the shipped after-tap
///    `youHaveSubscription` snackbar, moved before the tap);
///  * [selected] while the payment pane is up (chip 769) — primary border +
///    "Selected" tag; the Purchase verb and the trial badge drop away
///    because both now live in the pane (one verb, one badge at a time).
class SubscriptionsItem extends StatelessWidget {
  final SubscriptionData subscription;

  /// Chip 768: this row is the plan the shop already holds.
  final bool isCurrent;

  /// Chip 769: this row is the plan the open payment pane is charging for.
  final bool isSelected;

  /// Opens the purchase flow. Ignored while [isCurrent] or [isSelected] —
  /// the guard renders no tappable verb at all.
  final VoidCallback purchase;

  const SubscriptionsItem({
    super.key,
    required this.subscription,
    required this.purchase,
    this.isCurrent = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final includes = PlanCardLogic.includesFor(
      subscription,
      translate: AppHelpers.getTranslation,
    );
    final cycle = PlanCardLogic.cycleLabel(
      subscription,
      translate: AppHelpers.getTranslation,
    );
    final trial = PlanCardLogic.trialLabel(
      subscription,
      translate: AppHelpers.getTranslation,
    );
    final title = subscription.title ??
        subscription.content ??
        (subscription.type == null
            ? ''
            : AppHelpers.getTranslation(subscription.type!));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: AppStyle.cardDark,
        border: isSelected
            ? Border.all(color: AppStyle.primary, width: 1.5)
            : null,
      ),
      padding: REdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppStyle.interSemi(size: 18),
                ),
              ),
              if (isSelected)
                _TagPill(
                  label: AppHelpers.getTranslation('selected'),
                  color: AppStyle.primary,
                )
              // The trial badge (chip 762) yields to the Selected tag while
              // the payment pane is up — the trial fact moved into the pane.
              else if (trial != null)
                _TagPill(label: trial, color: AppStyle.green),
            ],
          ),
          14.verticalSpace,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                AppHelpers.numberFormat(number: subscription.price),
                style: AppStyle.interBold(size: 28),
              ),
              if (cycle != null) ...[
                8.horizontalSpace,
                Text(
                  cycle,
                  style: AppStyle.interRegular(
                    size: 14,
                    color: AppStyle.textDarkSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (includes.isNotEmpty) ...[
            16.verticalSpace,
            Container(height: 1, color: AppStyle.strokeDarkSubtle),
            16.verticalSpace,
            // Chip 763: the includes ON the card face. The shipped
            // "?"-CircleButton info dialog is deliberately retired — with
            // the same facts on the card, a second popup carried nothing.
            for (final line in includes)
              Padding(
                padding: REdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: REdgeInsets.only(top: 2),
                      child: Icon(
                        Remix.check_line,
                        size: 16.r,
                        color: AppStyle.green,
                      ),
                    ),
                    10.horizontalSpace,
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6.r,
                        children: [
                          Text(
                            line.text,
                            style: AppStyle.interRegular(
                              size: 14,
                              color: AppStyle.textDarkSecondary,
                            ),
                          ),
                          if (line.badge != null)
                            Container(
                              padding: REdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppStyle.primary,
                                borderRadius: BorderRadius.circular(100.r),
                              ),
                              child: Text(
                                line.badge!.toUpperCase(),
                                style: AppStyle.interBold(
                                  size: 9,
                                  color: AppStyle.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          // While this card is the pane's selected plan the verb lives in
          // the pane — the card carries no CTA at all (chip 769).
          if (!isSelected) ...[
            10.verticalSpace,
            if (isCurrent)
              // Chip 768 — the CURRENT-PLAN GUARD: disabled, not tappable.
              Container(
                width: double.infinity,
                padding: REdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100.r),
                  border: Border.all(color: AppStyle.strokeDark),
                ),
                child: Text(
                  AppHelpers.getTranslation('current.plan'),
                  textAlign: TextAlign.center,
                  style: AppStyle.interNoSemi(
                    size: 15,
                    color: AppStyle.textDarkFaint,
                  ),
                ),
              )
            else
              // Chip 764 — the Purchase CTA.
              ButtonEffectAnimation(
                onTap: purchase,
                child: Container(
                  width: double.infinity,
                  padding: REdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100.r),
                    color: AppStyle.primary,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppHelpers.getTranslation(TrKeys.purchase),
                        style: AppStyle.interNoSemi(
                          size: 15,
                          color: AppStyle.white,
                        ),
                      ),
                      8.horizontalSpace,
                      Icon(
                        Remix.arrow_right_line,
                        size: 18.r,
                        color: AppStyle.white,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Small outline tag pill — the trial badge (chip 762) and the Selected tag
/// (chip 769) share the shape and differ only in colour.
class _TagPill extends StatelessWidget {
  final String label;
  final Color color;

  const _TagPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: REdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: color),
        color: color.withOpacity(0.08),
      ),
      child: Text(
        label,
        style: AppStyle.interNoSemi(size: 12.5, color: color),
      ),
    );
  }
}
