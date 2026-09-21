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

import 'package:flutter_test/flutter_test.dart';

// ShopNavAvatar (lib/src/manager/presentation/main/shop_nav_avatar.dart)
// passes `errorBuilder` to `SvgPicture.network`, which flutter_svg only
// grew in 2.0.17. This package's own pubspec.lock resolves a much newer
// flutter_svg, so its widget tests cannot notice a floor that is too low;
// the composed shells can (paas_manager and paas_driver commit a
// pubspec.lock pinned to 2.0.10+1, and the composer's `flutter pub get`
// keeps that pin for as long as this package's constraint allows it -
// guided tour run 34049266887). This guard fails here, in the standalone
// harness, if the floor ever drops back below 2.0.17.
void main() {
  test('flutter_svg floor stays at or above 2.0.17 (SvgPicture errorBuilder)',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^\s{2}flutter_svg:\s*\^(\d+)\.(\d+)\.(\d+)', multiLine: true)
            .firstMatch(pubspec);
    expect(match, isNotNull,
        reason: 'pubspec.yaml must declare flutter_svg with a caret floor');
    final floor = [
      int.parse(match!.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
    const minimum = [2, 0, 17];
    var atLeast = true;
    for (var i = 0; i < 3; i++) {
      if (floor[i] != minimum[i]) {
        atLeast = floor[i] > minimum[i];
        break;
      }
    }
    expect(atLeast, isTrue,
        reason: 'flutter_svg ^${floor.join('.')} is below 2.0.17, the first '
            'release with SvgPicture.network(errorBuilder:) - composed shells '
            'whose lock pins an older flutter_svg would stop compiling '
            'shop_nav_avatar.dart');
  });
}
