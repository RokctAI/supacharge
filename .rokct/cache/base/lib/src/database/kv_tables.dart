import 'package:drift/drift.dart';

/// Generic JSON document store shared by all SDKs.
///
/// Rows are namespaced by [box] (a logical collection name, e.g. 'settings',
/// 'polaris_drafts') so feature SDKs can persist small documents without
/// registering a dedicated Drift table. SDKs with real relational needs
/// still declare typed tables via their manifest.json database section.
@DataClassName('KeyValueEntity')
class KeyValueTable extends Table {
  TextColumn get box => text()();
  TextColumn get id => text()();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {box, id};
}
