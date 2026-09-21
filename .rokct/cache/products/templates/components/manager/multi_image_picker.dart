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

import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import 'package:base_sdk/src/presentation/components/blur_wrap.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tpying_delay.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_gallery.dart';
import 'package:base_sdk/src/presentation/components/helper/common_image.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';

/// Multi-image gallery picker for the create/edit product forms, typed on
/// `SellerGallery`. The app's `ButtonEffectAnimation(onTap:)` wrapper became
/// `GestureDetector` + `ButtonsBouncingEffect` — base_sdk's
/// `AnimationButtonEffect` carries no tap handler, and the bouncing wrapper is
/// the pattern every other converted manager page already uses.
class MultiImagePicker extends StatelessWidget {
  final List<String?>? listOfImages;
  final List<SellerGallery?>? imageUrls;
  final Function(String) onDelete;
  final Function(String) onImageChange;

  const MultiImagePicker({
    super.key,
    this.listOfImages,
    required this.onDelete,
    this.imageUrls,
    required this.onImageChange,
  });

  @override
  Widget build(BuildContext context) {
    return _editProductImage(context);
  }

  _editProductImage(BuildContext context) {
    int itemCount = (listOfImages?.length ?? 0) + (imageUrls?.length ?? 0);
    return Column(
      children: [
        (itemCount > 0) == false
            ? GestureDetector(
                onTap: () async {
                  Delayed(milliseconds: 300).run(() async {
                    XFile? file;
                    try {
                      file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                    } catch (ex) {
                      debugPrint('===> trying to select image $ex');
                    }
                    if (file != null) {
                      onImageChange.call(file.path);
                    }
                  });
                },
                child: ButtonsBouncingEffect(
                  child: Container(
                    width: double.infinity,
                    height: 180.r,
                    decoration: BoxDecoration(
                      color: AppStyle.white,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: REdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Remix.upload_cloud_2_line,
                          color: AppStyle.primary,
                          size: 36.r,
                        ),
                        16.verticalSpace,
                        Text(
                          AppHelpers.getTranslation(TrKeys.productPicture),
                          style: AppStyle.interSemi(
                            size: 14,
                            color: AppStyle.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          AppHelpers.getTranslation(TrKeys.recommendedSize),
                          style: AppStyle.interRegular(
                            size: 14,
                            color: AppStyle.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Stack(
                children: [
                  CommonImage(
                    fileImage:
                        ((imageUrls?.isEmpty ?? true) &&
                            (listOfImages?.isNotEmpty ?? false))
                        ? File(listOfImages?.first ?? "")
                        : null,
                    url: (imageUrls?.isNotEmpty ?? false)
                        ? imageUrls?.first?.path
                        : null,
                    height: MediaQuery.sizeOf(context).height / 5.5,
                    width: double.infinity,
                    radius: 16,
                    preview: imageUrls?.isNotEmpty ?? false
                        ? imageUrls?.first?.preview
                        : null,
                    fit: BoxFit.fitHeight,
                  ),
                  Positioned(
                    right: 16.r,
                    top: 16.r,
                    child: GestureDetector(
                      onTap: () => onDelete(
                        (imageUrls?.isNotEmpty ?? false)
                            ? imageUrls?.first?.path ?? ""
                            : listOfImages?.first ?? "",
                      ),
                      child: ButtonsBouncingEffect(
                        child: BlurWrap(
                          blur: 6,
                          radius: BorderRadius.circular(20.r),
                          child: Container(
                            height: 40.r,
                            width: 40.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppStyle.white.withOpacity(0.2),
                            ),
                            child: Icon(
                              Remix.delete_bin_fill,
                              color: AppStyle.white,
                              size: 18.r,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        if (itemCount > 0)
          GridView.builder(
            padding: REdgeInsets.only(top: 12),
            itemCount: itemCount,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              crossAxisSpacing: 8.r,
              mainAxisSpacing: 8.r,
              maxCrossAxisExtent: 100.r,
              childAspectRatio: 0.9,
            ),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              return itemCount == index + 1
                  ? _mediaPicker(context)
                  : Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: CommonImage(
                            fileImage: (imageUrls?.length ?? 0) > index + 1
                                ? null
                                : File(
                                    listOfImages?[index -
                                            (imageUrls?.length ?? 0) +
                                            1] ??
                                        "",
                                  ),
                            url: (imageUrls?.length ?? 0) > index + 1
                                ? imageUrls![index + 1]?.path
                                : null,
                            preview: (imageUrls?.length ?? 0) > index + 1
                                ? imageUrls![index + 1]?.preview
                                : null,
                            height: 80,
                            width: 70,
                            radius: 12,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if ((imageUrls?.length ?? 0) > index + 1
                            ? imageUrls![index + 1]?.preview == null
                            : true)
                          Positioned.fill(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  String path;
                                  try {
                                    path = imageUrls?[index + 1]?.path ?? "";
                                  } catch (e) {
                                    path =
                                        listOfImages?[(index -
                                                (imageUrls?.length ?? 0)) +
                                            1] ??
                                        "";
                                  }
                                  onDelete(path);
                                },
                                child: ButtonsBouncingEffect(
                                  child: Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                      color: AppStyle.white.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Remix.delete_bin_line,
                                      color: AppStyle.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
            },
          ),
      ],
    );
  }

  _mediaPicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        Delayed(milliseconds: 300).run(() async {
          XFile? file;
          try {
            file = await ImagePicker().pickImage(source: ImageSource.gallery);
          } catch (ex) {
            debugPrint('===> trying to select image $ex');
          }
          if (file != null) {
            onImageChange.call(file.path);
          }
        });
      },
      child: ButtonsBouncingEffect(
        child: DottedBorder(
          dashPattern: const [8],
          color: AppStyle.primary,
          strokeWidth: 2.6,
          borderType: BorderType.RRect,
          radius: const Radius.circular(10),
          child: Center(
            child: Icon(
              Remix.upload_cloud_2_line,
              color: AppStyle.primary,
              size: 28.r,
            ),
          ),
        ),
      ),
    );
  }
}
