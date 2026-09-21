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


import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
import 'package:lms_sdk/src/common/application/schedule/schedule_notifier.dart'
    show ScheduleStore;

void main() {
  final attended = DateTime(2026, 7, 20, 15, 0);

  LibraryEntry entry({
    String id = 's1',
    String topic = 'Quadratics',
    bool isAttended = true,
    double engagement = 0,
    DateTime? at,
  }) =>
      LibraryEntry(
        sessionId: id,
        subject: 'Maths',
        topic: topic,
        tutorName: 'Grandmaster',
        attendedAt: at ?? attended,
        recordingAvailableAt:
            LibraryEntry.defaultRecordingUnlock(at ?? attended),
        attended: isAttended,
        engagementScore: engagement,
      );

  test('recording unlocks the following day (§2)', () {
    final e = entry();
    expect(e.recordingAvailable(DateTime(2026, 7, 20, 23, 59)), isFalse);
    expect(e.recordingAvailable(DateTime(2026, 7, 21, 0, 1)), isTrue);
  });

  test(
      'recording-unlock gate reads the notifier clock, so a spoofed device '
      'clock cannot unlock a recording early', () async {
    final e = entry(); // unlocks midnight after 2026-07-20
    // True server time is still the afternoon of the attend day → locked.
    final serverUtc = DateTime(2026, 7, 20, 15, 0).toUtc();
    var wall = serverUtc.toLocal().add(const Duration(hours: 12)); // spoofed
    var mono = const Duration(seconds: 0);
    final clock = ServerClock(
      fetch: () async => serverUtc,
      elapsed: () => mono,
      wallClock: () => wall,
    );
    final n = LibraryNotifier(
      store: LibraryStore(kv: _MemStore()),
      accessSource: _FixedAccess(
          const AccessStatus(subscription: SubscriptionState.active)),
      clock: clock, // no `now` → gate reads the corrected clock
    );
    await n.init(); // syncs

    // The page gates on notifier.now(); honestly still locked.
    expect(e.recordingAvailable(n.now()), isFalse);

    // Spoof the device clock a full day forward to force the unlock — the
    // corrected clock ignores it, so the recording stays locked.
    wall = wall.add(const Duration(days: 1));
    expect(e.recordingAvailable(n.now()), isFalse,
        reason: 'device-clock spoof must not unlock the recording');

    // Real elapsed time crossing midnight unlocks it honestly.
    mono += const Duration(hours: 9, minutes: 1); // 15:00 + 9h01 → next day
    expect(e.recordingAvailable(n.now()), isTrue);
    n.dispose();
  });

  test('§6 update logic: higher-engagement session replaces same topic only',
      () {
    final old = entry(id: 'a', engagement: 10);
    expect(
        LibraryUpdatePolicy.shouldReplace(old, entry(id: 'b', engagement: 20)),
        isTrue);
    expect(
        LibraryUpdatePolicy.shouldReplace(old, entry(id: 'c', engagement: 5)),
        isFalse);
    expect(
        LibraryUpdatePolicy.shouldReplace(
            old, entry(id: 'd', topic: 'Factoring', engagement: 99)),
        isFalse,
        reason: 'different topic never replaces');
  });

  test('store: rewatch bumps count; better session replaces topic recording',
      () async {
    final store = LibraryStore(kv: _MemStore());
    await store.recordAttended(entry(id: 'a', engagement: 10));
    await store.recordAttended(entry(id: 'a')); // rewatch
    var entries = await store.load();
    expect(entries.single.watchCount, 1);

    // Same topic, better session → replaces; worse → ignored.
    await store.recordAttended(entry(id: 'b', engagement: 50));
    entries = await store.load();
    expect(entries.single.sessionId, 'b');
    await store.recordAttended(entry(id: 'c', engagement: 1));
    entries = await store.load();
    expect(entries.single.sessionId, 'b');
  });

  group('access rules come from AccessPolicy (P2), not re-derived', () {
    Future<LibraryNotifier> build(AccessStatus status,
        {List<LibraryEntry> seed = const []}) async {
      final store = LibraryStore(kv: _MemStore());
      for (final e in seed) {
        await store.recordAttended(e);
      }
      final n = LibraryNotifier(
        store: store,
        accessSource: _FixedAccess(status),
      );
      await n.init();
      return n;
    }

    final seed = [
      entry(id: 'mine', topic: 'Quadratics'),
      entry(id: 'new1', topic: 'Factoring', isAttended: false),
    ];

    test('active sees attended AND library-new entries', () async {
      final n = await build(
          const AccessStatus(subscription: SubscriptionState.active),
          seed: seed);
      expect(n.state.visible.map((e) => e.sessionId).toSet(),
          {'mine', 'new1'});
      n.dispose();
    });

    test('lapsed keeps what they earned — attended only', () async {
      final n = await build(
          const AccessStatus(subscription: SubscriptionState.lapsed),
          seed: seed);
      expect(n.state.accessBlocked, isFalse);
      expect(n.state.visible.map((e) => e.sessionId).toList(), ['mine']);
      n.dispose();
    });

    test('never-subscribed has no library', () async {
      final n = await build(AccessStatus.guest, seed: seed);
      expect(n.state.accessBlocked, isTrue);
      expect(n.state.visible, isEmpty);
      n.dispose();
    });
  });

  group('lesson gate for recordings', () {
    test('lapsed student can open a library recording (isRecording gate)',
        () async {
      final engine = _FakeEngine();
      final n = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        isRecording: true,
        accessSource: _FixedAccess(
            const AccessStatus(subscription: SubscriptionState.lapsed)),
      );
      await n.init();
      expect(n.state.accessBlocked, isFalse);
      expect(engine.prepared, isTrue);
      n.dispose();
    });

    test('guest still cannot open recordings', () async {
      final engine = _FakeEngine();
      final n = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        isRecording: true,
        accessSource: _FixedAccess(AccessStatus.guest),
      );
      await n.init();
      expect(n.state.accessBlocked, isTrue);
      expect(engine.prepared, isFalse);
      n.dispose();
    });
  });
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;
  _FixedAccess(this.status);

  @override
  Future<AccessStatus> current() async => status;
}

class _MemStore implements ScheduleStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> get(String collection, String key) async =>
      _data['$collection/$key'];

  @override
  Future<void> put(
          String collection, String key, Map<String, dynamic> value) async =>
      _data['$collection/$key'] = value;
}

class _FakeEngine implements LessonPlaybackEngine {
  final _controller = StreamController<LessonPlaybackEvent>.broadcast();
  bool prepared = false;

  @override
  Future<LessonReadiness> prepare(String sessionId) async {
    prepared = true;
    return const LessonReadiness(isReady: true);
  }

  @override
  Future<void> start() async {}

  @override
  Stream<LessonPlaybackEvent> get events => _controller.stream;

  @override
  void pause() {}

  @override
  void primeTo(double toSeconds) {}

  @override
  void playStandingClip(String ref) {}

  @override
  void resumeAtLivePosition() {}

  @override
  void resume() {}

  @override
  void dispose() {
    _controller.close();
  }
}
