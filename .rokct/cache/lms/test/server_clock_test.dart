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


import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// These tests are the proof that a student can no longer bypass the door
/// policy or the skip-gate release timer by changing their phone's clock. The
/// attack is modelled directly: after the clock syncs, we move the *wall clock*
/// (what `DateTime.now()` would return) forward by hours while leaving the
/// *monotonic* timer where it was — exactly what a phone-clock spoof does — and
/// assert the corrected time (and every gate built on it) does not budge.
void main() {
  // Controllable clocks. `wall` stands in for the spoofable device clock;
  // `mono` stands in for the OS monotonic uptime counter a user can't move.
  late DateTime wall;
  late Duration mono;
  late DateTime serverUtc; // what the backend would return on the next fetch
  var fetchCount = 0;
  Duration syncLatency = Duration.zero;

  ServerClock buildClock() => ServerClock(
        fetch: () async {
          fetchCount++;
          // Latency elapses on the monotonic timer during the fetch, so the
          // RTT-correction path is exercised.
          mono += syncLatency;
          return serverUtc;
        },
        elapsed: () => mono,
        wallClock: () => wall,
        resyncInterval: const Duration(minutes: 10),
      );

  setUp(() {
    // Device clock is deliberately wrong from the start (spoofed 3h fast).
    wall = DateTime.utc(2026, 7, 20, 15, 0).add(const Duration(hours: 3));
    mono = const Duration(seconds: 1000);
    serverUtc = DateTime.utc(2026, 7, 20, 15, 0);
    fetchCount = 0;
    syncLatency = Duration.zero;
  });

  test('before the first sync, now() falls back to the device clock', () {
    final clock = buildClock();
    expect(clock.hasSynced, isFalse);
    // Fallback returns the device clock verbatim (drop-in for DateTime.now()).
    expect(clock.now(), wall);
  });

  test('after sync, moving the device clock forward does NOT move now()',
      () async {
    final clock = buildClock();
    await clock.sync();
    final corrected = clock.now();
    // Corrected time tracks the server, not the 3h-fast device clock.
    expect(corrected, serverUtc.toLocal());

    // Spoof: jump the device wall clock forward by 5 hours.
    wall = wall.add(const Duration(hours: 5));
    // Monotonic timer is untouched → corrected time is unchanged.
    expect(clock.now(), corrected);
  });

  test('now() advances by exactly the monotonic elapsed since sync', () async {
    final clock = buildClock();
    await clock.sync();
    final corrected = clock.now();
    // Real time passes: monotonic advances 7 minutes. Wall clock spoofed the
    // other way at the same time — must be ignored.
    mono += const Duration(minutes: 7);
    wall = wall.subtract(const Duration(days: 1));
    expect(clock.now(), corrected.add(const Duration(minutes: 7)));
  });

  test('sync corrects for round-trip latency (~half the RTT)', () async {
    syncLatency = const Duration(milliseconds: 400);
    final clock = buildClock();
    await clock.sync();
    // Server sampled its clock mid-flight; the anchor projects it forward by
    // half the 400ms RTT to the moment the response landed.
    expect(clock.now(), serverUtc.add(const Duration(milliseconds: 200)).toLocal());
  });

  test('a failed sync keeps the prior good anchor (no revert to device clock)',
      () async {
    final clock = buildClock();
    await clock.sync();
    final corrected = clock.now();

    // Next sync throws (dropped connection); the anchor must survive.
    final throwing = ServerClock(
      fetch: () async => throw Exception('offline'),
      elapsed: () => mono,
      wallClock: () => wall,
    );
    final ok = await throwing.sync();
    expect(ok, isFalse);
    expect(throwing.hasSynced, isFalse);

    // The original clock is unaffected and still correct despite a spoof.
    wall = wall.add(const Duration(hours: 9));
    expect(clock.now(), corrected);
  });

  test('ensureFresh only re-syncs once the anchor is stale', () async {
    final clock = buildClock();
    await clock.sync();
    expect(fetchCount, 1);
    await clock.ensureFresh(); // fresh → no fetch
    expect(fetchCount, 1);
    mono += const Duration(minutes: 11); // past resyncInterval
    await clock.ensureFresh();
    expect(fetchCount, 2);
  });

  // ---- The gates themselves, driven by the corrected clock ----------------

  test('door policy resists a spoofed device clock', () async {
    // Session opens 4 minutes after the true server time; 5-minute grace.
    final session = ScheduledSession(
      sessionId: 's1',
      subject: 'Maths',
      topic: 'Quadratics',
      tutorName: 'Grandmaster',
      startTime: serverUtc.add(const Duration(minutes: 4)),
      doorCloseSeconds: 300,
    );
    final clock = buildClock();
    await clock.sync();

    // Honest state: the door is not open yet.
    expect(session.doorStateAt(clock.now()), DoorState.beforeOpen);

    // Spoof the device clock 2 hours forward to try to force the door open
    // (and then past it, to "lock" it and dodge attendance). Corrected clock
    // ignores the spoof, so the door stays exactly where it should.
    wall = wall.add(const Duration(hours: 2));
    expect(session.doorStateAt(clock.now()), DoorState.beforeOpen);

    // Real time (monotonic) reaches the open window → door opens honestly.
    mono += const Duration(minutes: 4, seconds: 30);
    expect(session.doorStateAt(clock.now()), DoorState.graceOpen);
  });

  test('skip-gate lock does not release early under a spoofed clock', () async {
    final clock = buildClock();
    await clock.sync();
    final lock = SkipLock(
      sessionId: 's1',
      sessionStart: serverUtc.add(const Duration(minutes: 10)),
    );

    // Honest: session hasn't started, lock is held.
    expect(lock.releasedAt(clock.now()), isFalse);

    // Spoof forward past the session start to try to release the lock early.
    wall = wall.add(const Duration(hours: 1));
    expect(lock.releasedAt(clock.now()), isFalse,
        reason: 'device-clock spoof must not release the lock');

    // Only real elapsed time releases it.
    mono += const Duration(minutes: 10, seconds: 1);
    expect(lock.releasedAt(clock.now()), isTrue);
  });
}
