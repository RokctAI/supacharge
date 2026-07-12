import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'kv_tables.dart';

part 'app_database.g.dart';

/// Shared offline database for the composed app.
///
/// base_sdk owns the database shell and a generic JSON document store; SDKs
/// with relational needs register typed tables + migration steps through
/// their manifest.json `database` section, which the composer injects into
/// the cached copy of this file at compose time (the .rokct/cache copy is
/// fully editable by design).
// @sdk-database-table-imports
@DriftDatabase(
  tables: [
    KeyValueTable,
    // @sdk-database-tables
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());

  /// The database must be a process-wide singleton: multiple SDKs resolve it
  /// independently (directly or via get_it) and drift does not allow two
  /// executors on the same file.
  factory AppDatabase() => _instance ??= AppDatabase._internal();
  static AppDatabase? _instance;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // @sdk-database-migrations
      },
    );
  }

  // ─── Generic JSON document store ───

  /// Save a JSON-serializable item by key.
  Future<void> putItem(String boxName, String key, Map<String, dynamic> json) {
    return into(keyValueTable).insertOnConflictUpdate(
      KeyValueTableCompanion.insert(
        box: boxName,
        id: key,
        data: jsonEncode(json),
      ),
    );
  }

  /// Get an item as a Map by key, or null when absent.
  Future<Map<String, dynamic>?> getItem(String boxName, String key) async {
    final query = select(keyValueTable)
      ..where((t) => t.box.equals(boxName) & t.id.equals(key));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.data) as Map<String, dynamic>;
  }

  /// Get all items in a box. Each map includes its row key under 'id'
  /// (without overwriting an 'id' already present in the stored data).
  Future<List<Map<String, dynamic>>> getAll(String boxName) async {
    final query = select(keyValueTable)..where((t) => t.box.equals(boxName));
    final rows = await query.get();
    return rows.map((row) {
      final map = jsonDecode(row.data) as Map<String, dynamic>;
      map.putIfAbsent('id', () => row.id);
      return map;
    }).toList();
  }

  /// Delete an item by key.
  Future<void> deleteItem(String boxName, String key) {
    return (delete(keyValueTable)
          ..where((t) => t.box.equals(boxName) & t.id.equals(key)))
        .go();
  }

  /// Clear all items in a box. Returns the number of deleted rows.
  Future<int> clearBox(String boxName) {
    return (delete(keyValueTable)..where((t) => t.box.equals(boxName))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'rokct_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
