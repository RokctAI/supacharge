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

import 'package:users_sdk/src/common/services/session_end_hooks.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SessionEndHooks.clearAll);
  tearDown(SessionEndHooks.clearAll);

  test('with nothing registered, running is a no-op', () async {
    // The state every existing consumer is in: behaviour is unchanged.
    await SessionEndHooks.run();
    expect(SessionEndHooks.registeredIds, isEmpty);
  });

  test('a registered hook runs on session end', () async {
    var ran = 0;
    SessionEndHooks.register('restore_credentials', () async => ran++);
    await SessionEndHooks.run();
    expect(ran, 1);
  });

  test('re-registering the same id replaces rather than stacks', () async {
    var first = 0;
    var second = 0;
    SessionEndHooks.register('dup', () async => first++);
    SessionEndHooks.register('dup', () async => second++);
    await SessionEndHooks.run();
    expect(first, 0);
    expect(second, 1);
    expect(SessionEndHooks.registeredIds.length, 1);
  });

  test('unregister removes a hook', () async {
    var ran = 0;
    SessionEndHooks.register('x', () async => ran++);
    SessionEndHooks.unregister('x');
    await SessionEndHooks.run();
    expect(ran, 0);
  });

  test('one failing hook does not stop the others', () async {
    // Sign-out must never be blocked by tidy-up that went wrong.
    var ran = 0;
    SessionEndHooks.register('bad', () async => throw StateError('boom'));
    SessionEndHooks.register('good', () async => ran++);
    await SessionEndHooks.run();
    expect(ran, 1);
  });
}
