import 'package:drift/drift.dart';

/// One foreign key, with its parent column resolved.
class HeldForeignKey {
  const HeldForeignKey({
    required this.table,
    required this.from,
    required this.parent,
    required this.to,
    required this.onDelete,
  });

  /// The child table and column.
  final String table;
  final String from;

  /// The parent table and the column [from] names.
  final String parent;
  final String to;

  /// SQLite's `on_delete` action, upper case (`CASCADE`, `SET NULL`, ...).
  final String onDelete;
}

/// The schema facts the holds read, cached per database: the schema does
/// not change while the app runs.
class HeldSchema {
  HeldSchema._(this._db);

  /// The cache for [db].
  static HeldSchema of(GeneratedDatabase db) => _cache[db] ??= HeldSchema._(db);

  static final _cache = Expando<HeldSchema>();

  final GeneratedDatabase _db;
  final _keyColumns = <String, List<String>>{};
  final _hasClock = <String, bool>{};
  final _foreignKeys = <String, Map<int, HeldForeignKey>>{};
  Map<String, List<HeldForeignKey>>? _children;

  Future<List<Map<String, Object?>>> _tableInfo(String table) async => [
    for (final row
        in await _db.customSelect('PRAGMA table_info("$table")').get())
      row.data,
  ];

  /// [table]'s primary key columns in key order; every column when it
  /// declares none.
  Future<List<String>> keyColumns(String table) async {
    final cached = _keyColumns[table];
    if (cached != null) return cached;
    final info = await _tableInfo(table);
    final keyed = [
      for (final c in info)
        if ((c['pk'] as int) > 0) c,
    ]..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
    final columns = keyed.isEmpty
        ? [for (final c in info) c['name'] as String]
        : [for (final c in keyed) c['name'] as String];
    return _keyColumns[table] = columns;
  }

  Future<bool> hasClock(String table) async => _hasClock[table] ??=
      (await _tableInfo(table)).any((c) => c['name'] == 'hlc');

  /// Every foreign key that names [table] as its parent.
  Future<List<HeldForeignKey>> childrenOf(String table) async {
    final children = _children ??= await _loadChildren();
    return children[table] ?? const [];
  }

  Future<Map<String, List<HeldForeignKey>>> _loadChildren() async {
    final tables = await _db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final byParent = <String, List<HeldForeignKey>>{};
    for (final t in tables) {
      final name = t.read<String>('name');
      for (final fk in await foreignKeys(name)) {
        (byParent[fk.parent] ??= []).add(fk);
      }
    }
    return byParent;
  }

  /// [table]'s foreign keys, by SQLite's id for each. A key over several
  /// columns is reported by its first (seq 0), as the repair always read it.
  Future<Map<int, HeldForeignKey>> foreignKeysById(String table) async {
    final cached = _foreignKeys[table];
    if (cached != null) return cached;
    final rows = await _db
        .customSelect('PRAGMA foreign_key_list("$table")')
        .get();
    final byId = <int, HeldForeignKey>{};
    for (final row in rows) {
      final id = row.read<int>('id');
      if (byId.containsKey(id)) continue;
      final parent = row.read<String>('table');
      final to = row.data['to'] as String? ?? (await keyColumns(parent)).first;
      byId[id] = HeldForeignKey(
        table: table,
        from: row.read<String>('from'),
        parent: parent,
        to: to,
        onDelete: row.read<String>('on_delete').toUpperCase(),
      );
    }
    return _foreignKeys[table] = byId;
  }

  Future<List<HeldForeignKey>> foreignKeys(String table) async =>
      (await foreignKeysById(table)).values.toList();
}

/// The foreign key SQLite reports as [fkid] of [table], as the holds need
/// it. Null when the schema has no such key.
Future<HeldForeignKey?> heldForeignKey(
  GeneratedDatabase db,
  String table,
  int fkid,
) async {
  return (await HeldSchema.of(db).foreignKeysById(table))[fkid];
}
