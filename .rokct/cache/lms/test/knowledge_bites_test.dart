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
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// Decision #52's app-side contract, pinned:
///   * index parse — the REAL generated shape (`{"bites": {lesson_slug:
///     [{bite}]}}`, content from the factory's rehoused tree, verbatim);
///   * source fallback — backend miss falls through to the asset copy,
///     empty is never cached as an answer;
///   * offer eligibility — opt-in only, one deterministic bite per lesson,
///     never re-offered once accepted, sitting-scoped decline;
///   * persistence round-trip — accepted bites survive storage with their
///     full content (the offline-forever Library payoff).

/// A real bite, verbatim from
/// `factory/lessons/curriculum/CAPS/maths/knowledge_bites/grade11/
/// lines-gradients-and-inclination/dbe-maths-g12-p2-2025-nov-q3-1/
/// question.md` — the parse test must hold against what the generator
/// actually emits, not a toy.
const _realQuestionMd = '''
# Past-Paper Worked Example — Q3.1

**Source:** Department of Basic Education — Grade 12 Maths P2, November 2025, question Q3.1.

**© Department of Basic Education, 2025. Reproduced for educational use with attribution.**

## Question (2 marks)

In the diagram, P(-1 ; 8), Q(-4 ; -6) and R(12 ; 2) are the vertices of ΔPQR. The angle of inclination of QR is θ. Calculate the length of QR. Leave your answer in simplified surd form.

## Method

distance formula

## Memo working

Apply the distance formula to Q(-4 ; -6) and R(12 ; 2): QR = sqrt((-4 - 12)^2 + (-6 - 2)^2) = sqrt(256 + 64) = √320 = 8√5.

## Answer (per marking guidelines)

QR = √320 = 8√5 units
''';

final Map<String, dynamic> _realIndex = {
  'bites': {
    'lines-gradients-and-inclination': [
      {
        'bite_slug': 'dbe-maths-g12-p2-2025-nov-q3-1',
        'subject': 'maths',
        'grade': 11,
        'title': 'Past-Paper Worked Example — Q3.1',
        'question_md': _realQuestionMd,
      },
    ],
  },
};

KnowledgeBite _bite({
  String lessonSlug = 'lines-gradients-and-inclination',
  String biteSlug = 'dbe-maths-g12-p2-2025-nov-q3-1',
}) =>
    KnowledgeBite(
      lessonSlug: lessonSlug,
      biteSlug: biteSlug,
      subject: 'maths',
      grade: 11,
      title: 'Past-Paper Worked Example — Q3.1',
      questionMd: _realQuestionMd,
    );

void main() {
  group('KnowledgeBiteIndex.parse (generated-file contract)', () {
    test('parses the real generated shape', () {
      final index = KnowledgeBiteIndex.parse(_realIndex);
      final bites = index.bitesFor('lines-gradients-and-inclination');
      expect(bites, hasLength(1));
      final bite = bites.single;
      expect(bite.biteSlug, 'dbe-maths-g12-p2-2025-nov-q3-1');
      expect(bite.subject, 'maths');
      expect(bite.grade, 11);
      expect(bite.title, 'Past-Paper Worked Example — Q3.1');
      expect(bite.questionMd, contains('**Source:** Department of Basic'));
      expect(bite.questionMd, contains('## Memo working'));
    });

    test('unknown lesson slug answers empty, never throws', () {
      final index = KnowledgeBiteIndex.parse(_realIndex);
      expect(index.bitesFor('some-other-lesson'), isEmpty);
    });

    test('malformed documents degrade to empty (tolerant parse)', () {
      expect(KnowledgeBiteIndex.parse(const {}).isEmpty, isTrue);
      expect(KnowledgeBiteIndex.parse(const {'bites': 7}).isEmpty, isTrue);
      // Skills-index granularity (slug -> object, not list) is dropped.
      final wrongGranularity = KnowledgeBiteIndex.parse(const {
        'bites': {'a-lesson': {'bite_slug': 'x'}},
      });
      expect(wrongGranularity.isEmpty, isTrue);
      // Entries without a bite_slug are dropped; valid siblings survive.
      final partial = KnowledgeBiteIndex.parse(const {
        'bites': {
          'a-lesson': [
            {'title': 'no slug'},
            {'bite_slug': 'ok'},
          ],
        },
      });
      expect(partial.bitesFor('a-lesson').single.biteSlug, 'ok');
    });

    test('accepted-bite record round-trips through JSON with full content',
        () {
      final accepted = AcceptedKnowledgeBite(
        bite: _bite(),
        sessionId: 'sess-1',
        lessonId: 'LESSON-0001',
        acceptedAt: DateTime(2026, 8, 13, 19, 30),
      );
      final restored = AcceptedKnowledgeBite.fromJson(
          jsonDecode(jsonEncode(accepted.toJson())) as Map<String, dynamic>);
      expect(restored, isNotNull);
      expect(restored!.sessionId, 'sess-1');
      expect(restored.lessonId, 'LESSON-0001');
      expect(restored.acceptedAt, DateTime(2026, 8, 13, 19, 30));
      expect(restored.bite.lessonSlug, 'lines-gradients-and-inclination');
      expect(restored.bite.questionMd, _realQuestionMd);
    });
  });

  group('lesson-slug derivation (the documented correctable join key)', () {
    test('matches the content tree\'s directory naming', () {
      expect(lessonSlugFromName('Lines, gradients and inclination'),
          'lines-gradients-and-inclination');
      expect(lessonSlugFromName('Quadratics by factorisation'),
          'quadratics-by-factorisation');
      expect(lessonSlugFromName('  The cosine rule & 2D problems  '),
          'the-cosine-rule-2d-problems');
      expect(lessonSlugFromName(''), '');
    });
  });

  group('KnowledgeBiteOfferPolicy (offer eligibility)', () {
    test('offers the first bite by slug order, deterministically', () {
      final offer = KnowledgeBiteOfferPolicy.chooseOffer(
        bites: [_bite(biteSlug: 'z-later'), _bite(biteSlug: 'a-first')],
        alreadyAccepted: false,
        declinedThisSitting: false,
      );
      expect(offer?.biteSlug, 'a-first');
    });

    test('never offers once accepted (it is already in the Library)', () {
      expect(
        KnowledgeBiteOfferPolicy.chooseOffer(
          bites: [_bite()],
          alreadyAccepted: true,
          declinedThisSitting: false,
        ),
        isNull,
      );
    });

    test('sitting-scoped decline suppresses the offer', () {
      expect(
        KnowledgeBiteOfferPolicy.chooseOffer(
          bites: [_bite()],
          alreadyAccepted: false,
          declinedThisSitting: true,
        ),
        isNull,
      );
    });

    test('no bites, no offer', () {
      expect(
        KnowledgeBiteOfferPolicy.chooseOffer(
          bites: const [],
          alreadyAccepted: false,
          declinedThisSitting: false,
        ),
        isNull,
      );
    });
  });

  group('BackendKnowledgeBiteSource (backend-first, asset fallback)', () {
    test('backend unavailable → the fallback answers', () async {
      // No HttpService is registered in a test env, so the backend path
      // throws inside the source's guard — exactly the production failure
      // it must degrade through.
      final source = BackendKnowledgeBiteSource(fallback: _FixedSource());
      final bites =
          await source.bitesFor('lines-gradients-and-inclination');
      expect(bites.single.biteSlug, 'dbe-maths-g12-p2-2025-nov-q3-1');
    });

    test('backend unavailable and no fallback → empty, never an error',
        () async {
      final source = BackendKnowledgeBiteSource();
      expect(await source.bitesFor('lines-gradients-and-inclination'),
          isEmpty);
    });
  });

  group('KnowledgeBiteStore (acceptance persistence)', () {
    test('round-trips an acceptance and answers isAccepted', () async {
      final store = KnowledgeBiteStore(kv: _MemStore());
      expect(
          await store.isAccepted('lines-gradients-and-inclination'), isFalse);
      await store.accept(AcceptedKnowledgeBite(
        bite: _bite(),
        sessionId: 'sess-1',
        acceptedAt: DateTime(2026, 8, 13),
      ));
      expect(
          await store.isAccepted('lines-gradients-and-inclination'), isTrue);
      final loaded = await store.load();
      expect(loaded.single.bite.questionMd, _realQuestionMd);
    });

    test('acceptance is permanent — a re-accept never duplicates or edits',
        () async {
      final store = KnowledgeBiteStore(kv: _MemStore());
      await store.accept(AcceptedKnowledgeBite(
        bite: _bite(),
        sessionId: 'sess-1',
        acceptedAt: DateTime(2026, 8, 13),
      ));
      await store.accept(AcceptedKnowledgeBite(
        bite: _bite(biteSlug: 'another-bite'),
        sessionId: 'sess-2',
        acceptedAt: DateTime(2026, 8, 14),
      ));
      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.sessionId, 'sess-1');
    });
  });

  group('LessonNotifier end-of-playback offer (#52 access model)', () {
    test('offer is resolved at completion and raised as opt-in state',
        () async {
      final engine = _FakeEngine();
      var resolves = 0;
      KnowledgeBite? acceptedBite;
      final n = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        knowledgeBiteOffer: () async {
          resolves++;
          return _bite();
        },
        onKnowledgeBiteAccepted: (b) => acceptedBite = b,
      );
      await n.init();
      // Mid-content moments never raise the offer.
      engine.emit(const LessonPlaybackEvent(
          LessonPlaybackEventType.subtopicBoundary, subtopicRef: 'r1'));
      await Future<void>.delayed(Duration.zero);
      expect(n.state.biteOffer, isNull);

      engine.emit(
          const LessonPlaybackEvent(LessonPlaybackEventType.completed));
      await Future<void>.delayed(Duration.zero);
      expect(n.state.biteOffer?.biteSlug, 'dbe-maths-g12-p2-2025-nov-q3-1');

      // Accept: the persistence hook fires ONCE with the bite; the offer
      // state clears.
      n.acceptBiteOffer();
      expect(acceptedBite?.biteSlug, 'dbe-maths-g12-p2-2025-nov-q3-1');
      expect(n.state.biteOffer, isNull);
      expect(resolves, 1);
      n.dispose();
    });

    test('declining does not re-offer in the same sitting', () async {
      final engine = _FakeEngine();
      var resolves = 0;
      final n = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        knowledgeBiteOffer: () async {
          resolves++;
          return _bite();
        },
      );
      await n.init();
      engine.emit(
          const LessonPlaybackEvent(LessonPlaybackEventType.completed));
      await Future<void>.delayed(Duration.zero);
      expect(n.state.biteOffer, isNotNull);

      n.declineBiteOffer();
      expect(n.state.biteOffer, isNull);

      // A replayed completion in the same sitting must not re-resolve or
      // re-raise (the decline holds until this notifier dies; a FUTURE
      // playback builds a fresh notifier and offers again).
      engine.emit(
          const LessonPlaybackEvent(LessonPlaybackEventType.completed));
      await Future<void>.delayed(Duration.zero);
      expect(n.state.biteOffer, isNull);
      expect(resolves, 1);
      n.dispose();
    });

    test('no resolver wired → completion unchanged (no regression)',
        () async {
      final engine = _FakeEngine();
      final n = LessonNotifier(engine: engine, sessionId: 's1');
      await n.init();
      engine.emit(
          const LessonPlaybackEvent(LessonPlaybackEventType.completed));
      await Future<void>.delayed(Duration.zero);
      expect(n.state.completed, isTrue);
      expect(n.state.biteOffer, isNull);
      n.dispose();
    });

    test('resolver failure degrades to no offer, never an error', () async {
      final engine = _FakeEngine();
      final n = LessonNotifier(
        engine: engine,
        sessionId: 's1',
        knowledgeBiteOffer: () async => throw StateError('backend down'),
      );
      await n.init();
      engine.emit(
          const LessonPlaybackEvent(LessonPlaybackEventType.completed));
      await Future<void>.delayed(Duration.zero);
      expect(n.state.completed, isTrue);
      expect(n.state.biteOffer, isNull);
      n.dispose();
    });
  });

  group('Library attachment (#52: bites ride their lesson, never browse)',
      () {
    test('accepted bite attaches to its session\'s entry via biteFor',
        () async {
      final biteStore = KnowledgeBiteStore(kv: _MemStore());
      await biteStore.accept(AcceptedKnowledgeBite(
        bite: _bite(),
        sessionId: 'sess-1',
        acceptedAt: DateTime(2026, 8, 13),
      ));
      final libStore = LibraryStore(kv: _MemStore());
      final attendedAt = DateTime(2026, 8, 13, 15);
      await libStore.recordAttended(LibraryEntry(
        sessionId: 'sess-1',
        subject: 'Maths',
        topic: 'Analytical geometry',
        tutorName: 'Grandmaster',
        attendedAt: attendedAt,
        recordingAvailableAt: LibraryEntry.defaultRecordingUnlock(attendedAt),
      ));
      final n = LibraryNotifier(store: libStore, bites: biteStore);
      await n.init();
      final entry = n.state.visible.single;
      expect(n.state.biteFor(entry)?.bite.biteSlug,
          'dbe-maths-g12-p2-2025-nov-q3-1');
      n.dispose();
    });

    test('falls back to the lesson-slug join when session ids differ',
        () async {
      final biteStore = KnowledgeBiteStore(kv: _MemStore());
      await biteStore.accept(AcceptedKnowledgeBite(
        bite: _bite(),
        sessionId: 'live-sess',
        acceptedAt: DateTime(2026, 8, 13),
      ));
      final n = LibraryNotifier(
          store: LibraryStore(kv: _MemStore()), bites: biteStore);
      await n.init();
      final attendedAt = DateTime(2026, 8, 13, 15);
      final otherSession = LibraryEntry(
        sessionId: 'other-sess',
        subject: 'Maths',
        // Display name whose slug matches the bite's lesson slug.
        topic: 'Lines, gradients and inclination',
        tutorName: 'Grandmaster',
        attendedAt: attendedAt,
        recordingAvailableAt: LibraryEntry.defaultRecordingUnlock(attendedAt),
      );
      expect(n.state.biteFor(otherSession), isNotNull);
      n.dispose();
    });

    test('entries with no accepted bite show nothing (never pre-listed)',
        () async {
      final n = LibraryNotifier(
          store: LibraryStore(kv: _MemStore()),
          bites: KnowledgeBiteStore(kv: _MemStore()));
      await n.init();
      final attendedAt = DateTime(2026, 8, 13, 15);
      final entry = LibraryEntry(
        sessionId: 'sess-9',
        subject: 'Maths',
        topic: 'Quadratics',
        tutorName: 'Grandmaster',
        attendedAt: attendedAt,
        recordingAvailableAt: LibraryEntry.defaultRecordingUnlock(attendedAt),
      );
      expect(n.state.biteFor(entry), isNull);
      expect(n.state.acceptedBites, isEmpty);
      n.dispose();
    });
  });
}

class _FixedSource implements KnowledgeBiteSource {
  @override
  Future<List<KnowledgeBite>> bitesFor(String lessonSlug) async =>
      KnowledgeBiteIndex.parse(_realIndex).bitesFor(lessonSlug);
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
