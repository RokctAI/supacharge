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
import 'package:flutter/cupertino.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:base_sdk/src/presentation/components/custom_toggle3.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';
import 'package:${package}/presentation/components/restaurant/small_weekday_item.dart';
import 'package:base_sdk/src/models/data/shop_data.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:merchants_sdk/src/manager/application/restaurant/restaurant_provider.dart';
import 'package:merchants_sdk/src/manager/application/restaurant/working_days/working_days_provider.dart';
import 'package:merchants_sdk/src/manager/utils/week_days.dart';

// Ported from paas_manager lib/presentation/pages/restaurant/widgets/
// working_time_modal.dart. Deltas: the day model is base_sdk's
// [ShopWorkingDay] (no copyWith — entries are rebuilt in place); the time
// strings the pickers write use ':' (the legacy code wrote 'HH-mm' with a
// dash, which only its own substring parsing tolerated); the CustomToggle
// is the host's isText-less variant via ${package} (base_sdk's two
// CustomToggles have different signatures).
class WorkingTimeModal extends ConsumerStatefulWidget {
  const WorkingTimeModal({super.key});

  @override
  ConsumerState<WorkingTimeModal> createState() => _WorkingTimeModalState();
}

class _WorkingTimeModalState extends ConsumerState<WorkingTimeModal> {
  late List<ShopWorkingDay> _workingDays;
  late List<ShopWorkingDay> _savingWorkingDays;
  bool _shouldUpdate = false;
  final List temp = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _workingDays = ref.read(restaurantProvider).shop?.shopWorkingDays ?? [];
        if (_workingDays.isNotEmpty) {
          for (int i = 0; i < _workingDays.length; i++) {
            temp.add(_workingDays[i].day);
          }
          for (int i = 0; i < WeekDays.values.length; i++) {
            if (temp.contains(WeekDays.values[i].name)) {
              continue;
            } else {
              _workingDays.add(ShopWorkingDay(
                id: i,
                day: WeekDays.values[i].name,
                from: "00:00",
                to: "00:00",
                disabled: false,
              ));
            }
          }
        } else {
          for (int i = 0; i < WeekDays.values.length; i++) {
            _workingDays.add(ShopWorkingDay(
              id: i,
              day: WeekDays.values[i].name,
              from: "00:00",
              to: "00:00",
              disabled: false,
            ));
          }
        }
        _savingWorkingDays = _workingDays;
        ref.read(workingDaysProvider.notifier).setShopWorkingDays(_workingDays);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalWrap(
      body: Padding(
        padding: REdgeInsets.symmetric(horizontal: 16),
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(workingDaysProvider);
            final shopState = ref.watch(restaurantProvider);
            final event = ref.read(workingDaysProvider.notifier);
            final shopEvent = ref.read(restaurantProvider.notifier);
            return state.workingDays.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3.r,
                      color: AppStyle.primary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ModalDrag(),
                      TitleAndIcon(
                        title: AppHelpers.getTranslation(TrKeys.workingHours),
                      ),
                      Text(
                        AppHelpers.getTranslation(TrKeys.enterOpeningHours),
                        style: AppStyle.interNormal(
                          size: 14.sp,
                          color: AppStyle.blackColor,
                        ),
                      ),
                      24.verticalSpace,
                      SizedBox(
                        height: 40.r,
                        width: MediaQuery.sizeOf(context).width - 32.w,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ..._workingDays.map(
                              (ShopWorkingDay day) => GestureDetector(
                                onTap: () {
                                  event.changeIndex(day);
                                  _savingWorkingDays = _workingDays;
                                },
                                child: SmallWeekdayItem(
                                  isSelected: state.currentIndex ==
                                      _workingDays.indexOf(day),
                                  day: day,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      30.verticalSpace,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppHelpers.getTranslation(TrKeys.setBusinessDay),
                            style: AppStyle.interNormal(
                              size: 16.sp,
                              letterSpacing: -0.3,
                            ),
                          ),
                          CustomToggle(
                            key: UniqueKey(),
                            controller: ValueNotifier<bool>(
                              !(_savingWorkingDays[state.currentIndex]
                                      .disabled ??
                                  false),
                            ),
                            onChange: (value) {
                              _setDisabledDay(
                                currentIndex: state.currentIndex,
                                disabled: value,
                              );
                            },
                          ),
                        ],
                      ),
                      40.verticalSpace,
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 160.h,
                              child: CupertinoDatePicker(
                                key: UniqueKey(),
                                mode: CupertinoDatePickerMode.time,
                                initialDateTime: DateTime(
                                  2022,
                                  1,
                                  1,
                                  int.tryParse(
                                          _savingWorkingDays[
                                                      state.currentIndex]
                                                  .from
                                                  ?.substring(0, 2) ??
                                              '') ??
                                      0,
                                  int.tryParse(
                                          _savingWorkingDays[
                                                      state.currentIndex]
                                                  .from
                                                  ?.substring(3, 5) ??
                                              '') ??
                                      0,
                                ),
                                onDateTimeChanged: (DateTime newDateTime) {
                                  _setTimeToDay(
                                    time: TimeOfDay.fromDateTime(newDateTime),
                                    currentIndex: state.currentIndex,
                                  );
                                },
                                use24hFormat: true,
                                minuteInterval: 1,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 160.h,
                              child: CupertinoDatePicker(
                                key: UniqueKey(),
                                mode: CupertinoDatePickerMode.time,
                                use24hFormat: true,
                                minuteInterval: 1,
                                initialDateTime: DateTime(
                                  2022,
                                  1,
                                  1,
                                  int.tryParse(
                                          _savingWorkingDays[
                                                      state.currentIndex]
                                                  .to
                                                  ?.substring(0, 2) ??
                                              '') ??
                                      0,
                                  int.tryParse(
                                          _savingWorkingDays[
                                                      state.currentIndex]
                                                  .to
                                                  ?.substring(3, 5) ??
                                              '') ??
                                      0,
                                ),
                                onDateTimeChanged: (DateTime newDateTime) {
                                  _setTimeToDay(
                                    time: TimeOfDay.fromDateTime(newDateTime),
                                    isFrom: false,
                                    currentIndex: state.currentIndex,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      40.verticalSpace,
                      CustomButton(
                        title: AppHelpers.getTranslation(TrKeys.save),
                        isLoading: state.isLoading,
                        onPressed: () {
                          _savingWorkingDays = _workingDays;
                          if (_shouldUpdate) {
                            event.updateWorkingDays(
                              days: _savingWorkingDays,
                              shopUuid: shopState.shop?.id,
                              updateSuccess: () {
                                shopEvent.updateWorkingDays(_savingWorkingDays);
                                context.maybePop();
                              },
                            );
                          }
                        },
                      ),
                      30.verticalSpace,
                    ],
                  );
          },
        ),
      ),
    );
  }

  ShopWorkingDay _rebuilt(
    ShopWorkingDay day, {
    String? from,
    String? to,
    bool? disabled,
  }) =>
      // base_sdk's ShopWorkingDay has no copyWith; rebuild keeping the rest.
      ShopWorkingDay(
        id: day.id,
        day: day.day,
        from: from ?? day.from,
        to: to ?? day.to,
        disabled: disabled ?? day.disabled,
        createdAt: day.createdAt,
        updatedAt: day.updatedAt,
      );

  void _setDisabledDay({
    bool? disabled,
    required int currentIndex,
  }) {
    _shouldUpdate = true;
    _workingDays[currentIndex] = _rebuilt(
      _workingDays[currentIndex],
      disabled: !(disabled ?? false),
    );
  }

  void _setTimeToDay({
    required TimeOfDay time,
    bool isFrom = true,
    required int currentIndex,
  }) {
    _shouldUpdate = true;
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (isFrom) {
      _workingDays[currentIndex] = _rebuilt(
        _workingDays[currentIndex],
        from: formatted,
      );
    } else {
      _workingDays[currentIndex] = _rebuilt(
        _workingDays[currentIndex],
        to: formatted,
      );
    }
  }
}
