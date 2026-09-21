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
import 'package:subscriptions_sdk/src/common/infrastructure/services/shop_subscription_store.dart';
import 'package:base_sdk/src/services/date_service.dart';
import 'package:${package}/presentation/theme/theme.dart';

/// The CURRENT-PLAN card (approved section 40, chip 760): the shop's held
/// subscription as a full-width info card in the settled dark plane
/// language — crown avatar, "Current plan" + Active badge, plan name,
/// price, and the row's `expired_at` as the "renews" date. [compact]
/// (phone / one-plane fold) tucks the renews line under the plan name.
///
/// Every value comes from the stored Shop Subscription row
/// ([ShopSubscriptionStore.shopSubscription]); fields the row does not
/// carry simply do not render.
class HaveSubscription extends StatelessWidget {
  /// One-plane form (frames 40b/40c): the renews line moves under the name.
  final bool compact;

  const HaveSubscription({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final held = ShopSubscriptionStore.shopSubscription();
    if (held == null) return const SizedBox.shrink();
    final plan = held.subscription;
    final name = plan?.title ??
        plan?.content ??
        held.title ??
        held.content ??
        held.subscriptionRef ??
        (held.type == null ? '' : AppHelpers.getTranslation(held.type!));
    final num? price = held.price ?? plan?.price;
    final renews = held.expiredAt == null
        ? null
        : '${AppHelpers.getTranslation('renews').toLowerCase()} '
            '${DateService.dateFormatDMY(held.expiredAt)}';
    final bool active = held.active ?? false;

    final renewsText = renews == null
        ? null
        : Text(
            renews,
            style: AppStyle.interRegular(
              size: 13,
              color: AppStyle.textDarkSecondary,
            ),
          );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: AppStyle.cardDark,
      ),
      padding: REdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppStyle.primary.withOpacity(0.15),
            ),
            child: Icon(Remix.vip_crown_line, size: 24.r, color: AppStyle.primary),
          ),
          14.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        AppHelpers.getTranslation('current.plan'),
                        style: AppStyle.interRegular(
                          size: 13,
                          color: AppStyle.textDarkSecondary,
                        ),
                      ),
                    ),
                    if (active) ...[
                      8.horizontalSpace,
                      Container(
                        padding: REdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100.r),
                          border: Border.all(color: AppStyle.green),
                          color: AppStyle.green.withOpacity(0.08),
                        ),
                        child: Text(
                          AppHelpers.getTranslation(TrKeys.active),
                          style: AppStyle.interNoSemi(
                            size: 11.5,
                            color: AppStyle.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                4.verticalSpace,
                Text(name, style: AppStyle.interSemi(size: 18)),
                if (compact && renewsText != null) ...[
                  4.verticalSpace,
                  renewsText,
                ],
              ],
            ),
          ),
          12.horizontalSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (price != null)
                Text(
                  AppHelpers.numberFormat(number: price),
                  style: AppStyle.interSemi(size: 20),
                ),
              if (!compact && renewsText != null) ...[
                4.verticalSpace,
                renewsText,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
