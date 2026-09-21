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
  final monday9 = DateTime(2026, 7, 20, 9, 0); // a Monday
  final thursday9 = DateTime(2026, 7, 23, 9, 0);

  ScheduledSession session(String id, String tutor, DateTime start,
          {String topic = 'Quadratic equations'}) =>
      ScheduledSession(
        sessionId: id,
        subject: 'Maths',
        topic: topic,
        tutorName: tutor,
        startTime: start,
      );

  test('§9 resolver: next same-topic session by the OTHER tutor', () {
    final sessions = [
      session('g4', 'Grandmaster', monday9),
      session('bj4', 'Big John', thursday9),
      session('bj5', 'Big John', thursday9.add(const Duration(days: 7))),
      session('other', 'Big John', thursday9, topic: 'Factoring'),
    ];
    final alt = TopicLinkResolver.alternateFor(
      sessions,
      subject: 'Maths',
      topic: 'Quadratic equations',
      excludeTutor: 'Grandmaster',
      after: monday9,
    );
    expect(alt?.sessionId, 'bj4', reason: 'earliest alternate wins');
    expect(TopicLinkResolver.noteFor(alt!),
        'Big John covers the same topic Thursday 09:00');
    // No alternate for a topic only one tutor teaches.
    expect(
        TopicLinkResolver.alternateFor(sessions,
            subject: 'Maths',
            topic: 'Factoring',
            excludeTutor: 'Big John',
            after: monday9),
        isNull);
  });

  test('signoff fires the cross-promo; Remind me schedules and closes it',
      () async {
    final engine = _FakeEngine();
    final reminded = <String>[];
    final alt = session('bj4', 'Big John', thursday9);
    final n = LessonNotifier(
      engine: engine,
      sessionId: 'g4',
      crossTutorAlternate: () async => alt,
      onCrossTutorRemind: (s) async => reminded.add(s.sessionId),
    );
    await n.init();
    engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.signoffReached));
    await Future<void>.delayed(Duration.zero);
    expect(n.state.crossPromo?.sessionId, 'bj4');

    await n.remindCrossTutor();
    expect(reminded, ['bj4']);
    expect(n.state.crossPromo, isNull);
    n.dispose();
  });

  test('§9 library: both tutors keep their version of the same topic',
      () async {
    final store = LibraryStore(kv: _MemStore());
    LibraryEntry entry(String id, String tutor, double engagement) =>
        LibraryEntry(
          sessionId: id,
          subject: 'Maths',
          topic: 'Quadratic equations',
          tutorName: tutor,
          attendedAt: monday9,
          recordingAvailableAt: LibraryEntry.defaultRecordingUnlock(monday9),
          engagementScore: engagement,
        );
    await store.recordAttended(entry('g4', 'Grandmaster', 10));
    await store.recordAttended(entry('bj4', 'Big John', 5));
    var entries = await store.load();
    expect(entries, hasLength(2), reason: 'both versions coexist');
    // Within one tutor, higher engagement still replaces.
    await store.recordAttended(entry('g9', 'Grandmaster', 99));
    entries = await store.load();
    expect(entries.map((e) => e.sessionId).toSet(), {'g9', 'bj4'});
  });

  test('engagement aggregate accumulates across sessions', () async {
    final store = ProfileStore(kv: _MemStore());
    await store.recordEngagement(answered: 4, skipped: 1);
    await store.recordEngagement(answered: 2, skipped: 3);
    final (answered, skipped) = await store.engagement();
    expect(answered, 6);
    expect(skipped, 4);
  });
}

class _FakeEngine implements LessonPlaybackEngine {
  final _controller = StreamController<LessonPlaybackEvent>.broadcast();

  void emit(LessonPlaybackEvent e) => _controller.add(e);

  @override
  Future<LessonReadiness> prepare(String sessionId) async =>
      const LessonReadiness(isReady: true);

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
