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

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/presentation/components/blur_wrap.dart';
import 'package:base_sdk/src/presentation/components/helper/common_image.dart';
import 'package:base_sdk/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

class HorizontalImagePicker extends StatelessWidget {
  final String? imageFilePath;
  final String? imageUrl;
  final Function(String) onImageChange;
  final Function() onDelete;
  final bool isAdding;

  const HorizontalImagePicker({
    super.key,
    required this.onImageChange,
    required this.onDelete,
    this.imageFilePath,
    this.imageUrl,
    this.isAdding = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150.h,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: (isAdding && imageFilePath == null)
          ? InkWell(
              onTap: () async {
                XFile? file;
                try {
                  file = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                } catch (ex) {
                  debugPrint('===> trying to select image $ex');
                }
                if (file != null) {
                  onImageChange(file.path);
                }
              },
              child: Container(
                width: double.infinity,
                height: 180.h,
                decoration: BoxDecoration(
                  color: AppStyle.white,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: REdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        XFile? file;
                        try {
                          file = await ImagePicker()
                              .pickImage(source: ImageSource.gallery);
                        } catch (ex) {
                          debugPrint('===> trying to select image $ex');
                        }
                        if (file != null) {
                          onImageChange(file.path);
                        }
                      },
                      child: Icon(
                        Remix.upload_cloud_2_line,
                        color: AppStyle.primary,
                        size: 36.r,
                      ),
                    ),
                    16.verticalSpace,
                    Text(
                      AppHelpers.getTranslation(TrKeys.productPicture),
                      style: AppStyle.interSemi(
                        size: 14,
                        color: AppStyle.blackColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      AppHelpers.getTranslation(TrKeys.recommendedSize),
                      style: AppStyle.interRegular(
                        size: 14,
                        color: AppStyle.blackColor,
                        letterSpacing: -0.3,
                      ),
                    )
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                SizedBox(
                  height: 180.h,
                  width: double.infinity,
                  child: imageFilePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16.r),
                          child: Image.file(
                            File(imageFilePath!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CommonImage(
                          url: imageUrl,
                          width: double.infinity,
                          radius: 16,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  top: 12.h,
                  right: 16.w,
                  child: Row(
                    children: [
                      AnimationButtonEffect(
                        child: GestureDetector(
                          onTap: () async {
                            XFile? file;
                            try {
                              file = await ImagePicker()
                                  .pickImage(source: ImageSource.gallery);
                            } catch (ex) {
                              debugPrint('===> trying to select image $ex');
                            }
                            if (file != null) {
                              onImageChange(file.path);
                            }
                          },
                          child: BlurWrap(
                            radius: BorderRadius.circular(18.r),
                            child: Container(
                              height: 36.r,
                              width: 36.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppStyle.white.withOpacity(0.15),
                              ),
                              child: Icon(
                                Remix.image_add_fill,
                                color: (!isAdding &&
                                        imageUrl == null &&
                                        imageFilePath == null)
                                    ? AppStyle.blackColor
                                    : AppStyle.white,
                                size: 18.r,
                              ),
                            ),
                          ),
                        ),
                      ),
                      10.horizontalSpace,
                      if (imageFilePath != null)
                        AnimationButtonEffect(
                          child: GestureDetector(
                            onTap: onDelete,
                            child: BlurWrap(
                              radius: BorderRadius.circular(20.r),
                              child: Container(
                                height: 36.r,
                                width: 36.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppStyle.white.withOpacity(0.15),
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
