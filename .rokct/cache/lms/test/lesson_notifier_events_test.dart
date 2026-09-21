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

/// Fake engine standing in for the host's ReplayLessonEngine adapter —
/// verifies the event chain from LessonPlaybackEngine.events through the
/// notifier to the MCQ overlay's trigger state without needing replay_sdk
/// (ADR-005: this package never imports it).
class _FakeEngine implements LessonPlaybackEngine {
  final _controller = StreamController<LessonPlaybackEvent>.broadcast();
  bool started = false;
  int pauses = 0;
  int resumes = 0;

  void emit(LessonPlaybackEvent e) => _controller.add(e);

  @override
  Future<LessonReadiness> prepare(String sessionId) async =>
      const LessonReadiness(isReady: true);

  @override
  Future<void> start() async => started = true;

  @override
  Stream<LessonPlaybackEvent> get events => _controller.stream;

  @override
  void pause() => pauses++;

  @override
  void primeTo(double toSeconds) {}

  @override
  void playStandingClip(String ref) {}

  @override
  void resumeAtLivePosition() {}

  @override
  void resume() => resumes++;

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  test(
      'subtopicBoundary with an MCQ batch pauses playback and raises the '
      'overlay; answering advances and resumes', () async {
    final engine = _FakeEngine();
    final notifier = LessonNotifier(engine: engine, sessionId: 's1');
    await notifier.init();
    expect(engine.started, isTrue);
    expect(notifier.state.playing, isTrue);

    const mcq = McqQuestion(
      id: 'q1',
      prompt: 'What is x?',
      options: ['1', '2'],
      correctIndex: 1,
      timeLimitSeconds: 10,
    );
    engine.emit(const LessonPlaybackEvent(
      LessonPlaybackEventType.subtopicBoundary,
      subtopicRef: 'r1',
      mcqBatch: [mcq],
    ));
    await Future<void>.delayed(Duration.zero);

    // The overlay trigger: activeMcq set, playback paused, chat collapsed.
    expect(notifier.state.activeMcq?.id, 'q1');
    expect(notifier.state.mcqRemainingSeconds, 10);
    expect(engine.pauses, 1);
    expect(notifier.state.chatOpen, isFalse);

    notifier.answerMcq(1);
    expect(notifier.state.mcqLocked, isTrue);
    expect(notifier.state.mcqResults.single.outcome, McqOutcome.correct);

    // After the reveal beat the queue empties and playback resumes.
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(notifier.state.activeMcq, isNull);
    expect(engine.resumes, 1);
    expect(notifier.state.playing, isTrue);

    notifier.dispose();
  });

  test('speaking events drive the tutor presence flag; completion lands',
      () async {
    final engine = _FakeEngine();
    final notifier = LessonNotifier(engine: engine, sessionId: 's1');
    await notifier.init();

    engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.speakingStarted));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.tutorSpeaking, isTrue);

    engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.speakingStopped));
    engine.emit(
        const LessonPlaybackEvent(LessonPlaybackEventType.completed));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.tutorSpeaking, isFalse);
    expect(notifier.state.completed, isTrue);

    notifier.dispose();
  });
}
