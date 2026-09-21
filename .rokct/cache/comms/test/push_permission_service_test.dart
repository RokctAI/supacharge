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


// compliance-ignore-file: obs-flutter-trace
// False positive: this is a unit test with no network at all - it
// drives PushPermissionService against an in-memory fake of the
// firebase_messaging platform channel. Flagged only because the file
// name carries 'service'; there is no request to stamp with a trace id.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comms_sdk/src/common/services/push_permission_service.dart';

/// Stands in for `MethodChannelFirebaseMessaging.requestPermission`,
/// including the part that makes the guided tour fail: asking a second time
/// while a request is outstanding throws the platform channel's
/// concurrent-request FirebaseException.
class _FakePlatformPermission {
  int calls = 0;
  int concurrent = 0;
  Completer<NotificationSettings?>? _outstanding;

  Future<NotificationSettings?> request({
    required bool sound,
    required bool alert,
    required bool badge,
  }) {
    calls += 1;
    if (_outstanding != null) {
      concurrent += 1;
      throw FirebaseException(
        plugin: 'firebase_messaging',
        message: 'A request for permissions is already running, please wait '
            'for it to finish before doing another request.',
      );
    }
    final Completer<NotificationSettings?> completer =
        Completer<NotificationSettings?>();
    _outstanding = completer;
    return completer.future;
  }

  void finish() {
    final Completer<NotificationSettings?>? completer = _outstanding;
    _outstanding = null;
    completer?.complete(null);
  }

  void fail(Object error) {
    final Completer<NotificationSettings?>? completer = _outstanding;
    _outstanding = null;
    completer?.completeError(error);
  }
}

void main() {
  late _FakePlatformPermission fake;

  setUp(() {
    fake = _FakePlatformPermission();
    PushPermissionService.resetForTest();
    PushPermissionService.platformRequestOverride = fake.request;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PushPermissionService.resetForTest();
  });

  test('REPRODUCTION: the raw platform call throws when asked twice at once',
      () {
    // Exactly what run 33476454451 hit. The fake mirrors
    // MethodChannelFirebaseMessaging: a concurrent request throws
    // [firebase_messaging/unknown]. This is the unguarded behaviour the
    // shells had when they called FirebaseMessaging.instance directly.
    fake.request(sound: true, alert: true, badge: false);
    expect(
      () => fake.request(sound: true, alert: true, badge: false),
      throwsA(isA<FirebaseException>().having(
        (FirebaseException e) => e.message,
        'message',
        contains('already running'),
      )),
    );
    expect(fake.concurrent, 1);
    fake.finish();
  });

  test('a second sign-in while the first request is pending does not throw',
      () async {
    // The paas_manager / paas_driver guided tours sign in twice in one
    // process. Before the guard the second shell mount fired a second
    // requestPermission and the platform channel threw
    // [firebase_messaging/unknown] "A request for permissions is already
    // running" as an UNCAUGHT async error, failing `flutter test`.
    final Future<NotificationSettings?> first = PushPermissionService.request();
    final Future<NotificationSettings?> second =
        PushPermissionService.request();

    expect(PushPermissionService.isRequestInFlight, isTrue);

    fake.finish();
    await expectLater(first, completes);
    await expectLater(second, completes);

    expect(fake.calls, 1, reason: 'the redundant request is suppressed');
    expect(fake.concurrent, 0,
        reason: 'the platform channel is never asked twice at once');
    expect(PushPermissionService.isRequestInFlight, isFalse);
  });

  test('a single sign-in still asks the platform exactly once', () async {
    final Future<NotificationSettings?> only = PushPermissionService.request();
    expect(fake.calls, 1);
    fake.finish();
    await only;
    expect(fake.calls, 1);
    expect(PushPermissionService.isRequestInFlight, isFalse);
  });

  test('a later sign-in asks again once the first request has finished',
      () async {
    final Future<NotificationSettings?> first = PushPermissionService.request();
    fake.finish();
    await first;

    final Future<NotificationSettings?> later = PushPermissionService.request();
    expect(fake.calls, 2, reason: 'de-duplication is per in-flight request');
    fake.finish();
    await later;
  });

  test('a failed request clears the guard instead of latching it', () async {
    final Future<NotificationSettings?> first = PushPermissionService.request();
    fake.fail(
      FirebaseException(plugin: 'firebase_messaging', message: 'denied'),
    );
    expect(await first, isNull, reason: 'fail open, never rethrow');
    expect(PushPermissionService.isRequestInFlight, isFalse);

    final Future<NotificationSettings?> retry = PushPermissionService.request();
    expect(fake.calls, 2, reason: 'notifications still work after a failure');
    fake.finish();
    await retry;
  });

  test('a request that fails before suspending does not latch the guard',
      () async {
    PushPermissionService.platformRequestOverride = ({
      required bool sound,
      required bool alert,
      required bool badge,
    }) =>
        throw StateError('synchronous platform failure');

    expect(await PushPermissionService.request(), isNull);
    expect(PushPermissionService.isRequestInFlight, isFalse);
  });

  test('windows never touches firebase_messaging', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(PushPermissionService.isSupportedPlatform, isFalse);
    expect(await PushPermissionService.request(), isNull);
    expect(fake.calls, 0,
        reason: 'firebase_messaging has no Windows implementation');
  });

  test('the allowlist covers android, iOS and macOS', () {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(PushPermissionService.isSupportedPlatform, isTrue,
          reason: '$platform is a firebase_messaging platform');
    }
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(PushPermissionService.isSupportedPlatform, isFalse);
    }
  });
}
