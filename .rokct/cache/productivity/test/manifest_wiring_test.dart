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

// Regression guard for the composed app's wiring, which is DATA in this
// manifest rather than code in lib/: a composed app's lib/ is generated
// and gitignored, so nothing else in this package can fail when the
// manifest stops declaring what the shell needs (the radio_sdk pattern).
//
// What it guards: design strip section 46 reaches the guided run by ROUTE
// PATH — `/tasks/run?task=<id>` — from the /tasks page at one plane and
// from any other SDK that wants a run without importing this one. The
// route is only real if this manifest declares it against the template
// the installer copies in; a page with a @RoutePage the manifest never
// mentions is dropped from the generated router without a word.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest =
      jsonDecode(File('manifest.json').readAsStringSync()) as Map<String, dynamic>;

  List<Map<String, dynamic>> listOf(String key) =>
      ((manifest[key] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList();

  group('productivity_sdk manifest wiring', () {
    test('declares the tasks workspace and the guided run routes', () {
      final routes = listOf('routes');
      final byPath = {for (final r in routes) r['path'] as String: r};

      expect(byPath.keys, containsAll(['/tasks', '/tasks/run']));
      expect(byPath['/tasks']!['page'], 'TasksRoute.page');
      expect(byPath['/tasks/run']!['page'], 'TaskRunRoute.page');
    });

    test('every route imports a page the installer actually copies in', () {
      final installs = listOf('installs');
      final targets = installs.map((i) => i['to'] as String).toList();
      for (final route in listOf('routes')) {
        final import = route['import'] as String;
        expect(import, startsWith('package:\${package}/'),
            reason: 'routes resolve inside the composed app, not this SDK');
        final path = import
            .replaceFirst('package:\${package}/', 'lib/')
            .replaceFirst(RegExp(r"';?$"), '');
        expect(
          targets.any(path.startsWith),
          isTrue,
          reason: '${route['path']} imports $path, which no installs entry '
              'places in the composed app',
        );
      }
    });

    test('the run page template exists where the route says it does', () {
      final installs = listOf('installs');
      for (final route in listOf('routes')) {
        final import = route['import'] as String;
        final relative = import.replaceFirst('package:\${package}/', 'lib/');
        final install = installs.firstWhere(
          (i) => relative.startsWith(i['to'] as String),
        );
        final template = relative.replaceFirst(
          install['to'] as String,
          install['from'] as String,
        );
        expect(File(template).existsSync(), isTrue,
            reason: '${route['path']} points at $template');
        final source = File(template).readAsStringSync();
        final page = (route['page'] as String).replaceAll('.page', '');
        expect(
          source.contains('@RoutePage(') &&
              (source.contains("name: '$page'") ||
                  source.contains('class ${page.replaceAll('Route', 'Page')} ')),
          isTrue,
          reason: '$template must declare the $page @RoutePage',
        );
      }
    });

    test('the version moved with the new route', () {
      final version = manifest['version'] as String;
      final parts = version.split('.').map(int.parse).toList();
      expect(parts.length, 3);
      expect(parts[0] > 1 || (parts[0] == 1 && parts[1] >= 1), isTrue,
          reason: 'a route added is a minor bump: 1.1.0 or later');
    });

    // THE MIGRATION VERSION IS SHARED WITH EVERY OTHER SDK, AND THIS IS THE
    // BUG THAT COST RAY HIS NOTES ("notes seem like cant save").
    //
    // The composer sets the composed AppDatabase's schemaVersion to the
    // MAXIMUM version any composed manifest declares, while each SDK writes
    // its own `if (from < N)` guards — one namespace, no allocator.
    // auth_sdk already declared 16, so the launcher was ALREADY at
    // schemaVersion 16 while this manifest said 15; declaring 16 for
    // notes_table therefore raised nothing, drift never called onUpgrade on
    // a device that had the previous build, and every note insert failed on
    // `no such table`. The guards below are what a later table has to clear.
    group('the database migration', () {
      final migration = (manifest['database'] as Map)['migration'] as Map;
      final version = migration['version'] as int;
      final step = migration['step'] as String;

      List<int> thresholds() => RegExp(r'from\s*<\s*(\d+)')
          .allMatches(step)
          .map((m) => int.parse(m.group(1)!))
          .toList();

      test('is past 16, which auth_sdk already claims', () {
        expect(version, greaterThan(16),
            reason: 'auth_sdk (Users/auth/dart/manifest.json) declares 16, so '
                'the composed schemaVersion was already 16 and anything '
                'guarded at 16 or below never runs on an upgrading device');
      });

      test('declares a version no lower than any guard it writes', () {
        expect(thresholds(), isNotEmpty);
        expect(version, greaterThanOrEqualTo(thresholds().reduce(
            (a, b) => a > b ? a : b)),
            reason: 'a step guarded above the declared version can never run: '
                'drift upgrades only as far as schemaVersion');
      });

      test('creates the newest table at the declared version, not below it', () {
        // notes_table is the table this rule was learnt on. A guard lower
        // than the top version is a table that existing installs never get.
        final notesGuard = RegExp(
          r'if\s*\(from\s*<\s*(\d+)\)\s*\{[^}]*createTable\(notesTable\)',
        ).firstMatch(step);
        expect(notesGuard, isNotNull,
            reason: 'notes_table must be created by a migration step, or only '
                'a fresh install ever has one');
        expect(int.parse(notesGuard!.group(1)!), version,
            reason: 'the newest table is created at the top version so every '
                'device below it migrates in');
      });

      test('every registered table is created or is base-owned', () {
        final tables = ((manifest['database'] as Map)['tables'] as List)
            .cast<Map<String, dynamic>>()
            .map((t) => '${t['class']}')
            .toList();
        for (final table in tables) {
          // TasksTable -> tasksTable, the getter drift generates.
          final getter = table[0].toLowerCase() + table.substring(1);
          expect(step, contains('createTable($getter)'),
              reason: '$table is registered but no migration step creates it, '
                  'so only a fresh install has it');
        }
      });
    });

    // THE SIGN-OUT HOOK IS DATA TOO. Ray, 2026-09-19: "if on temp local user
    // you logout all your tasks still show". Emptying the live notifier is
    // Dart in lib/, but what makes it RUN is this boot hook -- and a composed
    // app's main.dart is generated and gitignored, so nothing else in this
    // package fails when the manifest stops declaring it.
    group('the session-end boot hook', () {
      test('registers this SDK\'s view clear against SessionEndHooks', () {
        final hooks = listOf('boot_hooks');
        final hook = hooks.firstWhere(
          (h) => h['id'] == 'productivity_session_end',
          orElse: () => <String, dynamic>{},
        );
        expect(hook, isNotEmpty,
            reason: 'without this hook nothing empties the root-scoped tasks '
                'notifier at sign-out, whatever lib/ can do');
        final body = hook['body'] as String;
        expect(body, contains('SessionEndHooks.register('));
        // The id and the callback both come off the class, so the manifest
        // cannot drift from the Dart it names.
        expect(body, contains('ProductivitySessionEnd.hookId'));
        expect(body, contains('ProductivitySessionEnd.clearLiveView'));
      });

      // THE MANIFEST MUST NOT ADVERTISE A DELETE. Ray's ruling: user data
      // does not get wiped on logout, so neither the wiring body nor the
      // comment beside it may name a row delete for the composer -- or the
      // next reader -- to take as this hook's job.
      test('neither the body nor its comment claims to delete anything', () {
        final body = listOf('boot_hooks').firstWhere(
              (h) => h['id'] == 'productivity_session_end',
            )['body'] as String;
        expect(body, isNot(contains('.clear;')),
            reason: 'the hook that deleted rows was registered as `.clear`');
        final comment = manifest['_comment_boot_hooks'] as String;
        expect(
          comment.toLowerCase(),
          isNot(contains('deletes the tasks')),
          reason: 'the comment described the version of this hook that wiped '
              'the tasks, notes, outbox and cursor; it must describe what the '
              'hook actually does now',
        );
        expect(comment, contains('deletes NOTHING'));
      });

      test('the clear it names is on the public surface', () {
        // The body is composed into the HOST's main.dart, which reaches this
        // package only through the barrel.
        final barrel = File('lib/productivity_sdk.dart').readAsStringSync();
        expect(
          barrel,
          contains(
            "export 'src/common/application/session/productivity_session_end.dart';",
          ),
          reason: 'an unexported clear is a host build that does not compile',
        );
        expect(
          File('lib/src/common/application/session/productivity_session_end.dart')
              .existsSync(),
          isTrue,
        );
      });

      test('declares no imports, because the host already has them', () {
        // Every composed main.dart imports package:productivity_sdk/... and
        // package:users_sdk/... in its @generated-sdk-imports block; a
        // wiring-block duplicate trips duplicate_import in every app (the
        // same reason auth_sdk's restore-credential hook declares none).
        final hook = listOf('boot_hooks')
            .firstWhere((h) => h['id'] == 'productivity_session_end');
        expect(hook.containsKey('imports'), isFalse);
      });
    });

    test('the schema the run persists into is still declared', () {
      final tables = ((manifest['database'] as Map)['tables'] as List)
          .cast<Map<String, dynamic>>()
          .map((t) => t['class'])
          .toSet();
      // The run writes its step timestamps into TasksTable.data; there is
      // no run table, and a migration that added one would be a mistake.
      expect(tables, contains('TasksTable'));
      expect(tables.any((t) => '$t'.toLowerCase().contains('run')), isFalse,
          reason: 'the run is derived state on the task, not a table');
    });
  });
}
