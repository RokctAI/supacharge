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
// src-path imports (not the lms_sdk barrel) — same pattern as
// office_hours_break_bridge_test: the barrel drags in presentation widgets
// whose composer-injected TrKeys members only exist in a composed host.
import 'package:lms_sdk/src/common/application/lesson/lesson_notifier.dart';
import 'package:lms_sdk/src/common/domain/interface/assistant_bridge.dart';
import 'package:lms_sdk/src/common/domain/interface/assistant_chat_plan_gate.dart';
import 'package:lms_sdk/src/common/domain/interface/lesson_playback_engine.dart';
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

class _FixedPlanGate implements AssistantChatPlanGate {
  final bool allowed;
  const _FixedPlanGate(this.allowed);

  @override
  Future<bool> allowsAssistantChat() async => allowed;
}

class _ThrowingPlanGate implements AssistantChatPlanGate {
  @override
  Future<bool> allowsAssistantChat() async =>
      throw StateError('entitlements unreachable');
}

void main() {
  test('plan gate: a plan without chat disables the lane and blocks sends',
      () async {
    final engine = _FakeEngine();
    final assistant = _SilentAssistant();
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: assistant,
      chatPlanGate: const _FixedPlanGate(false),
    );
    await notifier.init();

    expect(notifier.state.chatPlanBlocked, isTrue);
    // The lane itself stays "available" (office hours gating untouched) —
    // the composer honours the combined verdict.
    expect(notifier.state.chatAvailable, isTrue);
    expect(notifier.state.chatInputEnabled, isFalse);

    await notifier.sendChatMessage('can you help?');
    expect(assistant.sent, isEmpty);
    expect(notifier.state.chatMessages, isEmpty);

    notifier.dispose();
  });

  test('plan gate: allowed plan and no gate both leave chat on', () async {
    for (final gate in [const _FixedPlanGate(true), null]) {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        assistant: _SilentAssistant(),
        chatPlanGate: gate,
      );
      await notifier.init();
      expect(notifier.state.chatPlanBlocked, isFalse);
      notifier.dispose();
    }
  });

  test('plan gate fails OPEN: a throwing gate never switches chat off',
      () async {
    final engine = _FakeEngine();
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: _SilentAssistant(),
      chatPlanGate: _ThrowingPlanGate(),
    );
    await notifier.init();
    expect(notifier.state.chatPlanBlocked, isFalse);
    notifier.dispose();
  });

  test('phase gate: the intro window holds chat until a teaching signal',
      () async {
    final engine = _FakeEngine();
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: _SilentAssistant(),
    );
    await notifier.init();

    // Playback started -> intro window running, chat held.
    expect(kLessonIntroWindow, const Duration(minutes: 5));
    expect(notifier.state.introActive, isTrue);
    expect(notifier.state.chatPhaseOpen, isFalse);
    expect(notifier.state.chatInputEnabled, isFalse);

    // First subtopic boundary proves teaching is underway — chat opens
    // while the tutor is teaching.
    engine.emit(const LessonPlaybackEvent(
      LessonPlaybackEventType.subtopicBoundary,
      subtopicRef: 'r1',
    ));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.introActive, isFalse);
    expect(notifier.state.chatPhaseOpen, isTrue);
    expect(notifier.state.chatInputEnabled, isTrue);

    notifier.dispose();
  });

  test('phase gate: chat holds for the whole break and reopens after',
      () async {
    final engine = _FakeEngine();
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: _SilentAssistant(),
    );
    await notifier.init();

    engine.emit(const LessonPlaybackEvent(
      LessonPlaybackEventType.breakStarted,
      breakQuestions: [
        BreakQuestion(
            question: 'Why factor?', askSeconds: 0.05, answerSeconds: 0.05),
      ],
      breakSeconds: 60,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.breakActive, isTrue);
    expect(notifier.state.chatPhaseOpen, isFalse);

    // Mid-break the tutor answers the beat (speakingRole flips to tutor)
    // but the break itself still holds chat.
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(notifier.state.breakAsking, isFalse);
    expect(notifier.state.chatPhaseOpen, isFalse);

    // Beats finish -> break over, part two's tutor teaching, chat open.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(notifier.state.breakActive, isFalse);
    expect(notifier.state.chatPhaseOpen, isTrue);

    notifier.dispose();
  });

  test('phase gate: a beat-less break ends on its own clock', () async {
    final engine = _FakeEngine();
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: _SilentAssistant(),
    );
    await notifier.init();

    engine.emit(const LessonPlaybackEvent(
      LessonPlaybackEventType.breakStarted,
      breakSeconds: 0.1,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.breakActive, isTrue);
    expect(notifier.state.chatPhaseOpen, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(notifier.state.breakActive, isFalse);

    notifier.dispose();
  });

  test('phase gate: completion opens the lane (office hours ride it)',
      () async {
    final engine = _FakeEngine();
    final notifier = LessonNotifier(
      engine: engine,
      sessionId: 's1',
      assistant: _SilentAssistant(),
    );
    await notifier.init();
    expect(notifier.state.chatPhaseOpen, isFalse); // intro window

    engine.emit(const LessonPlaybackEvent(LessonPlaybackEventType.completed));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.completed, isTrue);
    expect(notifier.state.chatPhaseOpen, isTrue);

    notifier.dispose();
  });
}
