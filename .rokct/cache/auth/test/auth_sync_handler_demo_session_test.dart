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

// Demo login in production, phase 2 (auth side): the auth.register outbox
// handler follows the runtime demo switch. auth_di.dart registers
// DemoHoldSyncHandler(AuthSyncHandler()): while a demo session is active
// (or in a demo build) nothing queued may reach the real backend, so the
// hold answers retryable without handing the op to the inner handler; the
// moment the session clears the same registration pushes again. The auth
// repository itself is NOT part of the switch: a demo account signs in
// through the real backend, and MockAuthRepository stays behind the
// compile-time constant (demo_account_test.dart pins that).
//
// The hold is exercised through a fake inner handler: AuthSyncHandler
// reaches drift's generated offline_users table, which this package does
// not generate standalone, so the DI wiring is pinned at source level.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/database/app_database.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/sync/sync_handler.dart';

import 'package:auth_sdk/src/common/infrastructure/services/demo_hold_sync_handler.dart';

/// Counts what reaches it; every push it does receive succeeds.
class _RecordingHandler extends SyncHandler {
  int pushes = 0;
  int synced = 0;

  @override
  Future<SyncResult> push(OutboxEntry op) async {
    pushes++;
    return const SyncResult.synced();
  }

  @override
  Future<void> onSynced(OutboxEntry op, Map<String, String> idMappings) async {
    synced++;
  }
}

OutboxEntry _registerOp() {
  final now = DateTime.now();
  return OutboxEntry(
    id: 'op-1',
    opType: 'auth.register',
    sdk: 'auth_sdk',
    payload: '{"localUserId":"local-1"}',
    tempIds: '[]',
    dependsOn: '[]',
    status: 'pending',
    attempts: 0,
    createdAt: now,
    updatedAt: now,
  );
}

const List<String> _fixtureWords = ['demo', 'example', 'placeholder', 'sample'];

/// Source with `//` line comments stripped, so prose never satisfies or
/// trips a code guard.
String _withoutLineComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingHandler inner;
  late DemoHoldSyncHandler handler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    DemoSession.isDemoOverride = false;
    inner = _RecordingHandler();
    handler = DemoHoldSyncHandler(inner);
  });

  tearDown(() async {
    await DemoSession.instance.clear();
    DemoSession.isDemoOverride = null;
  });

  test('a real session pushes as before', () async {
    expect(DemoSession.demoActive, isFalse);

    final result = await handler.push(_registerOp());

    expect(inner.pushes, 1);
    expect(result, isA<SyncSynced>());
  });

  test(
    'an active demo session holds the op without reaching the handler',
    () async {
      await DemoSession.instance.activate();

      final result = await handler.push(_registerOp());

      expect(inner.pushes, 0);
      expect(result, isA<SyncRetryable>());
      expect(
        (result as SyncRetryable).error,
        DemoHoldSyncHandler.sessionHoldError,
      );
    },
  );

  test('the hold lifts the moment the session clears', () async {
    await DemoSession.instance.activate();
    expect(await handler.push(_registerOp()), isA<SyncRetryable>());
    expect(inner.pushes, 0);

    // Every sign-out path ends in LocalStorage.logout(), which clears the
    // session; the same registration resumes on the next drain.
    await DemoSession.instance.clear();

    expect(await handler.push(_registerOp()), isA<SyncSynced>());
    expect(inner.pushes, 1);
  });

  test('a demo build holds the op too', () async {
    DemoSession.isDemoOverride = true;

    expect(await handler.push(_registerOp()), isA<SyncRetryable>());
    expect(inner.pushes, 0);
  });

  test('onSynced passes straight through', () async {
    await handler.onSynced(_registerOp(), const {});
    expect(inner.synced, 1);
  });

  test('the DI wraps the auth handler in the hold, and only the handler', () {
    final di = _withoutLineComments(
      File('lib/src/common/di/auth_di.dart').readAsStringSync(),
    );
    expect(di, contains('DemoHoldSyncHandler(AuthSyncHandler())'));
    // The repository is not on the switch: one MockAuthRepository(), on
    // the compile-time constant (demo_account_test.dart pins the line).
    expect(RegExp(r'MockAuthRepository\(\)').allMatches(di), hasLength(1));
    expect(di, isNot(contains('DemoSession')));
  });

  test('the held error names no fixture and the hold no mock', () {
    // An outbox row's lastError can reach a sync status surface.
    final error = DemoHoldSyncHandler.sessionHoldError.toLowerCase();
    for (final word in _fixtureWords) {
      expect(error, isNot(contains(word)), reason: word);
    }
    final source = File(
      'lib/src/common/infrastructure/services/demo_hold_sync_handler.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('MockAuthRepository')));
    expect(source, isNot(contains('demoUserLogin')));
    expect(source, isNot(contains('demoUserPassword')));
  });
}
