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

// OWNER SCOPING, END TO END, AGAINST A REAL DATABASE.
//
// The ruling these tests encode is base_sdk's, applied to this SDK's own
// tables: VISIBILITY SCOPING, NEVER DELETION. Two accounts on one device do
// not see each other's tasks, notes or recovery rows; a row that belongs to
// nobody in particular (every row on every device in the field today) stays
// visible to whoever is using the device; and signing out deletes nothing at
// all -- the rows are still there for the account that wrote them when it
// comes back.

import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/productivity_sdk.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase database;
  late TodoRepositoryImpl tasks;
  late NoteRepositoryImpl notes;
  late RecoveryRepositoryImpl recovery;

  /// Who the device thinks is using it. Null is "nobody named", which is
  /// what a never-signed-in app and the moment after a sign-out both read
  /// as.
  String? account;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('productivity_owner_scope');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir.path,
    );
    database = AppDatabase();
    tasks = TodoRepositoryImpl(database);
    notes = NoteRepositoryImpl(database);
    recovery = RecoveryRepositoryImpl(database);
  });

  tearDownAll(() async {
    OwnerScope.instance.debugReset();
    await database.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    account = null;
    OwnerScope.instance.debugReset(withResolver: () => account);
    await database.delete(database.tasksTable).go();
    await database.delete(database.notesTable).go();
    await database.delete(database.urgeLogsTable).go();
    await database.delete(database.recoveryProfilesTable).go();
    await database.delete(database.outboxTable).go();
  });

  /// Sign [who] in for everything that follows; null means nobody, with no
  /// memory of whoever was here before.
  void signedInAs(String? who) {
    account = who;
    OwnerScope.instance.debugRemember(null);
  }

  /// Sign out the way a real sign-out does: the stored identity goes, and
  /// the account on its way out stays the last one this process saw.
  void signedOut() {
    account = null;
  }

  Future<List<String>> titles() async =>
      (await tasks.loadTodos()).map((t) => '${t['title']}').toList();

  Future<int> taskRowsOnDisk() async =>
      (await database.select(database.tasksTable).get()).length;

  Map<String, dynamic> task(String id, String title) => <String, dynamic>{
        'id': id,
        'title': title,
        'isDone': false,
      };

  group('two accounts on one device', () {
    test('cannot see each other\'s tasks', () async {
      signedInAs('user-a');
      await tasks.saveTodos(<Map<String, dynamic>>[task('a1', 'A only')]);

      signedInAs('user-b');
      expect(await titles(), isEmpty);
      await tasks.saveTodos(<Map<String, dynamic>>[task('b1', 'B only')]);
      expect(await titles(), <String>['B only']);

      signedInAs('user-a');
      expect(await titles(), <String>['A only']);
      // Both are still on disk: neither read deleted anything.
      expect(await taskRowsOnDisk(), 2);
    });

    test('can hold the same task id side by side', () async {
      // `owner` is in the primary key precisely so this is two rows and not
      // one account silently overwriting the other's task.
      signedInAs('user-a');
      await tasks.saveTodos(<Map<String, dynamic>>[task('shared', 'A version')]);
      signedInAs('user-b');
      await tasks.saveTodos(<Map<String, dynamic>>[task('shared', 'B version')]);

      expect(await titles(), <String>['B version']);
      signedInAs('user-a');
      expect(await titles(), <String>['A version']);
      expect(await taskRowsOnDisk(), 2);
    });

    test('cannot see each other\'s notes', () async {
      signedInAs('user-a');
      await notes.saveNote(<String, dynamic>{'title': 'A note', 'body': 'a'});
      signedInAs('user-b');
      expect(await notes.loadNotes(), isEmpty);
      await notes.saveNote(<String, dynamic>{'title': 'B note', 'body': 'b'});
      expect(
        (await notes.loadNotes()).map((n) => n['title']).toList(),
        <String>['B note'],
      );
      signedInAs('user-a');
      expect(
        (await notes.loadNotes()).map((n) => n['title']).toList(),
        <String>['A note'],
      );
    });

    test('do not inherit each other\'s recovery streak', () async {
      signedInAs('user-a');
      await recovery.logUrge(
        intensity: 4,
        triggerType: 'Bored',
        outcome: 'Resisted',
      );
      expect((await recovery.getStreakStats())['currentStreak'], 1);

      signedInAs('user-b');
      expect((await recovery.getStreakStats())['currentStreak'], 0);
      expect((await recovery.getWeeklySummary(
        DateTime.now().subtract(const Duration(days: 1)),
      ))['urgeEvents'], 0);

      signedInAs('user-a');
      expect((await recovery.getStreakStats())['currentStreak'], 1);
    });

    test('a delete reaches only the deleting account\'s row', () async {
      signedInAs('user-a');
      await tasks.saveTodos(<Map<String, dynamic>>[task('shared', 'A version')]);
      signedInAs('user-b');
      await tasks.saveTodos(<Map<String, dynamic>>[task('shared', 'B version')]);
      await tasks.deleteTodo('shared');
      expect(await titles(), isEmpty);

      signedInAs('user-a');
      expect(await titles(), <String>['A version']);
    });
  });

  group('rows that belong to nobody in particular', () {
    /// A row exactly as every device in the field holds it today: written
    /// before owner scoping existed, so its owner is the default.
    Future<void> seedLegacyTask(String id, String title) async {
      await database.into(database.tasksTable).insertOnConflictUpdate(
            TasksTableCompanion.insert(
              id: Value(id),
              title: title,
              owner: const Value(kUnownedOwner),
            ),
          );
    }

    test('stay visible to whoever is using the device', () async {
      await seedLegacyTask('legacy', 'Written before scoping');
      signedInAs(null);
      expect(await titles(), <String>['Written before scoping']);
      signedInAs('user-a');
      expect(await titles(), <String>['Written before scoping']);
    });

    test('are CLAIMED by the account that next writes them, not duplicated',
        () async {
      await seedLegacyTask('legacy', 'Written before scoping');
      signedInAs('user-a');
      await tasks.saveTodos(<Map<String, dynamic>>[
        task('legacy', 'Edited by A'),
      ]);
      // One row, not an owned row beside its unclaimed twin.
      expect(await taskRowsOnDisk(), 1);
      expect(await titles(), <String>['Edited by A']);
      // And now it is A's: B sees nothing.
      signedInAs('user-b');
      expect(await titles(), isEmpty);
    });

    test('a signed-out device writes them, and does not claim them',
        () async {
      signedInAs(null);
      await tasks.saveTodos(<Map<String, dynamic>>[task('t1', 'No account')]);
      final rows = await database.select(database.tasksTable).get();
      expect(rows.single.owner, kUnownedOwner);
      // Still visible to the next account to sign in, which is what keeps
      // "no worse than today" true for a device nobody has signed into.
      signedInAs('user-a');
      expect(await titles(), <String>['No account']);
    });
  });

  group('signing out', () {
    test('deletes nothing, and hides nothing from the account coming back',
        () async {
      signedInAs('user-a');
      await tasks.saveTodos(<Map<String, dynamic>>[
        task('a1', 'Fit the softener'),
        task('a2', 'Call the plumber'),
      ]);
      await notes.saveNote(<String, dynamic>{'title': 'Gate code', 'body': '1'});
      final int before = await taskRowsOnDisk();

      // The session ends. Nothing in this SDK deletes a row, and the live
      // view clear is two in-memory writes.
      signedOut();
      ProductivitySessionEnd.clearLiveView();

      expect(await taskRowsOnDisk(), before);
      expect(
        (await database.select(database.notesTable).get()).length,
        1,
      );

      // The same account comes back and finds its work.
      signedInAs('user-a');
      expect(await titles(), <String>['Fit the softener', 'Call the plumber']);
    });

    test('a write during teardown stays with the account on its way out',
        () async {
      signedInAs('user-a');
      await tasks.saveTodos(<Map<String, dynamic>>[task('a1', 'Before')]);
      // `LocalStorage.logout()` clears the identity BEFORE every session-end
      // hook runs, so a write from one of those hooks resolves to nobody.
      // It must not land unowned, because an unowned row is visible to
      // whoever signs in next.
      signedOut();
      await tasks.saveTodos(<Map<String, dynamic>>[task('a2', 'During')]);

      signedInAs('user-b');
      expect(await titles(), isEmpty);
      signedInAs('user-a');
      expect(await titles(), <String>['Before', 'During']);
    });

    test('the next account does not see the previous account\'s rows',
        () async {
      signedInAs('user-a');
      await tasks.saveTodos(<Map<String, dynamic>>[task('a1', 'A only')]);
      await notes.saveNote(<String, dynamic>{'title': 'A note', 'body': 'a'});
      signedOut();
      ProductivitySessionEnd.clearLiveView();

      signedInAs('user-b');
      expect(await titles(), isEmpty);
      expect(await notes.loadNotes(), isEmpty);
      // ... while the rows themselves are untouched on disk.
      expect(await taskRowsOnDisk(), 1);
    });
  });
}
