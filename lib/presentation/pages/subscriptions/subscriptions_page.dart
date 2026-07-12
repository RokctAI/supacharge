// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: subscriptions_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:subscriptions_sdk/src/application/subscriptions/subscriptions_provider.dart';
import 'package:base_sdk/base_sdk.dart';
import 'package:subscriptions_sdk/src/infrastructure/services/shop_subscription_store.dart';
import 'package:base_sdk/src/presentation/components/helper/no_data_info.dart';
import 'package:base_sdk/src/presentation/components/loading/loading_grid.dart';
import 'package:base_sdk/src/presentation/components/app_bars/common_app_bar.dart';
import 'widgets/have_subscription.dart';
import 'package:supacharge/core/presentation/theme/theme.dart';
import 'widgets/payment_dialog.dart';
import 'widgets/subscriptions_item.dart';

@RoutePage(name: 'ManagerSubscriptionsRoute')
class ManagerSubscriptionsPage extends ConsumerStatefulWidget {
  const ManagerSubscriptionsPage({super.key});

  @override
  ConsumerState<ManagerSubscriptionsPage> createState() =>
      _SubscriptionsPageState();
}

class _SubscriptionsPageState extends ConsumerState<ManagerSubscriptionsPage> {
  late RefreshController refreshController;

  @override
  void initState() {
    super.initState();
    refreshController = RefreshController();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(subscriptionProvider.notifier)
          .fetchSubscriptions(isRefresh: true),
    );
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLrt = LocalStorage.getLangLtr();
    return Directionality(
      textDirection: isLrt ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(subscriptionProvider);
            final notifier = ref.read(subscriptionProvider.notifier);
            int height =
                state.list.length < 5 &&
                    ShopSubscriptionStore.shopSubscription() == null
                ? 0
                : 80;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommonAppBar(
                  height: 102,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.maybePop(),
                        icon: Icon(FlutterRemix.arrow_left_s_line),
                      ),
                      Text(
                        AppHelpers.getTranslation(TrKeys.subscriptions),
                        style: AppStyle.interNormal(size: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SmartRefresher(
                    controller: refreshController,
                    onRefresh: () => notifier.fetchSubscriptions(
                      context: context,
                      controller: refreshController,
                      isRefresh: true,
                    ),
                    child: state.isLoading
                        ? LoadingGrid(
                            verticalPadding: 12,
                            itemBorderRadius: 12,
                            horizontalPadding: 12,
                            itemHeight:
                                ((MediaQuery.sizeOf(context).height - 240.h) ~/
                                    2) -
                                height,
                          )
                        : SingleChildScrollView(
                            padding: REdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                if (ShopSubscriptionStore.shopSubscription() !=
                                    null)
                                  const HaveSubscription(),
                                state.list.isEmpty
                                    ? NoDataInfo(
                                        title: AppHelpers.getTranslation(
                                          TrKeys.noData,
                                        ),
                                      )
                                    : GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: state.list.length,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisSpacing: 8.r,
                                              mainAxisSpacing: 4.r,
                                              crossAxisCount: 2,
                                              mainAxisExtent:
                                                  ((MediaQuery.sizeOf(
                                                            context,
                                                          ).height -
                                                          148.h) /
                                                      2) -
                                                  height,
                                            ),
                                        padding: REdgeInsets.all(12),
                                        itemBuilder: (context, index) =>
                                            SubscriptionsItem(
                                              subscription: state.list[index],
                                              purchase: () {
                                                if (ShopSubscriptionStore.shopSubscription()
                                                        ?.subscription ==
                                                    null) {
                                                  notifier.fetchPayments(
                                                    context: context,
                                                  );
                                                  notifier.selectSubscribe(
                                                    index: index,
                                                  );
                                                  AppHelpers.showAlertDialog(
                                                    context: context,
                                                    child:
                                                        const PaymentDialog(),
                                                  );
                                                } else {
                                                  AppHelpers.errorSnackBar(
                                                    context,
                                                    text: AppHelpers.getTranslation(
                                                      TrKeys
                                                          .youHaveSubscription,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                      ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


