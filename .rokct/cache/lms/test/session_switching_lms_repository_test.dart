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


// The LMS repository is chosen by the RUNTIME demo session, not by the
// compile-time build flag. A server-marked demo account signs in through the
// real AuthRepository minutes after DI ran, and before this change the
// registration-time decision was already frozen: the schedule, the Board, the
// server clock and tutor discovery all kept calling the backend for that
// session and failed when it was unreachable.
//
// So the assertions are about WHICH side answers, and — for a demo session —
// that the HTTP side is never touched at all. Both fakes throw on any member
// the test did not explicitly wire, so an accidental extra call is a failure
// rather than a silent pass.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/base_sdk.dart'
    show DemoSession, LocalStorage, StorageKeys;

import 'package:lms_sdk/src/common/domain/interface/lms_repository.dart';
import 'package:lms_sdk/src/common/domain/interface/tutor_catalog.dart';
import 'package:lms_sdk/src/common/domain/models/course_models.dart';
import 'package:lms_sdk/src/common/domain/models/tutor_models.dart';
import 'package:lms_sdk/src/common/infrastructure/repositories/session_switching_lms_repository.dart';
import 'package:lms_sdk/src/common/infrastructure/repositories/session_switching_tutor_catalog.dart';

/// Records what it was asked for and answers with values carrying its own
/// [tag], so a test can tell the two sides apart. Anything the test did not
/// wire reaches [noSuchMethod] and throws.
class _RecordingRepository implements LmsRepository {
  _RecordingRepository(this.tag);

  final String tag;
  final List<String> calls = <String>[];

  @override
  Future<DateTime> serverTime() async {
    calls.add('serverTime');
    // Distinguishable per side: the year is the marker, nothing more.
    return DateTime.utc(tag == 'http' ? 2001 : 2002);
  }

  @override
  Future<List<CourseSummary>> listCourses({String? subject, int? grade}) async {
    calls.add('listCourses(subject: $subject, grade: $grade)');
    return <CourseSummary>[
      CourseSummary(
          id: '$tag-course',
          title: tag,
          subject: tag,
          shortIntroduction: 'Which side answered this call.',
          lessonCount: 1,
        ),
    ];
  }

  @override
  Future<List<TutorProfile>> listTutors({int? grade}) async {
    calls.add('listTutors(grade: $grade)');
    return const <TutorProfile>[];
  }

  @override
  Future<double?> saveProgress(String lesson, {bool isComplete = true}) async {
    calls.add('saveProgress($lesson, isComplete: $isComplete)');
    return tag == 'http' ? 10 : 20;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'the $tag repository was asked for ${invocation.memberName}, which this '
      'test never wired');
}

/// Same idea for the catalog seam.
class _RecordingCatalog implements TutorCatalog {
  _RecordingCatalog(this.tag);

  final String tag;
  final List<String> calls = <String>[];

  @override
  Future<List<TutorProfile>> getTutors({int? grade}) async {
    calls.add('getTutors(grade: $grade)');
    return const <TutorProfile>[];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingRepository http;
  late _RecordingRepository demo;
  late SessionSwitchingLmsRepository repository;

  setUp(() async {
    // An empty preference store IS the no-demo-session starting point:
    // DemoSession.active reads the persisted flag on every call, so a store
    // with nothing in it answers false. LocalStorage.init() is what gives
    // DemoSession something to read at all.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
    http = _RecordingRepository('http');
    demo = _RecordingRepository('demo');
    repository =
        SessionSwitchingLmsRepository(httpRepo: http, demoRepo: demo);
  });

  tearDown(() async {
    // The session is app-global and persisted; never let one test leak into
    // the next.
    await DemoSession.instance.clear();
  });

  group('no demo session', () {
    test('every call reaches the HTTP repository and not the demo one',
        () async {
      expect(DemoSession.demoActive, isFalse);

      expect((await repository.serverTime()).year, 2001);
      expect((await repository.listCourses(subject: 'Mathematics', grade: 10))
          .single
          .subject, 'http');
      await repository.listTutors(grade: 11);
      expect(await repository.saveProgress('lesson-1'), 10);

      expect(http.calls, <String>[
        'serverTime',
        'listCourses(subject: Mathematics, grade: 10)',
        'listTutors(grade: 11)',
        'saveProgress(lesson-1, isComplete: true)',
      ]);
      expect(demo.calls, isEmpty);
    });
  });

  group('demo session active', () {
    test('every call reaches the demo repository and NO HTTP call is made',
        () async {
      await DemoSession.instance.activate();
      expect(DemoSession.demoActive, isTrue);

      expect((await repository.serverTime()).year, 2002);
      expect((await repository.listCourses()).single.subject, 'demo');
      await repository.listTutors(grade: 11);
      expect(await repository.saveProgress('lesson-1', isComplete: false), 20);

      expect(demo.calls, <String>[
        'serverTime',
        'listCourses(subject: null, grade: null)',
        'listTutors(grade: 11)',
        'saveProgress(lesson-1, isComplete: false)',
      ]);
      // The whole point: the backend is never touched for a demo session.
      expect(http.calls, isEmpty);
    });

    test('the side is resolved per call, so a sign-in mid-run lands at once',
        () async {
      expect((await repository.serverTime()).year, 2001);

      await DemoSession.instance.activate();
      expect((await repository.serverTime()).year, 2002);

      // And a sign-out hands the app straight back to the backend.
      await DemoSession.instance.clear();
      expect((await repository.serverTime()).year, 2001);

      expect(http.calls, <String>['serverTime', 'serverTime']);
      expect(demo.calls, <String>['serverTime']);
    });

    test('a session restored from storage serves the fixtures just the same',
        () async {
      // DemoSession.active re-reads the persisted flag on every call, so a
      // relaunch that restores the stored session is served the fixtures with
      // no activate() in this process at all — a fresh LocalStorage over the
      // same stored values, the way base_sdk's own demo_session_test spells a
      // relaunch.
      SharedPreferences.setMockInitialValues(<String, Object>{
        StorageKeys.keyDemoSessionActive: true,
      });
      await LocalStorage.init();
      expect(DemoSession.instance.active, isTrue);

      expect((await repository.serverTime()).year, 2002);
      expect(http.calls, isEmpty);
    });
  });

  group('SessionSwitchingTutorCatalog', () {
    late _RecordingCatalog backend;
    late _RecordingCatalog seeded;
    late SessionSwitchingTutorCatalog catalog;

    setUp(() {
      backend = _RecordingCatalog('backend');
      seeded = _RecordingCatalog('seeded');
      catalog = SessionSwitchingTutorCatalog(
        backendCatalog: backend,
        demoCatalog: seeded,
      );
    });

    test('no demo session reads the backend catalog', () async {
      await catalog.getTutors(grade: 12);
      expect(backend.calls, <String>['getTutors(grade: 12)']);
      expect(seeded.calls, isEmpty);
    });

    test('a demo session reads the seeded deck and never the backend',
        () async {
      await DemoSession.instance.activate();
      await catalog.getTutors(grade: 12);
      expect(seeded.calls, <String>['getTutors(grade: 12)']);
      expect(backend.calls, isEmpty);
    });
  });
}
