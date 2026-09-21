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

/// The Access Control Matrix from supacharge-business.md §3, row by row.
void main() {
  const active = AccessStatus(subscription: SubscriptionState.active);
  const lapsed = AccessStatus(subscription: SubscriptionState.lapsed);
  const guest = AccessStatus.guest;
  const withPartner =
      AccessStatus(subscription: SubscriptionState.active, hasPartner: true);

  test('matrix: subscription-gated capabilities', () {
    for (final cap in [
      LessonCapability.liveSessions,
      LessonCapability.libraryNew,
      LessonCapability.assistant,
      LessonCapability.homeworkTool,
    ]) {
      expect(AccessPolicy.allows(active, cap), isTrue, reason: '$cap active');
      expect(AccessPolicy.allows(lapsed, cap), isFalse, reason: '$cap lapsed');
      expect(AccessPolicy.allows(guest, cap), isFalse, reason: '$cap guest');
    }
  });

  test('matrix: lapsed students keep what they earned', () {
    expect(AccessPolicy.allows(active, LessonCapability.libraryAttended),
        isTrue);
    expect(AccessPolicy.allows(lapsed, LessonCapability.libraryAttended),
        isTrue);
    // Never-subscribed has no earned library.
    expect(
        AccessPolicy.allows(guest, LessonCapability.libraryAttended), isFalse);
  });

  test('discounted rate gates on the student having a partner', () {
    expect(AccessPolicy.allows(withPartner, LessonCapability.discountedRate),
        isTrue);
    expect(AccessPolicy.allows(active, LessonCapability.discountedRate),
        isFalse);
  });

  test('partner dashboard/reports are the partner role only, never a student',
      () {
    // A student — even one WITH a partner attached — never views the partner
    // dashboard; that surface belongs to the partner account (P3).
    for (final cap in [
      LessonCapability.partnerDashboard,
      LessonCapability.weeklyReports,
    ]) {
      expect(AccessPolicy.allows(withPartner, cap), isFalse);
      expect(AccessPolicy.allows(AccessStatus.partner, cap), isTrue);
    }
  });

  group('LessonNotifier gating', () {
    test('lapsed student is blocked from a live session before prepare runs',
        () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        accessSource: _FixedAccess(lapsed),
      );
      await notifier.init();
      expect(notifier.state.accessBlocked, isTrue);
      expect(engine.prepared, isFalse, reason: 'gate fires before prepare');
      notifier.dispose();
    });

    test('sample lessons bypass the live-session gate but not the Mandy gate',
        () async {
      final engine = _FakeEngine();
      final bridge = _FakeBridge();
      final notifier = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        isSample: true,
        assistant: bridge,
        accessSource: _FixedAccess(guest),
      );
      await notifier.init();
      expect(notifier.state.accessBlocked, isFalse);
      expect(engine.prepared, isTrue);
      // Mandy row: guests/lapsed get no chat even on free samples.
      expect(notifier.state.chatAvailable, isFalse);
      notifier.dispose();
    });

    test('active subscriber passes both gates', () async {
      final engine = _FakeEngine();
      final bridge = _FakeBridge();
      final notifier = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        assistant: bridge,
        accessSource: _FixedAccess(active),
      );
      await notifier.init();
      expect(notifier.state.accessBlocked, isFalse);
      expect(notifier.state.chatAvailable, isTrue);
      notifier.dispose();
    });

    test('a throwing access source fails closed', () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        accessSource: _ThrowingAccess(),
      );
      await notifier.init();
      expect(notifier.state.accessBlocked, isTrue);
      notifier.dispose();
    });
  });
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;
  _FixedAccess(this.status);

  @override
  Future<AccessStatus> current() async => status;
}

class _ThrowingAccess implements AccessStatusSource {
  @override
  Future<AccessStatus> current() async => throw StateError('offline');
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

class _FakeBridge implements LessonAssistantBridge {
  final _messages = StreamController<LessonChatMessage>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Stream<LessonChatMessage> get messages => _messages.stream;

  @override
  Future<void> sendMessage(String text) async {}
}
