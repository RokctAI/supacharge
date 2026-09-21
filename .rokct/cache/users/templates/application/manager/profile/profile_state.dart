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

// Ported from paas_manager lib/application/profile/profile_state.dart
// (users_sdk manager consume, fork plan S-2 / migration bucket b).
// Trimmed to the fields the composed manager surfaces actually read:
// the retired become-seller CreateShopPage flow (bgImage/logoImage/
// filepath/isSaveLoading/typeIndex/addressModel) is replaced by
// merchants_sdk's shop-setup registration step, and referral/wallet
// history never shipped in the manager shell.
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:base_sdk/src/models/data/profile_data.dart';

part 'profile_state.freezed.dart';

@freezed
abstract class ProfileState with _$ProfileState {
  const factory ProfileState({
    @Default(true) bool isLoading,
    @Default(null) ProfileData? userData,
  }) = _ProfileState;

  const ProfileState._();
}
