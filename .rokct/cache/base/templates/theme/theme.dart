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


// Host-shell theme shim: composed-app pages import
// package:<app>/presentation/theme/theme.dart; the real theme lives in
// base_sdk. Re-exported here so installed template pages resolve unchanged.
//
// This installed file is also where THE APP'S brand palette lives: the
// kernel ships neutral defaults only, and [applyAppBrandColors] (call it in
// main() before runApp) injects this app's values via
// AppStyle.injectBrandColors. Customize the values here — the installer
// never overwrites an edited copy.
import 'package:base_sdk/src/presentation/theme/app_style.dart';

export 'package:base_sdk/src/presentation/theme/app_style.dart';
export 'package:base_sdk/src/presentation/theme/map_themes.dart';

/// Injects this app's brand palette into the shared AppStyle tokens.
/// Default template: keeps the kernel's neutral defaults — replace with
/// your app's palette on install.
void applyAppBrandColors() {
  AppStyle.injectBrandColors();
}
