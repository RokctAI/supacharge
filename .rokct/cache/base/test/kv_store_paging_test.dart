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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/database/app_database.dart';

/// Paged reads of the generic key/value box store.
///
/// getAll() used to run one unbounded SELECT over a whole box and jsonDecode
/// every row; it now walks the box in bounded pages. These lock the contract
/// that survived that change and the paging primitives added alongside it.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    // One test closes the database itself; a second close must not fail the
    // teardown.
    try {
      await db.close();
    } catch (_) {}
  });

  Future<void> seed(String box, int count) async {
    for (var i = 0; i < count; i++) {
      final key = 'k-${i.toString().padLeft(2, '0')}';
      await db.putItem(box, key, <String, dynamic>{'n': i});
    }
  }

  test('getAll returns the whole box, in row-key order', () async {
    await seed('notes', 7);
    final all = await db.getAll('notes');
    expect(all, hasLength(7));
    expect(
      all.map((e) => e['id']).toList(),
      <String>[
        'k-00', 'k-01', 'k-02', 'k-03', 'k-04', 'k-05', 'k-06',
      ],
    );
    expect(all.map((e) => e['n']).toList(), <int>[0, 1, 2, 3, 4, 5, 6]);
  });

  test('getAll crosses page boundaries exactly once per row', () async {
    // More rows than one page holds, so the keyset cursor is exercised.
    await seed('big', AppDatabase.defaultPageSize + 3);
    final all = await db.getAll('big');
    expect(all, hasLength(AppDatabase.defaultPageSize + 3));
    final ids = all.map((e) => e['id']).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'no row repeated');
  });

  test('getAll does not overwrite an id already in the stored data', () async {
    await db.putItem('notes', 'row-key', <String, dynamic>{'id': 'inner-id'});
    final all = await db.getAll('notes');
    expect(all.single['id'], 'inner-id');
  });

  test('boxes stay isolated', () async {
    await seed('a', 3);
    await seed('b', 2);
    expect(await db.getAll('a'), hasLength(3));
    expect(await db.getAll('b'), hasLength(2));
    expect(await db.getAll('empty'), isEmpty);
  });

  test('getPage returns one bounded page and honours afterId', () async {
    await seed('notes', 5);
    final first = await db.getPage('notes', limit: 2);
    expect(first.map((e) => e['id']).toList(), <String>['k-00', 'k-01']);

    final second = await db.getPage('notes', limit: 2, afterId: 'k-01');
    expect(second.map((e) => e['id']).toList(), <String>['k-02', 'k-03']);

    final last = await db.getPage('notes', limit: 2, afterId: 'k-03');
    expect(last.map((e) => e['id']).toList(), <String>['k-04']);

    expect(await db.getPage('notes', limit: 2, afterId: 'k-04'), isEmpty);
  });

  test('getAllPaged yields bounded pages covering the whole box', () async {
    await seed('notes', 5);
    final pages = await db.getAllPaged('notes', pageSize: 2).toList();
    expect(pages.map((p) => p.length).toList(), <int>[2, 2, 1]);
    expect(
      pages.expand((p) => p).map((e) => e['id']).toList(),
      <String>['k-00', 'k-01', 'k-02', 'k-03', 'k-04'],
    );
  });

  test('getAllPaged on an empty box yields nothing', () async {
    expect(await db.getAllPaged('nothing', pageSize: 2).toList(), isEmpty);
  });

  test('countBox counts without reading rows', () async {
    await seed('notes', 4);
    await seed('other', 1);
    expect(await db.countBox('notes'), 4);
    expect(await db.countBox('other'), 1);
    expect(await db.countBox('missing'), 0);
  });

  test('clearBox empties only its own box', () async {
    await seed('a', 3);
    await seed('b', 2);
    expect(await db.clearBox('a'), 3);
    expect(await db.getAll('a'), isEmpty);
    expect(await db.getAll('b'), hasLength(2));
  });

  test('releaseMemory is safe to call, open or closed', () async {
    await seed('notes', 1);
    await db.releaseMemory();
    expect(await db.getAll('notes'), hasLength(1));
    await db.close();
    // Never throws: releasing cache is best effort, not a correctness step.
    await db.releaseMemory();
  });
}
