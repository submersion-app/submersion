/// A row a sync apply had to change because a parent it names was not on
/// this device yet (issue #4954), kept so the change can be undone once the
/// parent arrives.
///
/// The apply runs in one transaction per peer, and its foreign-key repair
/// clears a nullable link (or deletes a NOT NULL child) whose parent is
/// absent. When that parent comes from another peer, in the next
/// transaction or a later pull, nothing would bring the link back, and the
/// next local edit of the row would send the cleared value to every device.
///
/// Both kinds live in one device-local `settings` value
/// ([heldReferencesSettingsKey]): they describe this device's copy of the
/// library, never the library itself.
library;

import 'dart:convert';
import 'dart:typed_data';

/// The `settings` key holding this device's held references. Device-local:
/// listed in `deviceLocalSettingsKeys`.
const String heldReferencesSettingsKey = 'sync_held_references';

/// The identity of one row: its SQL table and its primary key values, by SQL
/// column name. Rows are matched by primary key, never by rowid, since a
/// later write can give the row a new rowid.
String heldRowId(String table, Map<String, Object?> key) =>
    '$table|${jsonEncode([
      for (final column in key.keys.toList()..sort()) [column, key[column]],
    ])}';

/// The parent a held row is waiting for.
class HeldParent {
  const HeldParent({
    required this.table,
    required this.column,
    required this.value,
  });

  factory HeldParent.fromJson(Map<String, dynamic> json) => HeldParent(
    table: json['table'] as String,
    column: json['column'] as String,
    value: json['value'] as Object,
  );

  /// The parent's SQL table.
  final String table;

  /// The parent column the link names (its primary key, as a rule).
  final String column;

  /// The value the link held.
  final Object value;

  Map<String, dynamic> toJson() => {
    'table': table,
    'column': column,
    'value': value,
  };
}

/// A nullable link the repair cleared: restored once [parent] exists, left
/// out of this device's exports until then.
class HeldLink {
  const HeldLink({
    required this.table,
    required this.key,
    required this.column,
    required this.parent,
    this.hlc,
  });

  factory HeldLink.fromJson(Map<String, dynamic> json) => HeldLink(
    table: json['table'] as String,
    key: Map<String, Object?>.from(json['key'] as Map),
    column: json['column'] as String,
    parent: HeldParent.fromJson(json['parent'] as Map<String, dynamic>),
    hlc: json['hlc'] as String?,
  );

  final String table;

  /// The row's primary key, by SQL column name.
  final Map<String, Object?> key;

  /// The SQL column the repair cleared.
  final String column;

  final HeldParent parent;

  /// The row's clock the last time this device judged the hold: at the
  /// repair, then after each later write that left the hold standing. Null
  /// for a table without an `hlc` column.
  final String? hlc;

  String get rowId => heldRowId(table, key);

  String get id => '$rowId|$column';

  HeldLink withHlc(String? value) => HeldLink(
    table: table,
    key: key,
    column: column,
    parent: parent,
    hlc: value,
  );

  Map<String, dynamic> toJson() => {
    'table': table,
    'key': key,
    'column': column,
    'parent': parent.toJson(),
    'hlc': hlc,
  };
}

/// One raw SQL row, as `SELECT *` read it.
class HeldRow {
  const HeldRow({required this.table, required this.values});

  factory HeldRow.fromJson(Map<String, dynamic> json) => HeldRow(
    table: json['table'] as String,
    values: {
      for (final e in (json['values'] as Map<String, dynamic>).entries)
        e.key: _decodeValue(e.value),
    },
  );

  final String table;

  /// Column values by SQL name, exactly as stored.
  final Map<String, Object?> values;

  Map<String, dynamic> toJson() => {
    'table': table,
    'values': {for (final e in values.entries) e.key: _encodeValue(e.value)},
  };
}

/// A NOT NULL child the repair deleted, with every row the delete cascaded
/// to, parent first: re-inserted once [parent] exists.
class HeldOrphan {
  const HeldOrphan({
    required this.table,
    required this.key,
    required this.parent,
    required this.rows,
  });

  factory HeldOrphan.fromJson(Map<String, dynamic> json) => HeldOrphan(
    table: json['table'] as String,
    key: Map<String, Object?>.from(json['key'] as Map),
    parent: HeldParent.fromJson(json['parent'] as Map<String, dynamic>),
    rows: [
      for (final row in json['rows'] as List)
        HeldRow.fromJson(row as Map<String, dynamic>),
    ],
  );

  final String table;
  final Map<String, Object?> key;
  final HeldParent parent;

  /// The orphan itself first, then the rows its delete cascaded to, each
  /// after its own parent.
  final List<HeldRow> rows;

  String get id => heldRowId(table, key);

  Map<String, dynamic> toJson() => {
    'table': table,
    'key': key,
    'parent': parent.toJson(),
    'rows': [for (final row in rows) row.toJson()],
  };
}

/// Everything this device holds, by id.
class HeldReferences {
  const HeldReferences({this.links = const {}, this.orphans = const {}});

  factory HeldReferences.decode(String? value) {
    if (value == null || value.isEmpty) return const HeldReferences();
    final json = jsonDecode(value) as Map<String, dynamic>;
    final links = [
      for (final link in json['links'] as List? ?? const [])
        HeldLink.fromJson(link as Map<String, dynamic>),
    ];
    final orphans = [
      for (final orphan in json['orphans'] as List? ?? const [])
        HeldOrphan.fromJson(orphan as Map<String, dynamic>),
    ];
    return HeldReferences(
      links: {for (final link in links) link.id: link},
      orphans: {for (final orphan in orphans) orphan.id: orphan},
    );
  }

  final Map<String, HeldLink> links;
  final Map<String, HeldOrphan> orphans;

  bool get isEmpty => links.isEmpty && orphans.isEmpty;

  String encode() => jsonEncode({
    'links': [for (final link in links.values) link.toJson()],
    'orphans': [for (final orphan in orphans.values) orphan.toJson()],
  });
}

const _blobKey = r'$blob';

Object? _encodeValue(Object? value) =>
    value is Uint8List ? {_blobKey: base64Encode(value)} : value;

Object? _decodeValue(Object? value) {
  if (value is Map && value[_blobKey] is String) {
    return base64Decode(value[_blobKey] as String);
  }
  return value;
}
