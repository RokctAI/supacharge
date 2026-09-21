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
import 'package:auto_route/auto_route.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:merchants_sdk/src/driver/application/story/story_provider.dart';
import 'package:base_sdk/src/presentation/components/helper/shimmer.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

// Moved verbatim from paas_driver lib/presentation/pages/stores/story_page.dart
// (driver migration S-D6; merchants_sdk is the driver story home per
// driver.json's merchants_sdk comment — base_sdk owns the story models).
// Deltas from the pure move, all import retargeting:
// - storyProvider now lives in merchants_sdk's src/driver story slice.
// - Style -> base_sdk AppStyle: primaryColor -> primary (a non-const getter,
//   so the two progress-bar consts below became non-const), greyColor ->
//   bgGrey (same 0xFFF4F5F8), black -> blackColor (legacy Style.black was
//   pure #000000; base's AppStyle.black is charcoal 0xFF232B2F).
// - interNormal sizes pass raw numbers (base's interNormal applies .sp
//   itself; the legacy host one took an already-scaled fontSize).
// - TrKeys.deliverymanbottomslide1..3 ride this manifest's tr_keys block.
// - Dropped two dead legacy fossils: a commented-out `late StoryNotifier
//   event;` field and an empty didChangeDependencies override that only
//   carried its commented-out read.
@RoutePage()
class StoryPage extends ConsumerStatefulWidget {
  const StoryPage({super.key});

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  final pageController = PageController(initialPage: 0);
  int currentIndex = 0;

  final List<String> image = [
    "https://s3.juvo.app/public/images/intro/driver/1.jpg",
    "https://s3.juvo.app/public/images/intro/driver/2.jpg",
    "https://s3.juvo.app/public/images/intro/driver/3.jpg",
  ];

  final List<Map<String, dynamic>> titles = [
    {
      'text': AppHelpers.getTranslation(TrKeys.deliverymanbottomslide1),
      'style': AppStyle.interNormal(
        size: 32,
        letterSpacing: -0.3,
        color: AppStyle.white,
      ),
    },
    {
      'text': AppHelpers.getTranslation(TrKeys.deliverymanbottomslide2),
      'style': AppStyle.interNormal(
        size: 32,
        letterSpacing: -0.3,
        color: AppStyle.white,
      ),
    },
    {
      'text': AppHelpers.getTranslation(TrKeys.deliverymanbottomslide3),
      'style': AppStyle.interNormal(
        size: 32,
        letterSpacing: -0.3,
        color: AppStyle.white,
      ),
    },
  ];

  @override
  void initState() {
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addListener(() {
            setState(() {});
            if (controller.value > 0.99) {
              if (ref.watch(storyProvider).currentIndex == 2) {
                context.router.maybePop();
              }
              pageController.nextPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn,
              );
            }
          });
    controller.repeat();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyProvider);
    final event = ref.read(storyProvider.notifier);
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            physics: const ClampingScrollPhysics(),
            controller: pageController,
            onPageChanged: (s) {
              event.changeIndex(s);
              controller.reset();
              controller.repeat();
            },
            children: [
              ...image.map(
                (e) => Stack(
                  children: [
                    Container(
                      width: MediaQuery.sizeOf(context).width,
                      height: MediaQuery.sizeOf(context).height,
                      foregroundDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppStyle.primary.withOpacity(0.26),
                            AppStyle.primary.withOpacity(0),
                            AppStyle.primary.withOpacity(0),
                            AppStyle.primary.withOpacity(0.26),
                          ],
                        ),
                      ),
                      child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        height: MediaQuery.sizeOf(context).height,
                        foregroundDecoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppStyle.blackColor.withOpacity(0.4),
                              AppStyle.blackColor.withOpacity(0.4),
                            ],
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: e,
                          width: MediaQuery.sizeOf(context).width,
                          height: MediaQuery.sizeOf(context).height,
                          fit: BoxFit.cover,
                          progressIndicatorBuilder: (context, url, progress) {
                            return const ImageShimmer(isCircle: false, size: 0);
                          },
                          errorWidget: (context, url, error) {
                            return Container(
                              decoration: BoxDecoration(
                                color: AppStyle.bgGrey,
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Remix.image_line,
                                color: AppStyle.blackColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Column(
                          children: [
                            const Spacer(),
                            Text(
                              titles[image.indexOf(e)]['text'],
                              style: titles[image.indexOf(e)]['style'],
                            ),
                            24.verticalSpace,
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            pageController.previousPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeIn,
                            );
                          },
                          child: Container(
                            height: MediaQuery.sizeOf(context).height,
                            width: MediaQuery.sizeOf(context).width / 2,
                            color: AppStyle.transparent,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeIn,
                            );
                          },
                          child: Container(
                            height: MediaQuery.sizeOf(context).height,
                            width: MediaQuery.sizeOf(context).width / 2,
                            color: AppStyle.transparent,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 16.w,
                      top: 48.h,
                      child: GestureDetector(
                        onTap: () {
                          context.router.maybePop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Remix.close_fill,
                            color: AppStyle.white,
                            size: 30.r,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                height: 4.h,
                width: MediaQuery.sizeOf(context).width,
                margin: EdgeInsets.only(left: 20.w, bottom: 10.h),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return AnimatedContainer(
                      margin: EdgeInsets.only(right: 8.w),
                      height: 4.h,
                      width: (MediaQuery.sizeOf(context).width - 60.w) / 3,
                      decoration: BoxDecoration(
                        color: state.currentIndex >= index
                            ? AppStyle.primary
                            : AppStyle.white,
                        borderRadius: BorderRadius.circular(122.r),
                      ),
                      duration: const Duration(milliseconds: 500),
                      child: state.currentIndex == index
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(122.r),
                              // Non-const: AppStyle.primary is a runtime
                              // getter (brand-hook overridable), unlike the
                              // legacy const Style.primaryColor.
                              child: LinearProgressIndicator(
                                value: controller.value,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppStyle.primary,
                                ),
                                backgroundColor: AppStyle.white,
                              ),
                            )
                          : state.currentIndex > index
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(122.r),
                              child: LinearProgressIndicator(
                                value: 1,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppStyle.primary,
                                ),
                                backgroundColor: AppStyle.white,
                              ),
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
