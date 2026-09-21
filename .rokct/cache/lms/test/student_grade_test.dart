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

/// Student grade field (lms/docs/student-grade-brief.md): the shared
/// prerequisite behind Holiday Programme grade logic and course-catalog
/// grade filtering. Grade is canonical BACKEND-side (LMS Student Profile);
/// lms_sdk carries only the read/write repository surface and the capture
/// notifier — no grade on AccessStatus or other models, per the brief.
void main() {
  group('StudentGradeStatus (rlms.api.student.my_grade contract)', () {
    test('never captured: null grade, no confirmation due', () {
      final s = StudentGradeStatus.fromJson(
          {'grade': null, 'needs_confirmation': false, 'suggested_grade': null});
      expect(s.grade, isNull);
      expect(s.isSet, isFalse);
      expect(s.needsConfirmation, isFalse);
    });

    test('confirmed this year: plain grade, no prompt', () {
      final s = StudentGradeStatus.fromJson(
          {'grade': 11, 'needs_confirmation': false, 'suggested_grade': null});
      expect(s.grade, 11);
      expect(s.needsConfirmation, isFalse);
    });

    test('January rollover: prompt-to-confirm with grade+1 suggested', () {
      // The decided rollover story: NEVER automatic — the backend only
      // reports staleness + a suggestion; the student confirms.
      final s = StudentGradeStatus.fromJson(
          {'grade': 11, 'needs_confirmation': true, 'suggested_grade': 12});
      expect(s.grade, 11);
      expect(s.needsConfirmation, isTrue);
      expect(s.suggestedGrade, 12);
    });
  });

  group('StudentGradeNotifier (capture / settings / rollover confirm)', () {
    test('loads the backend status on init', () async {
      final repo = _GradeRepo(
          const StudentGradeStatus(grade: 10, needsConfirmation: false));
      final n = StudentGradeNotifier(repository: repo);
      await n.init();
      expect(n.state.loading, isFalse);
      expect(n.state.status.grade, 10);
      n.dispose();
    });

    test('setGrade saves, updates state, and fires the host cache hook',
        () async {
      int? hooked;
      final repo = _GradeRepo(const StudentGradeStatus());
      final n = StudentGradeNotifier(
        repository: repo,
        onGradeSaved: (g) async => hooked = g,
      );
      await n.init();
      await n.setGrade(11);
      expect(repo.setGradeCalls, [11]);
      expect(n.state.status.grade, 11);
      // Saving resolves the rollover prompt: confirmation is no longer due.
      expect(n.state.status.needsConfirmation, isFalse);
      expect(n.state.saved, isTrue);
      expect(hooked, 11);
      n.dispose();
    });

    test('save failure surfaces a retryable error, state unchanged',
        () async {
      final repo = _GradeRepo(const StudentGradeStatus(grade: 10))
        ..failSetGrade = true;
      final n = StudentGradeNotifier(repository: repo);
      await n.init();
      await n.setGrade(11);
      expect(n.state.error, 'grade-save-failed');
      expect(n.state.status.grade, 10);
      n.dispose();
    });

    test('no repository wired: no grade surface, no crash', () async {
      final n = StudentGradeNotifier();
      await n.init();
      expect(n.state.loading, isFalse);
      expect(n.state.status.isSet, isFalse);
      n.dispose();
    });
  });

  group('catalog grade filtering (the second blocked consumer)', () {
    const g11Course = CourseSummary(
      id: 'c-g11',
      title: 'Grade 11 Functions',
      subject: 'maths',
      shortIntroduction: '',
      lessonCount: 1,
    );
    const g12Course = CourseSummary(
      id: 'c-g12',
      title: 'Grade 12 Calculus',
      subject: 'maths',
      shortIntroduction: '',
      lessonCount: 1,
    );
    const agnosticCourse = CourseSummary(
      id: 'c-any',
      title: 'Study Skills',
      subject: 'maths',
      shortIntroduction: '',
      lessonCount: 1,
    );

    test('grade narrows the catalog; grade-agnostic courses always show',
        () async {
      final repo = _CatalogRepo(
        [g11Course, g12Course, agnosticCourse],
        gradesByCourse: {'c-g11': 11, 'c-g12': 12},
      );
      final n = CourseCatalogNotifier(repository: repo, grade: 11);
      await n.init();
      // The student's grade went through to the backend query...
      expect(repo.listCoursesGradeArgs, [11]);
      // ...and the visible catalog is their grade + the ungraded seed
      // content — never the other grade's course.
      expect(n.state.courses.map((c) => c.id), ['c-g11', 'c-any']);
      n.dispose();
    });

    test('no grade captured: catalog browses everything, as before',
        () async {
      final repo = _CatalogRepo([g11Course, g12Course, agnosticCourse],
          gradesByCourse: {'c-g11': 11, 'c-g12': 12});
      final n = CourseCatalogNotifier(repository: repo);
      await n.init();
      expect(repo.listCoursesGradeArgs, [null]);
      expect(n.state.courses, hasLength(3));
      n.dispose();
    });
  });
}

/// Minimal grade-only fake: everything else unimplemented (and uncalled).
class _GradeRepo extends _UnimplementedRepo {
  StudentGradeStatus status;
  bool failSetGrade = false;
  final setGradeCalls = <int>[];

  _GradeRepo(this.status);

  @override
  Future<StudentGradeStatus> myGrade() async => status;

  @override
  Future<void> setGrade(int grade) async {
    if (failSetGrade) throw StateError('backend down');
    setGradeCalls.add(grade);
    status = StudentGradeStatus(grade: grade);
  }
}

/// Catalog fake mirroring list_courses' real semantics: a course with no
/// grade recorded is grade-agnostic and passes every grade filter.
class _CatalogRepo extends _UnimplementedRepo {
  final List<CourseSummary> courses;
  final Map<String, int> gradesByCourse;
  final listCoursesGradeArgs = <int?>[];

  _CatalogRepo(this.courses, {this.gradesByCourse = const {}});

  @override
  Future<List<CourseSummary>> listCourses({String? subject, int? grade}) async {
    listCoursesGradeArgs.add(grade);
    if (grade == null) return courses;
    return [
      for (final c in courses)
        if (gradesByCourse[c.id] == null || gradesByCourse[c.id] == grade) c
    ];
  }

  @override
  Future<CourseEnrollment?> getMyEnrollment(String course) async => null;
}

class _UnimplementedRepo implements LmsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}
