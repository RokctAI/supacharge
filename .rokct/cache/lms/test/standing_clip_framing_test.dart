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



// The standing-clip framing beats (decisions #7/#9/#38/#39/#40): the host's
// opening and handover, the timekeeping calls over the tutor, the host's
// sign-off, and the recording-stop beat.
//
// Two halves are pinned here. The manifest vocabulary — the event shapes
// the factory emitter actually writes, copied field-for-field, since a
// near-miss on a name silently no-ops — and the notifier's dispatch of the
// engine events those shapes become. The audio itself belongs to
// replay_sdk's clip channel (ADR-005: this package never imports it).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

class _FakeEngine implements LessonPlaybackEngine {
  final _controller = StreamController<LessonPlaybackEvent>.broadcast();
  bool started = false;
  int pauses = 0;
  int resumes = 0;

  /// Standing clips the NOTIFIER cued (as opposed to the ones a track
  /// event cues inside the engine) — today only `out_of_break`.
  final clipsPlayed = <String>[];

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
  void playStandingClip(String ref) => clipsPlayed.add(ref);

  @override
  void resumeAtLivePosition() {}

  @override
  void resume() => resumes++;

  @override
  void dispose() {
    _controller.close();
  }
}

/// One tick of the microtask queue — the notifier's stream listener runs
/// there, exactly as the other notifier tests wait.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('manifest vocabulary', () {
    test('assistant_opening names its host and both intro variants', () {
      // Byte-for-byte the emitter's shape.
      final event = <String, dynamic>{
        'time': 0,
        'type': 'assistant_opening',
        'assistant': 'assistant_003',
        'estimated_duration_seconds': 300,
        'duration_source': 'estimate',
        'clips': {
          'new': 'assistant_003/intro/new',
          'returning': 'assistant_003/intro/returning',
        },
      };
      expect(manifestFramingAssistantId(event), 'assistant_003');
      expect(manifestClipVariants(event), {
        'new': 'assistant_003/intro/new',
        'returning': 'assistant_003/intro/returning',
      });
    });

    test('handover names the host in `from`, not `assistant`', () {
      final event = <String, dynamic>{
        'time': 0,
        'type': 'handover',
        'from': 'assistant_002',
        'to': 'tutor_007',
      };
      expect(manifestFramingAssistantId(event), 'assistant_002');
    });

    test('a legacy host spelling still resolves to the canonical id', () {
      expect(
        manifestFramingAssistantId({'assistant': 'mandy'}),
        'assistant_003',
      );
      expect(
        manifestFramingAssistantId({'from': 'assistant_g10'}),
        'assistant_001',
      );
    });

    test('every emitted interjection kind parses', () {
      expect(assistantInterjectionKind('five_min_warning'),
          AssistantInterjectionKind.fiveMinWarning);
      expect(assistantInterjectionKind('halfway'),
          AssistantInterjectionKind.halfway);
      expect(assistantInterjectionKind('wrap_up'),
          AssistantInterjectionKind.wrapUp);
      // A call a later emitter adds still plays its clip rather than
      // throwing on the way in.
      expect(assistantInterjectionKind('cheer_up'),
          AssistantInterjectionKind.unknown);
      expect(assistantInterjectionKind(null),
          AssistantInterjectionKind.unknown);
    });

    test('handover states its position with `after`', () {
      // Factory `main` (merged in #133), byte-for-byte: the opening's
      // length is an ESTIMATE until the clip is recorded, so the
      // handover's position cannot be a time.
      final event = <String, dynamic>{
        'time': 0,
        'type': 'handover',
        'after': 'assistant_opening',
        'from': 'assistant_003',
        'to': 'tutor_007',
      };
      expect(manifestEventAfter(event), 'assistant_opening');
      expect(handoverWaitsForOpening(event), isTrue);
    });

    test('a handover with no `after` fires at its own time, as it does today',
        () {
      // The legacy pre-#133 shape, which older manifests still carry:
      // `handover` sits at time 0 beside `assistant_opening` with
      // nothing ordering the two.
      final event = <String, dynamic>{
        'time': 0,
        'type': 'handover',
        'from': 'assistant_003',
        'to': 'tutor_007',
      };
      expect(manifestEventAfter(event), isNull);
      expect(handoverWaitsForOpening(event), isFalse);
      // And a dependency on something else is not this one.
      expect(handoverWaitsForOpening({'after': 'signoff'}), isFalse);
      expect(handoverWaitsForOpening({'after': '  '}), isFalse);
    });

    test('break_start offers the host bridge clips either side of the swap',
        () {
      final event = <String, dynamic>{
        'time': 1440.0,
        'type': 'break_start',
        'duration_seconds': 120,
        'bridge': 'assistant',
        'bridge_id': 'assistant_003',
        'next_tutor': 'tutor_008',
        'clips': {
          'into_break': 'assistant_003/handover/into_break',
          'out_of_break': 'assistant_003/handover/out_of_break',
        },
      };
      expect(manifestBridgeAssistantId(event), 'assistant_003');
      expect(manifestClipVariants(event)['into_break'],
          'assistant_003/handover/into_break');
      expect(manifestClipVariants(event)['out_of_break'],
          'assistant_003/handover/out_of_break');
    });

    test('events carrying no clips read as no clips, never as a failure', () {
      // Every manifest emitted before the framing vocabulary, and every
      // lesson whose grade resolves no host.
      expect(manifestClipVariants({'type': 'profile', 'audio': 'audio.mp3'}),
          isEmpty);
      expect(manifestFramingAssistantId({'type': 'profile'}), isNull);
      expect(manifestClipVariants({'type': 'break_start', 'clips': 'nope'}),
          isEmpty);
    });
  });

  group('opening intro variant', () {
    // The pick the route-shell adapter makes when an `assistant_opening`
    // arrives: the app owns it, because the app is the side that knows the
    // attendance history (decision #39). Until the opening event existed
    // this selector had no caller at all.
    AssistantIntroSelector selectorWith(List<String> priorSessions) =>
        AssistantIntroSelector(
          attendanceHistory: () async => [
            for (final id in priorSessions)
              AttendanceRecord(
                sessionId: id,
                at: DateTime.utc(2026, 7, 1),
                outcome: AttendanceOutcome.attendedOnTime,
              ),
          ],
        );

    test('an empty ledger takes the `new` clip the event offers', () async {
      const variants = {
        'new': 'assistant_003/intro/new',
        'returning': 'assistant_003/intro/returning',
      };
      final variant = await selectorWith(const []).variantForSession('s1');
      expect(variant, IntroVariant.newStudent);
      expect(variants[variant == IntroVariant.returning ? 'returning' : 'new'],
          'assistant_003/intro/new');
    });

    test('a ledger holding only this session still reads as new', () async {
      final variant = await selectorWith(const ['s1']).variantForSession('s1');
      expect(variant, IntroVariant.newStudent);
    });

    test('any prior session takes the `returning` clip', () async {
      const variants = {
        'new': 'assistant_003/intro/new',
        'returning': 'assistant_003/intro/returning',
      };
      final variant =
          await selectorWith(const ['s0']).variantForSession('s1');
      expect(variant, IntroVariant.returning);
      expect(variants[variant == IntroVariant.returning ? 'returning' : 'new'],
          'assistant_003/intro/returning');
    });
  });

  group('notifier dispatch', () {
    test('assistantOpening gives the floor to the host, not the tutor',
        () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();
      // Playback start still assumes the tutor holds the floor (a
      // mid-session join has no opening event to read).
      expect(notifier.state.speakingRole, SpeakingRole.tutor);

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.assistantOpening,
        assistantId: 'assistant_003',
        clipVariants: {
          'new': 'assistant_003/intro/new',
          'returning': 'assistant_003/intro/returning',
        },
      ));
      await _settle();

      expect(notifier.state.speakingRole, SpeakingRole.assistant);
      expect(notifier.state.tutorSpeaking, isFalse);
      expect(notifier.state.introActive, isTrue);

      notifier.dispose();
    });

    test('handoverToTutor ends the opening block and passes the floor',
        () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.assistantOpening,
        assistantId: 'assistant_003',
      ));
      await _settle();
      expect(notifier.state.introActive, isTrue);

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.handoverToTutor,
        assistantId: 'assistant_003',
      ));
      await _settle();

      // Driven by the event now, not by the five-minute timer.
      expect(notifier.state.introActive, isFalse);
      expect(notifier.state.speakingRole, SpeakingRole.tutor);
      expect(notifier.state.tutorSpeaking, isTrue);

      notifier.dispose();
    });

    test('an interjection lights the host without pausing playback', () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.assistantInterjection,
        assistantId: 'assistant_003',
        interjectionKind: AssistantInterjectionKind.fiveMinWarning,
        clipRef: 'assistant_003/timekeeping/five_min_warning',
        ackClipRef: 'tutor_007/acknowledgements/01',
      ));
      await _settle();

      expect(notifier.state.speakingRole, SpeakingRole.assistant);
      // The tutor teaches on through the call — the clip ducks the lesson
      // track rather than pausing it (decision #38).
      expect(notifier.state.playing, isTrue);
      expect(engine.pauses, 0);

      // The tutor's next beat takes the floor straight back.
      engine.emit(const LessonPlaybackEvent(
          LessonPlaybackEventType.speakingStarted));
      await _settle();
      expect(notifier.state.speakingRole, SpeakingRole.tutor);

      notifier.dispose();
    });

    test('assistantSignoff closes on the host', () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.assistantSignoff,
        assistantId: 'assistant_003',
        clipRef: 'assistant_003/signoff/session_end',
      ));
      await _settle();

      expect(notifier.state.speakingRole, SpeakingRole.assistant);
      expect(notifier.state.tutorSpeaking, isFalse);
      expect(notifier.state.recordingStopped, isFalse);

      notifier.dispose();
    });

    test('recordingStopped marks the cut without ending the session',
        () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.recordingStopped,
        assistantId: 'assistant_003',
        clipRef: 'assistant_003/signoff/recording_stopped',
      ));
      await _settle();

      expect(notifier.state.recordingStopped, isTrue);
      // Office hours come AFTER this beat and are live-only — the session
      // is not over, so `completed` must not have fired.
      expect(notifier.state.completed, isFalse);
      expect(notifier.state.speakingRole, SpeakingRole.assistant);

      notifier.dispose();
    });

    test('a handover held back for the opening keeps the host block open',
        () async {
      // What the engine does with `after: "assistant_opening"` (#133): the
      // handover is emitted when the opening's BEAT finishes, not at its
      // own time: 0. Everything in between is still the host's.
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.assistantOpening,
        assistantId: 'assistant_003',
        clipVariants: {'new': 'assistant_003/intro/new'},
      ));
      await _settle();
      expect(notifier.state.introActive, isTrue);

      // The opening's clip is still playing: no handover has arrived, so
      // the block has NOT collapsed and the whiteboard stays shut.
      await _settle();
      expect(notifier.state.introActive, isTrue);
      expect(notifier.state.speakingRole, SpeakingRole.assistant);
      expect(notifier.state.tutorSpeaking, isFalse);

      // The beat ends; the engine releases the handover it was holding.
      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.handoverToTutor,
        assistantId: 'assistant_003',
        afterEvent: 'assistant_opening',
      ));
      await _settle();

      expect(notifier.state.introActive, isFalse);
      expect(notifier.state.speakingRole, SpeakingRole.tutor);
      expect(notifier.state.tutorSpeaking, isTrue);

      notifier.dispose();
    });

    test('the break plays the host back out of it when its beats finish',
        () async {
      // `out_of_break` belongs to the far side of the tutor swap, which no
      // track event marks — the break ends on the notifier's own clock, so
      // the notifier is what cues the clip (decision #9).
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.breakStarted,
        assistantId: 'assistant_003',
        breakQuestions: [
          BreakQuestion(question: 'q', askSeconds: 0.01, answerSeconds: 0.01),
        ],
        clipVariants: {
          'into_break': 'assistant_003/handover/into_break',
          'out_of_break': 'assistant_003/handover/out_of_break',
        },
      ));
      await _settle();
      expect(notifier.state.breakActive, isTrue);
      expect(engine.clipsPlayed, isEmpty,
          reason: 'the line INTO the break is the engine\'s, cued by the '
              'track event itself');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(notifier.state.breakActive, isFalse);
      expect(engine.clipsPlayed, ['assistant_003/handover/out_of_break']);

      notifier.dispose();
    });

    test('a beat-less break still plays the host back out, exactly once',
        () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.breakStarted,
        assistantId: 'assistant_003',
        breakSeconds: 0.05,
        clipVariants: {
          'out_of_break': 'assistant_003/handover/out_of_break',
        },
      ));
      await _settle();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(notifier.state.breakActive, isFalse);
      expect(engine.clipsPlayed, ['assistant_003/handover/out_of_break']);

      // Part two's tutor takes the floor — the catch-all break end. The
      // clip is one-shot, so it does not play a second time.
      engine.emit(const LessonPlaybackEvent(
          LessonPlaybackEventType.speakingStarted));
      await _settle();
      expect(engine.clipsPlayed, ['assistant_003/handover/out_of_break']);

      notifier.dispose();
    });

    test('a break the timers never closed still plays the host back out',
        () async {
      // The break_start shape with neither beats nor a duration: the only
      // thing that ends it is the next tutor taking the floor.
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.breakStarted,
        assistantId: 'assistant_003',
        clipVariants: {
          'out_of_break': 'assistant_003/handover/out_of_break',
        },
      ));
      await _settle();
      expect(notifier.state.breakActive, isTrue);
      expect(engine.clipsPlayed, isEmpty);

      engine.emit(const LessonPlaybackEvent(
          LessonPlaybackEventType.speakingStarted));
      await _settle();
      expect(notifier.state.breakActive, isFalse);
      expect(engine.clipsPlayed, ['assistant_003/handover/out_of_break']);

      notifier.dispose();
    });

    test('a break carrying no bridge clips cues nothing', () async {
      // Every manifest emitted before the bridge clips, and every lesson
      // whose grade resolves no host.
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
        LessonPlaybackEventType.breakStarted,
        breakSeconds: 0.05,
      ));
      await _settle();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(engine.clipsPlayed, isEmpty);

      notifier.dispose();
    });

    test('a session with no framing events behaves exactly as before',
        () async {
      final engine = _FakeEngine();
      final notifier = LessonNotifier(engine: engine, sessionId: 's1');
      await notifier.init();

      engine.emit(const LessonPlaybackEvent(
          LessonPlaybackEventType.speakingStarted));
      await _settle();

      expect(notifier.state.speakingRole, SpeakingRole.tutor);
      expect(notifier.state.recordingStopped, isFalse);

      notifier.dispose();
    });
  });
}
