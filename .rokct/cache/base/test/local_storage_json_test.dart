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


// LocalStorage's generic JSON key API (design 46e): the setJson/getJson/
// deleteJson trio feature SDKs park host-owned records under, and the
// setOnboardingRun/getOnboardingRun/deleteOnboardingRun pair built on it.
// Round-trip, null-as-remove, corrupt-JSON-reads-as-absent (never throws),
// and the hostRecord. prefix keeping caller keys off the typed keys.

import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';
import 'package:base_sdk/src/services/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory SecureStore so logout() never reaches a platform channel.
class _MemorySecureStore implements SecureStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await LocalStorage.init();
  }

  const record = <String, dynamic>{
    'version': 1,
    'stepIndex': 2,
    'done': ['welcome', 'role', 'slide:0'],
    'lastTouched': '2026-09-02T13:45:00.000Z',
    'values': {'school': 'Ridge'},
    'role': 'student',
    'roleStepVisible': true,
  };

  group('LocalStorage.setJson/getJson/deleteJson', () {
    test('absent key reads as null', () async {
      await boot({});
      expect(LocalStorage.getJson('nothing.here'), isNull);
    });

    test('round-trips a nested record', () async {
      await boot({});
      await LocalStorage.setJson('run', record);
      expect(LocalStorage.getJson('run'), equals(record));
      // Nested collections come back as their JSON shapes, not references.
      expect(LocalStorage.getJson('run')!['done'], isA<List>());
      expect(LocalStorage.getJson('run')!['values'], isA<Map>());
    });

    test('overwrites in place', () async {
      await boot({});
      await LocalStorage.setJson('run', {'stepIndex': 1});
      await LocalStorage.setJson('run', {'stepIndex': 4});
      expect(LocalStorage.getJson('run'), equals({'stepIndex': 4}));
    });

    test('null value removes the key', () async {
      await boot({});
      await LocalStorage.setJson('run', record);
      await LocalStorage.setJson('run', null);
      expect(LocalStorage.getJson('run'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('${StorageKeys.keyHostRecordPrefix}run'),
          isFalse);
    });

    test('deleteJson removes the key and is idempotent', () async {
      await boot({});
      await LocalStorage.setJson('run', record);
      await LocalStorage.deleteJson('run');
      expect(LocalStorage.getJson('run'), isNull);
      await LocalStorage.deleteJson('run');
      expect(LocalStorage.getJson('run'), isNull);
    });

    test('corrupt JSON reads as null, never throws', () async {
      await boot({'${StorageKeys.keyHostRecordPrefix}run': '{not json'});
      expect(() => LocalStorage.getJson('run'), returnsNormally);
      expect(LocalStorage.getJson('run'), isNull);
    });

    test('empty string and non-object JSON read as null', () async {
      await boot({
        '${StorageKeys.keyHostRecordPrefix}empty': '',
        '${StorageKeys.keyHostRecordPrefix}list': '[1, 2, 3]',
        '${StorageKeys.keyHostRecordPrefix}scalar': '"text"',
        '${StorageKeys.keyHostRecordPrefix}nul': 'null',
      });
      expect(LocalStorage.getJson('empty'), isNull);
      expect(LocalStorage.getJson('list'), isNull);
      expect(LocalStorage.getJson('scalar'), isNull);
      expect(LocalStorage.getJson('nul'), isNull);
    });

    test('keys live under the hostRecord. prefix', () async {
      await boot({});
      await LocalStorage.setJson('run', record);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('run'), isFalse);
      expect(prefs.getString('${StorageKeys.keyHostRecordPrefix}run'),
          isNotNull);
    });

    test('a caller key spelled like a typed key cannot touch it', () async {
      await boot({StorageKeys.keyToken: 'abc'});
      await LocalStorage.setJson(StorageKeys.keyToken, {'stolen': true});
      expect(LocalStorage.getToken(), 'abc');
      expect(LocalStorage.getJson(StorageKeys.keyToken), {'stolen': true});
      await LocalStorage.deleteJson(StorageKeys.keyToken);
      expect(LocalStorage.getToken(), 'abc');
    });

    test('a bare pref under the caller key is invisible to getJson',
        () async {
      await boot({'run': '{"stepIndex": 9}'});
      expect(LocalStorage.getJson('run'), isNull);
    });

    test('two keys do not share a record', () async {
      await boot({});
      await LocalStorage.setJson('a', {'v': 1});
      await LocalStorage.setJson('b', {'v': 2});
      await LocalStorage.deleteJson('a');
      expect(LocalStorage.getJson('a'), isNull);
      expect(LocalStorage.getJson('b'), equals({'v': 2}));
    });
  });

  group('LocalStorage.setOnboardingRun/getOnboardingRun/deleteOnboardingRun',
      () {
    test('round-trips through the generic pair under the fixed sub-key',
        () async {
      await boot({});
      await LocalStorage.setOnboardingRun(record);
      expect(LocalStorage.getOnboardingRun(), equals(record));
      expect(LocalStorage.getJson(StorageKeys.keyOnboardingRun),
          equals(record));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(
          '${StorageKeys.keyHostRecordPrefix}${StorageKeys.keyOnboardingRun}',
        ),
        isNotNull,
      );
    });

    test('null clears, deleteOnboardingRun clears', () async {
      await boot({});
      await LocalStorage.setOnboardingRun(record);
      await LocalStorage.setOnboardingRun(null);
      expect(LocalStorage.getOnboardingRun(), isNull);
      await LocalStorage.setOnboardingRun(record);
      await LocalStorage.deleteOnboardingRun();
      expect(LocalStorage.getOnboardingRun(), isNull);
    });

    test('corrupt record reads as null', () async {
      await boot({
        '${StorageKeys.keyHostRecordPrefix}${StorageKeys.keyOnboardingRun}':
            '{"stepIndex":',
      });
      expect(LocalStorage.getOnboardingRun(), isNull);
    });

    test('logout leaves the run in place', () async {
      SecureStorage.store = _MemorySecureStore();
      await boot({StorageKeys.keyToken: 'abc'});
      await LocalStorage.setOnboardingRun(record);
      LocalStorage.logout();
      expect(LocalStorage.getToken(), '');
      expect(LocalStorage.getOnboardingRun(), equals(record));
    });
  });
}
