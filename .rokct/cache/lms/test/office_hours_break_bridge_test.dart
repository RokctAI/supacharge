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
// src-path imports (not the lms_sdk barrel) — same pattern as replay_sdk's
// audio_sync_events_test: the barrel drags in presentation widgets whose
// composer-injected TrKeys members only exist in a composed host app.
import 'package:lms_sdk/src/common/application/lesson/lesson_notifier.dart';
import 'package:lms_sdk/src/common/controllers/break_bridge.dart';
import 'package:lms_sdk/src/common/controllers/office_hours.dart';
import 'package:lms_sdk/src/common/domain/interface/assistant_bridge.dart';
import 'package:lms_sdk/src/common/domain/interface/lesson_playback_engine.dart';
import 'package:lms_sdk/src/common/domain/interface/subscription_status_provider.dart';
import 'package:lms_sdk/src/common/domain/models/lesson_models.dart';

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

/// Chat lane stand-in: available, records sends, replies with nothing.
class _SilentAssistant implements LessonAssistantBridge {
  final sent = <String>[];
  final _out = StreamController<LessonChatMessage>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Stream<LessonChatMessage> get messages => _out.stream;

  @override
  Future<void> sendMessage(String text) async => sent.add(text);
}

class _RecordingVectorCache implements VectorDatabase {
  final queries = <String>[];
  final String? cannedHit;

  _RecordingVectorCache({this.cannedHit});

  @override
  Future<String?> searchSimilarity(String queryText, double threshold) async {
    queries.add(queryText);
    return cannedHit;
  }
}

class _AlwaysSubscribed implements SubscriptionStatusProvider {
  @override
  Future<bool> hasActiveSubscription(String studentId) async => true;
}

class _WeakConceptTitles implements UsersSDKInterface {
  List<String>? lastRefs;

  @override
  Future<List<String>> getWeakConcepts(
      String sessionId, List<String> subtopicRefs) async {
    lastRefs = subtopicRefs;
    return subtopicRefs.map((r) => r.replaceAll('_', ' ')).toList();
  }
}

void main() {
  test(
      'breakStarted loads the break bridge with the track refs; chat during '
      'the break runs through it and the answer lands in the lane; the lane '
      'reverts when the beats finish', () async {
    final engine = _FakeEngine();
    final assistant = _SilentAssistant();
    // Cache always misses, so the backend fallback records what the bridge
    // was primed with (subtopic ref from the track event, student profile
    // from the notifier).
    final cache = _RecordingVectorCache();
    final backendCalls = <List<String>>[];
    final bridge = BreakBridgeController(
      localCacheDb: cache,
      backendSynthesizeFn: (profile, subtopic, question) async {
        backendCalls.add([profile, subtopic, question]);
        return 'synthesized: factor first';
      },
    );
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: assistant,
      breakBridge: bridge,
      studentProfileRef: 'student-1',
    );
    await notifier.init();
    expect(notifier.state.chatAvailable, isTrue);

    engine.emit(const LessonPlaybackEvent(
      LessonPlaybackEventType.breakStarted,
      subtopicRef: 'factoring_method',
      contextTranscriptRef: 'transcripts/factoring.md',
      breakQuestions: [
        BreakQuestion(
            question: 'Why factor?', askSeconds: 0.05, answerSeconds: 0.05),
      ],
      breakSeconds: 60,
    ));
    await Future<void>.delayed(Duration.zero);

    await notifier.sendChatMessage('how do I factor this?');
    expect(cache.queries, ['how do I factor this?']);
    expect(backendCalls, [
      ['student-1', 'factoring_method', 'how do I factor this?'],
    ]);
    expect(notifier.state.chatMessages.last.fromStudent, isFalse);
    expect(notifier.state.chatMessages.last.text, 'synthesized: factor first');
    // The live assistant lane was bypassed during the break.
    expect(assistant.sent, isEmpty);

    // Beats finish (~0.1s scripted above) -> bridge closes, lane reverts.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await notifier.sendChatMessage('and after the break?');
    expect(assistant.sent, ['and after the break?']);
    expect(cache.queries, hasLength(1));

    notifier.dispose();
  });

  test(
      'a closed break bridge answers with the back-to-lesson line instead of '
      'hitting cache or backend', () async {
    final cache = _RecordingVectorCache(cannedHit: 'should never surface');
    final bridge = BreakBridgeController(
      localCacheDb: cache,
      backendSynthesizeFn: (p, s, q) async => 'nor this',
    );
    final answer = await bridge.askQuestion('late question', 'student-1');
    expect(answer, "The break is over, let's get back to the lesson!");
    expect(cache.queries, isEmpty);
  });

  test(
      'live completion enters office hours: weak MCQ subtopics reach the '
      'controller, the greeting rides the chat lane, and the follow-up '
      'revision task is created', () async {
    final engine = _FakeEngine();
    final assistant = _SilentAssistant();
    final users = _WeakConceptTitles();
    final tasks = <String>[];
    OfficeHoursController? built;
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: assistant,
      officeHoursBuilder: (
              {required onMessageReceived, required onSessionClosed}) =>
          built = OfficeHoursController(
        studentId: 'student-1',
        onMessageReceived: onMessageReceived,
        onSessionClosed: onSessionClosed,
        usersSdk: users,
        subscriptionStatusProvider: _AlwaysSubscribed(),
        createProductivityTask: (title, desc) => tasks.add(title),
        assistantDisplayName: 'Mandy',
      ),
    );
    await notifier.init();

    // One wrong answer marks its subtopic weak.
    const mcq = McqQuestion(
      id: 'q1',
      prompt: 'x?',
      options: ['1', '2'],
      correctIndex: 1,
      timeLimitSeconds: 30,
    );
    engine.emit(const LessonPlaybackEvent(
      LessonPlaybackEventType.subtopicBoundary,
      subtopicRef: 'quadratic_formula',
      mcqBatch: [mcq],
    ));
    await Future<void>.delayed(Duration.zero);
    notifier.answerMcq(0); // incorrect
    await Future<void>.delayed(const Duration(seconds: 3));

    engine.emit(const LessonPlaybackEvent(LessonPlaybackEventType.completed));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(notifier.state.officeHoursActive, isTrue);
    expect(notifier.state.chatOpen, isTrue);
    expect(users.lastRefs, ['quadratic_formula']);
    expect(tasks, ['Review quadratic formula']);
    final greeting = notifier.state.chatMessages.last;
    expect(greeting.fromStudent, isFalse);
    expect(greeting.text, contains('quadratic formula'));
    expect(built, isNotNull);

    notifier.dispose();
  });

  test('office hours never start on a library rewatch (live-only)', () async {
    final engine = _FakeEngine();
    final assistant = _SilentAssistant();
    var builderCalled = false;
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: assistant,
      isRecording: true,
      officeHoursBuilder: (
          {required onMessageReceived, required onSessionClosed}) {
        builderCalled = true;
        return OfficeHoursController(
          studentId: 'student-1',
          onMessageReceived: onMessageReceived,
          onSessionClosed: onSessionClosed,
          usersSdk: _WeakConceptTitles(),
          subscriptionStatusProvider: _AlwaysSubscribed(),
          createProductivityTask: (t, d) {},
        );
      },
    );
    await notifier.init();
    engine.emit(const LessonPlaybackEvent(LessonPlaybackEventType.completed));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(builderCalled, isFalse);
    expect(notifier.state.officeHoursActive, isFalse);
    notifier.dispose();
  });
}
