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


// Guards the standalone harness against TrKeys injection drift (lms_sdk's
// tr_keys_injection_guard_test pattern).
//
// This SDK's TrKeys entries live in `manifest.json` — inside the app_type
// flavor blocks (manager, driver) — and are injected into the host's
// base_sdk `TrKeys` at compose time. Standalone,
// `tool/inject_tr_keys.dart` performs the same injection into the
// resolved base_sdk checkout (all flavors' keys, a harmless superset).
//
// This test reads both sides from disk and fails with the exact
// regeneration command whenever the resolved base_sdk is missing a
// manifest key — ONE actionable failure instead of hundreds of
// undefined-getter compile errors taking down the whole POS suite.
//
// Deliberately imports nothing from merchants_sdk: it must still load
// when the rest of the suite cannot compile.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'resolved base_sdk TrKeys carries every manifest tr_key '
      '(else run: dart run tool/inject_tr_keys.dart)', () {
    final manifest = jsonDecode(File('manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    final trKeys = <String, String>{};
    (manifest['tr_keys'] as Map<String, dynamic>? ?? {})
        .forEach((k, v) => trKeys[k] = v as String);
    final appType = manifest['app_type'] as Map<String, dynamic>? ?? {};
    for (final flavor in appType.values) {
      if (flavor is Map<String, dynamic>) {
        (flavor['tr_keys'] as Map<String, dynamic>? ?? {})
            .forEach((k, v) => trKeys[k] = v as String);
      }
    }
    expect(trKeys, isNotEmpty,
        reason: 'manifest.json is expected to declare tr_keys');

    final packageConfigFile = File('.dart_tool/package_config.json');
    final packageConfig = jsonDecode(packageConfigFile.readAsStringSync())
        as Map<String, dynamic>;
    final baseSdk = (packageConfig['packages'] as List)
        .cast<Map>()
        .firstWhere((p) => p['name'] == 'base_sdk');
    final rootUriRaw = baseSdk['rootUri'] as String;
    final rootUri =
        Uri.parse(rootUriRaw.endsWith('/') ? rootUriRaw : '$rootUriRaw/');
    final baseSdkRootUri = rootUri.isAbsolute
        ? rootUri
        : packageConfigFile.absolute.parent.uri.resolveUri(rootUri);
    final src =
        File.fromUri(baseSdkRootUri.resolve('lib/src/services/tr_keys.dart'))
            .readAsStringSync();

    // A TrKeys member may come from the injected marker block or be
    // declared by base itself (in which case the installer keeps base's
    // declaration and skips the SDK's — same rule
    // tool/inject_tr_keys.dart applies).
    final declared = RegExp(r'static const String (\w+)\s*=')
        .allMatches(src)
        .map((m) => m.group(1))
        .toSet();
    final missing =
        trKeys.keys.where((k) => !declared.contains(k)).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason: 'The resolved base_sdk TrKeys is missing '
          '${missing.length} key(s) declared in manifest.json '
          '(first few: ${missing.take(5).join(', ')}). '
          'Re-run the standalone injection from merchants/dart:\n'
          '  dart run tool/inject_tr_keys.dart\n'
          'This regenerates the @sdk-tr-keys block from manifest.json — '
          'never add keys to TrKeys by hand.',
    );
  });
}
