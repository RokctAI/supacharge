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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/services/local_storage.dart';

import 'package:auth_sdk/src/common/domain/interface/restore_credential_platform.dart';
import 'package:auth_sdk/src/common/services/restore_credential_service.dart';

/// A stand-in for core's Android channel.
///
/// auth_sdk deliberately owns only the interface, so this is what lets the
/// whole lifecycle be exercised here without core's implementation, and
/// without any platform channel.
class FakeRestoreCredentialPlatform extends RestoreCredentialPlatform {
  FakeRestoreCredentialPlatform({
    this.supported = true,
    this.createResult,
    this.getResult,
    this.throwE2eeOnCloudBackup = false,
  });

  final bool supported;
  final String? createResult;
  final String? getResult;

  /// Reproduces a device with no backup, no screen lock, or no E2EE.
  final bool throwE2eeOnCloudBackup;

  final List<bool> createCalls = <bool>[];
  int getCalls = 0;
  int clearCalls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<String?> createRestoreKey(
    String requestJson, {
    bool isCloudBackupEnabled = true,
  }) async {
    createCalls.add(isCloudBackupEnabled);
    if (throwE2eeOnCloudBackup && isCloudBackupEnabled) {
      throw const RestoreCredentialE2eeUnavailable('no e2ee in test');
    }
    return createResult;
  }

  @override
  Future<String?> getRestoreKey(String requestJson) async {
    getCalls++;
    return getResult;
  }

  @override
  Future<void> clearRestoreKey() async => clearCalls++;
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
    RestoreCredentialPlatform.instance = const NoRestoreCredentialPlatform();
  });

  tearDown(() {
    RestoreCredentialPlatform.instance = const NoRestoreCredentialPlatform();
  });

  group('default platform', () {
    test('reports itself unsupported so the feature stays dormant', () async {
      expect(
        await const NoRestoreCredentialPlatform().isSupported(),
        isFalse,
      );
    });

    test('every operation no-ops instead of throwing', () async {
      const platform = NoRestoreCredentialPlatform();
      expect(await platform.createRestoreKey('{}'), isNull);
      expect(await platform.getRestoreKey('{}'), isNull);
      // Must not throw: sign-out calls this unconditionally.
      await platform.clearRestoreKey();
    });

    test('is the instance in force until something installs one', () {
      expect(
        RestoreCredentialPlatform.instance,
        isA<NoRestoreCredentialPlatform>(),
      );
    });
  });

  group('ensureRestoreKey', () {
    test('does nothing without a session', () async {
      await LocalStorage.setToken('');
      final platform = FakeRestoreCredentialPlatform();
      RestoreCredentialPlatform.instance = platform;

      expect(await RestoreCredentialService().ensureRestoreKey(), isFalse);
      expect(platform.createCalls, isEmpty);
    });

    test('does nothing on a platform that cannot hold restore keys', () async {
      await LocalStorage.setToken('tok');
      final platform = FakeRestoreCredentialPlatform(supported: false);
      RestoreCredentialPlatform.instance = platform;

      expect(await RestoreCredentialService().ensureRestoreKey(), isFalse);
      expect(platform.createCalls, isEmpty);
    });

    test('skips the work once this install already has a key', () async {
      await LocalStorage.setToken('tok');
      SharedPreferences.setMockInitialValues(<String, Object>{
        RestoreCredentialService.hasSyncedFlagKey: true,
      });
      await LocalStorage.init();
      await LocalStorage.setToken('tok');

      final platform = FakeRestoreCredentialPlatform();
      RestoreCredentialPlatform.instance = platform;

      expect(await RestoreCredentialService().ensureRestoreKey(), isFalse);
      // The whole point of the cached flag: no network, no channel call.
      expect(platform.createCalls, isEmpty);
    });
  });

  group('attemptRestore', () {
    test('does nothing when a session already exists', () async {
      await LocalStorage.setToken('tok');
      final platform = FakeRestoreCredentialPlatform(getResult: '{}');
      RestoreCredentialPlatform.instance = platform;

      expect(await RestoreCredentialService().attemptRestore(), isFalse);
      expect(platform.getCalls, 0);
    });

    test('does nothing on an unsupported platform', () async {
      await LocalStorage.setToken('');
      final platform = FakeRestoreCredentialPlatform(supported: false);
      RestoreCredentialPlatform.instance = platform;

      expect(await RestoreCredentialService().attemptRestore(), isFalse);
      expect(platform.getCalls, 0);
    });
  });

  group('clear', () {
    test('deletes the platform key and drops the cached flag', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        RestoreCredentialService.hasSyncedFlagKey: true,
      });
      await LocalStorage.init();
      await LocalStorage.setToken('');

      final platform = FakeRestoreCredentialPlatform();
      RestoreCredentialPlatform.instance = platform;

      await RestoreCredentialService().clear();

      expect(platform.clearCalls, 1);
      expect(
        await RestoreCredentialService.hasSyncedRestoreCredential(),
        isFalse,
      );
    });

    test('still clears locally when the platform throws', () async {
      RestoreCredentialPlatform.instance = _ThrowingPlatform();
      // Must not rethrow: sign-out has to feel unconditional.
      await RestoreCredentialService().clear();
      expect(
        await RestoreCredentialService.hasSyncedRestoreCredential(),
        isFalse,
      );
    });
  });

  group('E2EE fallback contract', () {
    test('E2ee signal carries its message', () {
      const e = RestoreCredentialE2eeUnavailable('no screen lock');
      expect(e.toString(), contains('no screen lock'));
    });

    test('a cloud-backup refusal is retried with backup off', () async {
      // Exercises the documented fallback directly against the platform
      // contract: the first attempt asks for cloud backup, is refused, and
      // the second asks without it.
      final platform = FakeRestoreCredentialPlatform(
        throwE2eeOnCloudBackup: true,
        createResult: jsonEncode(<String, dynamic>{'id': 'abc'}),
      );

      String? result;
      try {
        result = await platform.createRestoreKey('{}');
      } on RestoreCredentialE2eeUnavailable {
        result = await platform.createRestoreKey(
          '{}',
          isCloudBackupEnabled: false,
        );
      }

      expect(platform.createCalls, <bool>[true, false]);
      expect(result, isNotNull);
    });
  });
}

class _ThrowingPlatform extends RestoreCredentialPlatform {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<String?> createRestoreKey(
    String requestJson, {
    bool isCloudBackupEnabled = true,
  }) async =>
      throw StateError('boom');

  @override
  Future<String?> getRestoreKey(String requestJson) async =>
      throw StateError('boom');

  @override
  Future<void> clearRestoreKey() async => throw StateError('boom');
}
