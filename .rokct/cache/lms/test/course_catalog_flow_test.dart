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

/// Fake backend standing in for HttpLmsRepository — verifies the actual
/// enroll-then-view-enrollment state machine (list -> enroll -> re-fetch
/// enrollment -> filter to "My Enrollments") without a live Frappe server,
/// same posture as lesson_notifier_events_test.dart's fake engine.
class _FakeLmsRepository implements LmsRepository {
  final List<CourseSummary> _courses;

  /// Server-side grade per course id (student-grade brief) — null/absent =
  /// grade-agnostic, always shown, mirroring list_courses' real filter.
  final Map<String, int> _gradesByCourse;
  final Map<String, CourseEnrollment> _enrollments = {};
  final List<String> enrollCalls = [];
  final List<String> getMyEnrollmentCalls = [];
  final List<String> getCourseContentCalls = [];
  final List<int?> listCoursesGradeArgs = [];
  final List<int> setGradeCalls = [];
  StudentGradeStatus gradeStatus = const StudentGradeStatus();

  _FakeLmsRepository(this._courses,
      {Map<String, int> gradesByCourse = const {}})
      : _gradesByCourse = gradesByCourse;

  @override
  Future<List<CourseSummary>> listCourses({String? subject, int? grade}) async {
    listCoursesGradeArgs.add(grade);
    var courses = _courses;
    if (subject != null) {
      courses = courses.where((c) => c.subject == subject).toList();
    }
    if (grade != null) {
      courses = courses
          .where((c) =>
              _gradesByCourse[c.id] == null || _gradesByCourse[c.id] == grade)
          .toList();
    }
    return courses;
  }

  @override
  Future<BoardTerm?> boardCoverage(String subject) async => null;

  @override
  Future<StudentGradeStatus> myGrade() async => gradeStatus;

  @override
  Future<void> setGrade(int grade) async => setGradeCalls.add(grade);

  @override
  Future<MathsTrackStatus> myMathsTrack() async => const MathsTrackStatus();

  @override
  Future<void> setMathsTrack(MathsTrack track) async {}

  @override
  Future<void> setSchool(String school, String curriculum) async {}

  @override
  Future<List<String>> knownSchools(String curriculum) async => const [];

  @override
  Future<LastYearBaseline?> lastYearBaseline() async => null;

  @override
  Future<List<TutorProfile>> listTutors({int? grade}) async => const [];

  @override
  Future<DateTime> serverTime() async => DateTime.now().toUtc();

  @override
  Future<bool> canReviewLessons() async => false;

  @override
  Future<void> reviewLesson({
    required String lessonId,
    required LessonReviewStatus status,
    String? reason,
  }) async {}

  @override
  Future<PracticeQueue> practiceQueue({String? subject, String? lesson}) async =>
      PracticeQueue.empty;

  @override
  Future<void> recordPracticeAttempt({
    required String itemId,
    required McqOutcome outcome,
    String? subtopicRef,
    int? selectedIndex,
  }) async {}

  @override
  Future<CourseEnrollment?> getMyEnrollment(String course) async {
    getMyEnrollmentCalls.add(course);
    return _enrollments[course];
  }

  @override
  Future<String> enroll(String course) async {
    enrollCalls.add(course);
    // Mirrors the real backend: enrolling creates a 0%-progress enrollment
    // record that a later getMyEnrollment call picks up.
    _enrollments[course] = CourseEnrollment(id: 'enr-$course', progress: 0);
    return 'enr-$course';
  }

  @override
  Future<List<CourseChapterContent>> getCourseContent(String course) async {
    getCourseContentCalls.add(course);
    return [
      const CourseChapterContent(
        id: 'ch1',
        title: 'Chapter 1',
        sequence: 0,
        lessons: [
          CourseLessonContent(
              id: 'lesson-1', title: 'Lesson 1', sequence: 0, sessionId: 'sess-1'),
        ],
      ),
    ];
  }

  @override
  Future<LessonSessionInfo> getLessonSession(String lesson) async {
    return const LessonSessionInfo(sessionId: 'sess-1');
  }

  @override
  Future<List<String>> allowedSubjects() async => const [];

  @override
  Future<double?> saveProgress(String lesson, {bool isComplete = true}) async => null;

  @override
  Future<void> recordVideoWatch({
    required String lesson,
    required String source,
    required double watchTimeSeconds,
  }) async {}

  @override
  Future<void> recordQuizResult({
    required String lesson,
    required String questionId,
    required McqOutcome outcome,
    String? subtopicRef,
    int? selectedIndex,
  }) async {}

  @override
  Future<void> recordAttendanceEvent({
    required String sessionId,
    required AttendanceEventOutcome outcome,
    double dataUsedMb = 0,
    int? secondsWatched,
    String? sittingId,
  }) async {}
}

void main() {
  const course = CourseSummary(
    id: 'course-1',
    title: 'Algebra Basics',
    subject: 'maths',
    shortIntroduction: 'Intro to algebra',
    lessonCount: 1,
  );

  test('listCourses populates the catalog with nothing enrolled yet', () async {
    final repo = _FakeLmsRepository([course]);
    final notifier = CourseCatalogNotifier(repository: repo);
    await notifier.init();

    expect(notifier.state.courses, [course]);
    expect(notifier.state.enrollments['course-1'], isNull);
    expect(notifier.state.visibleCourses, [course]);
    // "My Enrollments" is empty before enrolling.
    notifier.setShowEnrolledOnly(true);
    expect(notifier.state.visibleCourses, isEmpty);

    notifier.dispose();
  });

  test(
      'enroll() calls the real enroll endpoint then re-fetches enrollment, '
      'and the course then shows up under My Enrollments', () async {
    final repo = _FakeLmsRepository([course]);
    final notifier = CourseCatalogNotifier(repository: repo);
    await notifier.init();
    expect(repo.enrollCalls, isEmpty);

    await notifier.enroll('course-1');

    // enroll() was actually called against the backend...
    expect(repo.enrollCalls, ['course-1']);
    // ...and getMyEnrollment was called again afterward to confirm/display it
    // (once during init's eager load, once more after enrolling).
    expect(repo.getMyEnrollmentCalls, ['course-1', 'course-1']);
    expect(notifier.state.enrolling, isEmpty);
    expect(notifier.state.enrollments['course-1']?.progress, 0);

    // The enrollment is now visible under the "My Enrollments" filter.
    notifier.setShowEnrolledOnly(true);
    expect(notifier.state.visibleCourses.single.id, 'course-1');

    notifier.dispose();
  });

  test('toggleExpand fetches real course content and caches it', () async {
    final repo = _FakeLmsRepository([course]);
    final notifier = CourseCatalogNotifier(repository: repo);
    await notifier.init();

    // init() auto-expands the first course so the catalog lands with content
    // visible — the content fetch has already happened once.
    expect(notifier.state.expandedCourse, 'course-1');
    expect(notifier.state.courseContent['course-1']?.single.lessons.single.id,
        'lesson-1');
    expect(repo.getCourseContentCalls, ['course-1']);

    // Collapsing and re-expanding doesn't refetch (cached).
    await notifier.toggleExpand('course-1');
    expect(notifier.state.expandedCourse, isNull);
    await notifier.toggleExpand('course-1');
    expect(notifier.state.expandedCourse, 'course-1');
    expect(repo.getCourseContentCalls, ['course-1']);

    notifier.dispose();
  });
}
