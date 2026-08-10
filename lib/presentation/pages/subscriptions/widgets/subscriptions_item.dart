// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: subscriptions_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:base_sdk/base_sdk.dart';
import 'package:subscriptions_sdk/subscriptions_sdk.dart';
import 'package:base_sdk/src/presentation/components/buttons/second_button.dart';
import 'package:base_sdk/src/presentation/components/buttons/circle_button.dart';
import 'package:supacharge/core/presentation/theme/theme.dart';

class SubscriptionsItem extends StatelessWidget {
  final SubscriptionData subscription;
  final VoidCallback purchase;

  const SubscriptionsItem({
    super.key,
    required this.subscription,
    required this.purchase,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            color: AppStyle.white,
          ),
          padding: REdgeInsets.symmetric(vertical: 32),
          margin: REdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                subscription.title ?? "",
                style: AppStyle.interNormal(size: 14),
              ),
              Text(
                AppHelpers.numberFormat(number: subscription.price),
                style: AppStyle.interSemi(size: 18),
              ),
              12.verticalSpace,
              Text(
                "${subscription.month ?? 0} ${TrKeys.month}",
                style: AppStyle.interNormal(size: 14),
              ),
              Text(
                "${AppHelpers.getTranslation(TrKeys.product)}: ${subscription.productLimit ?? 0}",
                style: AppStyle.interNormal(size: 14),
              ),
              Text(
                "${AppHelpers.getTranslation(TrKeys.order)}: ${subscription.orderLimit ?? 0}",
                style: AppStyle.interNormal(size: 14),
              ),
              if (subscription.withReport ?? false)
                Text(
                  "+ ${AppHelpers.getTranslation(TrKeys.withReport)}",
                  style: AppStyle.interRegular(size: 12, color: AppStyle.green),
                ),
              16.verticalSpace,
              SecondButton(
                title: AppHelpers.getTranslation(TrKeys.purchase),
                bgColor: AppStyle.primary,
                titleColor: AppStyle.white,
                onTap: purchase,
              ),
            ],
          ),
        ),
        Positioned(
          right: 8.r,
          top: 8.r,
          child: CircleButton(
            size: 30,
            iconSize: 16,
            icon: Remix.question_mark,
            onTap: () {
              AppHelpers.openDialog(
                context: context,
                title:
                    "${AppHelpers.getTranslation(TrKeys.subscriptionIncludes)}, "
                    "\n${AppHelpers.getTranslation(TrKeys.productCount)}: ${subscription.productLimit ?? 0}, "
                    "\n${AppHelpers.getTranslation(TrKeys.orderCount)}: ${subscription.orderLimit ?? 0}, "
                    "\n${AppHelpers.getTranslation(TrKeys.duration)}: ${subscription.month} ${AppHelpers.getTranslation(TrKeys.month)}",
              );
            },
          ),
        ),
      ],
    );
  }
}
