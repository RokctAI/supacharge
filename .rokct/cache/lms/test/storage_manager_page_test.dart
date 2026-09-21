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


// StorageManagerPage — decision #7's storage-manager surface: per-lesson
// size/delete/re-download, friendly-only student errors (rule #56: the
// diagnostic detail goes to telemetry, never the screen).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/src/common/domain/interface/lesson_storage.dart';
import 'package:lms_sdk/src/common/presentation/pages/storage/storage_manager_page.dart';

class _FakeInventory implements LessonStorageInventory {
  List<StoredLesson> lessons;
  final List<String> deleted = [];
  final List<String> redownloaded = [];
  Object? deleteError;
  Object? redownloadError;
  Object? listError;

  _FakeInventory(this.lessons);

  @override
  Future<List<StoredLesson>> listDownloads() async {
    final error = listError;
    if (error != null) throw error;
    return lessons;
  }

  @override
  Future<void> deleteDownload(String sessionId) async {
    final error = deleteError;
    if (error != null) throw error;
    deleted.add(sessionId);
    lessons = lessons.where((l) => l.sessionId != sessionId).toList();
  }

  @override
  Future<void> redownload(String sessionId) async {
    final error = redownloadError;
    if (error != null) throw error;
    redownloaded.add(sessionId);
  }
}

StoredLesson _lesson(String id,
        {int size = 5 * 1024 * 1024, String subject = 'Mathematics'}) =>
    StoredLesson(
      sessionId: id,
      sizeBytes: size,
      subject: subject,
      scheduledAt: DateTime(2026, 8, 10),
    );

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('lists lessons with subject, size and the total line',
      (tester) async {
    final inventory = _FakeInventory([
      _lesson('s1', size: 10 * 1024 * 1024),
      _lesson('s2', size: 2 * 1024 * 1024, subject: 'Physical Sciences'),
    ]);
    await tester.pumpWidget(_host(StorageManagerPage(inventory: inventory)));
    await tester.pumpAndSettle();

    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Physical Sciences'), findsOneWidget);
    expect(find.textContaining('2 lessons on this device'), findsOneWidget);
    expect(find.textContaining('12.0 MB'), findsOneWidget);
  });

  testWidgets('empty state is a friendly note, not an error', (tester) async {
    final inventory = _FakeInventory([]);
    await tester.pumpWidget(_host(StorageManagerPage(inventory: inventory)));
    await tester.pumpAndSettle();

    expect(find.textContaining('No downloaded lessons yet'), findsOneWidget);
  });

  testWidgets('delete asks first, then removes the row', (tester) async {
    final inventory = _FakeInventory([_lesson('s1')]);
    await tester.pumpWidget(_host(StorageManagerPage(inventory: inventory)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this lesson?'), findsOneWidget);

    // Declining keeps the download.
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(inventory.deleted, isEmpty);
    expect(find.text('Mathematics'), findsOneWidget);

    // Confirming removes it.
    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(inventory.deleted, ['s1']);
    expect(find.textContaining('No downloaded lessons yet'), findsOneWidget);
  });

  testWidgets(
      'a failed delete shows ONLY the friendly line — no exception detail '
      'reaches the student (rule #56)', (tester) async {
    final inventory = _FakeInventory([_lesson('s1')])
      ..deleteError = StateError(
          'bundle checksum mismatch at /data/replay_assets/s1.rok');
    await tester.pumpWidget(_host(StorageManagerPage(inventory: inventory)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't be removed"), findsOneWidget);
    expect(find.textContaining('checksum'), findsNothing);
    expect(find.textContaining('replay_assets'), findsNothing);
    // The row is still there — nothing pretended to succeed.
    expect(find.text('Mathematics'), findsOneWidget);
  });

  testWidgets('re-download calls the inventory and confirms kindly',
      (tester) async {
    final inventory = _FakeInventory([_lesson('s1')]);
    await tester.pumpWidget(_host(StorageManagerPage(inventory: inventory)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Download again'));
    await tester.pumpAndSettle();

    expect(inventory.redownloaded, ['s1']);
    expect(find.textContaining('ready to play offline'), findsOneWidget);
  });

  testWidgets('a failed listing shows a friendly line, not a stack',
      (tester) async {
    final inventory = _FakeInventory([])
      ..listError = StateError('drift table not migrated');
    await tester.pumpWidget(_host(StorageManagerPage(inventory: inventory)));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't be listed"), findsOneWidget);
    expect(find.textContaining('drift'), findsNothing);
  });

  group('formatBytes', () {
    test('picks sensible units', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
    });
  });
}
