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


// Standalone-harness TrKeys injection.
//
// TrKeys entries this SDK's pages reference are declared in this package's
// `manifest.json` under `tr_keys` and are BY DESIGN absent from raw base_sdk:
// at compose time the SDK installer (`sdk_installer_base.py`,
// `update_tr_keys_registration`) injects every installed SDK's manifest
// `tr_keys` into the HOST app's copy of base_sdk's `TrKeys` class, between the
// `// @sdk-tr-keys-start` / `// @sdk-tr-keys-end` markers that
// `lib/src/services/tr_keys.dart` carries for exactly this purpose.
//
// When this package is resolved STANDALONE (tests, analysis), base_sdk comes
// from the workspace checkout via the pubspec `dependency_overrides`, and that
// checkout's marker region is empty — so every `TrKeys.<key>` this SDK's code
// references fails to compile and the whole test suite fails to load.
//
// This tool performs the same injection the installer does, from the same
// single source of truth (`manifest.json` `tr_keys`), into the same marker
// region of the RESOLVED base_sdk checkout, with the same collision rule
// (a key base_sdk already declares outside the markers is skipped — base's
// declaration wins, exactly as on compose). Because the input is the very map
// the compose step consumes, the standalone harness cannot drift from compose:
// a key added to the manifest is picked up on the next run with no
// hand-maintained duplicate list anywhere.
//
// The write is confined to the marker region and is idempotent; restore the
// pristine checkout any time with `git checkout -- lib/src/services/tr_keys.dart`
// in the base_sdk repo. Nothing is committed anywhere by this tool.
//
// Usage (from merchants/dart, after `flutter pub get`):
//
//   dart run tool/inject_tr_keys.dart
//
// `test/tr_keys_injection_guard_test.dart` fails with a pointer to this tool
// whenever the resolved base_sdk is missing manifest keys, so an out-of-date
// injection is diagnosed instead of surfacing as hundreds of compile errors.

import 'dart:convert';
import 'dart:io';

const startMarker = '// @sdk-tr-keys-start';
const endMarker = '// @sdk-tr-keys-end';

void main(List<String> args) {
  final manifestFile = File('manifest.json');
  final packageConfigFile = File('.dart_tool/package_config.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('manifest.json not found — run from the package root '
        '(merchants/dart).');
    exit(2);
  }
  if (!packageConfigFile.existsSync()) {
    stderr.writeln('.dart_tool/package_config.json not found — run '
        '`flutter pub get` first.');
    exit(2);
  }

  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final sdkName = manifest['name'] as String? ?? 'sdk';
  // merchants_sdk delta from the lms original: this SDK's tr_keys live
  // inside its app_type flavor blocks (manager, driver), not at the top
  // level — on compose the installer injects the composed flavor's block.
  // Standalone resolves ALL flavors' keys (a harmless superset: tests and
  // analysis cover both role folders).
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
  if (trKeys.isEmpty) {
    stdout.writeln('manifest.json declares no tr_keys — nothing to inject.');
    return;
  }

  // Locate the resolved base_sdk checkout (works under any override).
  final packageConfig =
      jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = (packageConfig['packages'] as List).cast<Map>();
  final baseSdk = packages.firstWhere(
    (p) => p['name'] == 'base_sdk',
    orElse: () => throw StateError('base_sdk not in package_config.json'),
  );
  // Ensure a trailing slash so Uri.resolve treats the root as a directory.
  final rootUriRaw = baseSdk['rootUri'] as String;
  final rootUri =
      Uri.parse(rootUriRaw.endsWith('/') ? rootUriRaw : '$rootUriRaw/');
  final baseSdkRootUri = rootUri.isAbsolute
      ? rootUri
      : File(packageConfigFile.path).absolute.parent.uri.resolveUri(rootUri);
  final trKeysFile = File.fromUri(
      baseSdkRootUri.resolve('lib/src/services/tr_keys.dart'));
  if (!trKeysFile.existsSync()) {
    stderr.writeln('base_sdk tr_keys.dart not found at ${trKeysFile.path}');
    exit(2);
  }

  final src = trKeysFile.readAsStringSync();
  final startIdx = src.indexOf(startMarker);
  final endIdx = src.indexOf(endMarker, startIdx + startMarker.length);
  if (startIdx < 0 || endIdx < 0) {
    stderr.writeln('Injection markers not found in ${trKeysFile.path} — '
        'this base_sdk checkout does not support tr_keys injection.');
    exit(2);
  }

  // Same rule as the installer: a manifest key whose NAME base_sdk already
  // declares outside the marker region is skipped — base's declaration wins.
  // The block's current contents are excluded so keys injected by a previous
  // run don't mask themselves on re-injection.
  final outsideRegion =
      src.substring(0, startIdx) + src.substring(endIdx + endMarker.length);
  final baseOwned = RegExp(r'static const String (\w+)\s*=')
      .allMatches(outsideRegion)
      .map((m) => m.group(1))
      .toSet();

  // Same escaping as the installer (backslash, then single quote).
  String escape(String v) =>
      v.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  final keyLines = <String>[];
  trKeys.forEach((field, value) {
    if (baseOwned.contains(field)) {
      stdout.writeln("  [!] tr_keys collision: '$field' already exists in "
          "base tr_keys.dart - keeping base's declaration");
      return;
    }
    // compliance-ignore: flutter-hardcoded-secret (generated translation-key declaration in a codegen tool, not a credential)
    keyLines.add("  static const String $field = '${escape(value)}';");
  });

  final replacement =
      '$startMarker\n${keyLines.join('\n')}\n  $endMarker';
  final updated = src.substring(0, startIdx) +
      replacement +
      src.substring(endIdx + endMarker.length);
  if (updated == src) {
    stdout.writeln('TrKeys already up to date '
        '(${keyLines.length} keys, ${trKeysFile.path}).');
    return;
  }
  trKeysFile.writeAsStringSync(updated);
  stdout.writeln('Injected ${keyLines.length} $sdkName tr_keys into '
      '${trKeysFile.path}.');
}
