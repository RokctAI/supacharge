// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: fav_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:core_sdk/src/presentation/pages/home/widgets/banner_item.dart';
import 'package:supacharge/core/presentation/theme/color_set.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:order_sdk/order_sdk.dart';

import 'package:fav_sdk/fav_sdk.dart';
import 'package:core_sdk/core_sdk.dart';
import 'package:core_sdk/src/presentation/pages/home/home_three/shimmer/banner_shimmer.dart';
import 'package:supacharge/core/presentation/theme/theme.dart';
import 'package:core_sdk/src/application/main/main_provider.dart';
import 'package:core_sdk/src/presentation/pages/home/home_one/widget/market_one_item.dart';
import 'package:core_sdk/src/presentation/pages/home/home_three/widgets/market_three_item.dart';
import 'package:core_sdk/src/presentation/pages/home/home_two/widget/market_two_item.dart';
import 'package:core_sdk/src/presentation/pages/home/shimmer/all_shop_shimmer.dart';

import 'package:core_sdk/src/presentation/components/components.dart';

@RoutePage()
class LikePage extends ConsumerStatefulWidget {
  final bool isBackButton;

  const LikePage({super.key, this.isBackButton = true});

  @override
  ConsumerState<LikePage> createState() => _LikePageState();
}

class _LikePageState extends ConsumerState<LikePage> {
  late FavoritesNotifier event;
  final RefreshController _bannerController = RefreshController();
  final RefreshController _likeShopController = RefreshController();
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shopFavoritesProvider.notifier).fetchLikeShop(context);
    });
    _controller.addListener(listen);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    event = ref.read(shopFavoritesProvider.notifier);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _likeShopController.dispose();
    _controller.removeListener(listen);
    super.dispose();
  }

  void listen() {
    final direction = _controller.position.userScrollDirection;
    if (direction == ScrollDirection.reverse) {
      ref.read(mainProvider.notifier).changeScrolling(true);
    } else if (direction == ScrollDirection.forward) {
      ref.read(mainProvider.notifier).changeScrolling(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopFavoritesProvider);
    return CustomScaffold(
      body: (colors) => Column(
        children: [
          CommonAppBar(
            child: Text(
              AppHelpers.getTranslation(TrKeys.likeRestaurants),
              style: AppStyle.interNoSemi(size: 18, color: colors.textBlack),
            ),
          ),
          Expanded(
            child: SmartRefresher(
              enablePullDown: true,
              enablePullUp: false,
              physics: const BouncingScrollPhysics(),
              controller: _likeShopController,
              scrollController: _controller,
              onLoading: () {},
              onRefresh: () {
                ref.read(shopFavoritesProvider.notifier).build();
                ref
                    .read(homeProvider.notifier)
                    .fetchBannerPage(
                      context,
                      _likeShopController,
                      isRefresh: true,
                    );
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 24.h,
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  children: [
                    ref.watch(homeProvider).isBannerLoading
                        ? const BannerShimmer()
                        : SizedBox(
                            height: 200.h,
                            child: SmartRefresher(
                              scrollDirection: Axis.horizontal,
                              enablePullDown: false,
                              enablePullUp: true,
                              controller: _bannerController,
                              onLoading: () async {
                                await ref
                                    .read(homeProvider.notifier)
                                    .fetchBannerPage(
                                      context,
                                      _bannerController,
                                    );
                              },
                              child: ListView.builder(
                                shrinkWrap: false,
                                scrollDirection: Axis.horizontal,
                                itemCount: ref
                                    .watch(homeProvider)
                                    .banners
                                    .length,
                                padding: EdgeInsets.only(left: 16.w),
                                itemBuilder: (context, index) => BannerItem(
                                  banner: ref
                                      .watch(homeProvider)
                                      .banners[index],
                                ),
                              ),
                            ),
                          ),
                    24.verticalSpace,
                    state.isShopLoading
                        ? const AllShopShimmer(isTitle: false)
                        : state.shops.isEmpty
                        ? _resultEmpty(colors)
                        : ListView.builder(
                            padding: AppHelpers.getType() == 2
                                ? EdgeInsets.symmetric(horizontal: 16.r)
                                : EdgeInsets.only(top: 6.h),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.vertical,
                            itemCount: state.shops.length,
                            itemBuilder: (context, index) =>
                                AppHelpers.getType() == 0
                                ? MarketItem(
                                    shop: state.shops[index],
                                    isSimpleShop: true,
                                  )
                                : AppHelpers.getType() == 1
                                ? MarketOneItem(
                                    shop: state.shops[index],
                                    isSimpleShop: true,
                                  )
                                : AppHelpers.getType() == 2
                                ? MarketTwoItem(
                                    shop: state.shops[index],
                                    isSimpleShop: true,
                                  )
                                : MarketThreeItem(
                                    shop: state.shops[index],
                                    isSimpleShop: true,
                                  ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: (colors) => widget.isBackButton
          ? Padding(
              padding: EdgeInsets.only(left: 16.w),
              child: const PopButton(),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _resultEmpty(CustomColorSet colors) {
    return Column(
      children: [
        32.verticalSpace,
        Image.asset("assets/images/notFound.png"),
        Text(
          AppHelpers.getTranslation(TrKeys.nothingFound),
          style: AppStyle.interSemi(size: 18.sp, color: colors.textBlack),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Text(
            AppHelpers.getTranslation(TrKeys.trySearchingAgain),
            style: AppStyle.interRegular(size: 14.sp, color: colors.textBlack),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

