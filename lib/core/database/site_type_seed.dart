/// Built-in dive site types (v214, issue #1765).
///
/// The slug ids are the identity: every device seeds the same rows with
/// `INSERT OR IGNORE`, sync never exports them, and a `site_site_types` row
/// points at a built-in by slug. The names are English literals because the
/// stored `name` is what exports carry; the UI translates by id
/// (`builtInSiteTypeName`). This is the dive type arrangement, including the
/// lesson of #1360: a seed must never mint random ids.
library;

/// The built-in site types in display order. Append only; never rename a
/// slug, since junction rows, exports and saved filters reference it.
const List<({String id, String name})> kBuiltInSiteTypes = [
  (id: 'reef', name: 'Reef'),
  (id: 'wall', name: 'Wall'),
  (id: 'wreck', name: 'Wreck'),
  (id: 'artificial_reef', name: 'Artificial reef'),
  (id: 'cave', name: 'Cave'),
  (id: 'cavern', name: 'Cavern'),
  (id: 'cenote', name: 'Cenote'),
  (id: 'blue_hole', name: 'Blue hole'),
  (id: 'lake', name: 'Lake'),
  (id: 'quarry', name: 'Quarry'),
  (id: 'river', name: 'River'),
  (id: 'spring', name: 'Spring'),
  (id: 'pool', name: 'Pool'),
  (id: 'pier', name: 'Pier / jetty'),
  (id: 'muck', name: 'Muck'),
  (id: 'kelp_forest', name: 'Kelp forest'),
];

/// The set of built-in slugs, for importers that map external vocabularies.
final Set<String> kBuiltInSiteTypeIds = {
  for (final t in kBuiltInSiteTypes) t.id,
};

/// Idempotent seed of [kBuiltInSiteTypes]. Run by `onCreate`, the v214 rung
/// and the `beforeOpen` backstop.
final String kSeedBuiltInSiteTypesSql = _buildSeedSql();

String _buildSeedSql() {
  String quote(String s) => "'${s.replaceAll("'", "''")}'";
  final rows = <String>[];
  for (var i = 0; i < kBuiltInSiteTypes.length; i++) {
    final t = kBuiltInSiteTypes[i];
    rows.add(
      i == 0
          ? 'SELECT ${quote(t.id)} AS id, ${quote(t.name)} AS name, '
                '$i AS sort_order'
          : 'UNION ALL SELECT ${quote(t.id)}, ${quote(t.name)}, $i',
    );
  }
  return '''
  INSERT OR IGNORE INTO site_types
    (id, name, is_built_in, sort_order, created_at, updated_at)
  SELECT t.id, t.name, 1, t.sort_order, n.now_ms, n.now_ms
  FROM (
    ${rows.join('\n    ')}
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';
}
