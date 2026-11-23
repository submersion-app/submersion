/// A row a sync apply had to change because a parent it names was not on
/// this device yet (issue #4954), kept so the change can be undone once the
/// parent arrives.
///
/// The apply runs in one transaction per peer, and its foreign-key repair
/// clears a nullable link whose parent is absent. When that parent comes from another peer, in the next
/// transaction or a later pull, nothing would bring the link back, and the
/// next local edit of the row would send the cleared value to every device.
///
/// They live in one device-local `settings` value
/// ([heldReferencesSettingsKey]): they describe this device's copy of the
/// library, never the library itself.
library;

import 'dart:convert';

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

/// Everything this device holds, by id.
class HeldReferences {
  const HeldReferences({this.links = const {}});

  factory HeldReferences.decode(String? value) {
    if (value == null || value.isEmpty) return const HeldReferences();
    final json = jsonDecode(value) as Map<String, dynamic>;
    final links = [
      for (final link in json['links'] as List? ?? const [])
        HeldLink.fromJson(link as Map<String, dynamic>),
    ];
    return HeldReferences(links: {for (final link in links) link.id: link});
  }

  final Map<String, HeldLink> links;

  bool get isEmpty => links.isEmpty;

  String encode() => jsonEncode({
    'links': [for (final link in links.values) link.toJson()],
  });
}
