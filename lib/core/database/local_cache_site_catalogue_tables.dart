import 'package:drift/drift.dart';

/// One site of the built-in catalogue, loaded from `assets/data/site_catalogue.json` whenever that
/// file's version changes.
///
/// Local-only by construction: every device rebuilds it from its own
/// bundled file, so it carries no HLC, is never synced and never backed up.
/// A format change may drop and re-create it.
@DataClassName('SiteCatalogueRow')
class SiteCatalogueEntries extends Table {
  @override
  String get tableName => 'site_catalogue';

  TextColumn get id => text()();
  TextColumn get name => text()();

  /// The folded text a search runs against: name and place, through the
  /// same `normalize` the site picker applies to the diver's own sites.
  TextColumn get searchText => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get countryCode => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get locality => text().nullable()();
  TextColumn get island => text().nullable()();
  TextColumn get bodyOfWater => text().nullable()();
  TextColumn get waterType => text().nullable()();
  RealColumn get minDepth => real().nullable()();
  RealColumn get maxDepth => real().nullable()();

  /// JSON arrays of built-in site type ids, EntryMethod names and the
  /// source's remaining descriptive tags.
  TextColumn get typeIds => text().withDefault(const Constant('[]'))();
  TextColumn get entryMethods => text().withDefault(const Constant('[]'))();
  TextColumn get features => text().withDefault(const Constant('[]'))();
  TextColumn get difficulty => text().nullable()();
  TextColumn get hazards => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get source => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get trust => text().withDefault(const Constant('verified'))();

  /// `site` or `register` (CatalogueKind): a place people dive, or a
  /// record from a wreck register or a reef deployment list. Reads filter
  /// on it, so it is a column and not part of the JSON.
  TextColumn get kind => text().withDefault(const Constant('site'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// What the catalogue tables currently hold: the imported file's `version`
/// and its `sources`, as JSON.
@DataClassName('SiteCatalogueMetaRow')
class SiteCatalogueMeta extends Table {
  @override
  String get tableName => 'site_catalogue_meta';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The open backstop's copy of [SiteCatalogueEntries], for a local cache a
/// colliding branch stamped at v21 without creating it. Must match the
/// Drift table column for column.
const String kCreateSiteCatalogueTableSql = '''
  CREATE TABLE IF NOT EXISTS site_catalogue (
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    search_text TEXT NOT NULL,
    latitude REAL NULL,
    longitude REAL NULL,
    country_code TEXT NULL,
    country TEXT NULL,
    region TEXT NULL,
    locality TEXT NULL,
    island TEXT NULL,
    body_of_water TEXT NULL,
    water_type TEXT NULL,
    min_depth REAL NULL,
    max_depth REAL NULL,
    type_ids TEXT NOT NULL DEFAULT '[]',
    entry_methods TEXT NOT NULL DEFAULT '[]',
    features TEXT NOT NULL DEFAULT '[]',
    difficulty TEXT NULL,
    hazards TEXT NULL,
    description TEXT NULL,
    website TEXT NULL,
    source TEXT NOT NULL,
    source_ref TEXT NULL,
    trust TEXT NOT NULL DEFAULT 'verified',
    kind TEXT NOT NULL DEFAULT 'site',
    PRIMARY KEY (id)
  )
''';

/// Adds [SiteCatalogueEntries.kind] to a table created before v22. The rows
/// already there are dive sites: every record was, before register records
/// existed.
const String kAddSiteCatalogueKindSql =
    "ALTER TABLE site_catalogue ADD COLUMN kind TEXT NOT NULL DEFAULT 'site'";

/// The open backstop's copy of [SiteCatalogueMeta].
const String kCreateSiteCatalogueMetaTableSql = '''
  CREATE TABLE IF NOT EXISTS site_catalogue_meta (
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (key)
  )
''';

/// The bounding-box index "sites near here" reads.
const String kCreateSiteCatalogueIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_site_catalogue_lat_lon '
    'ON site_catalogue (latitude, longitude)';

/// The same lookup for one kind of record: the picker asks for dive sites
/// and for register records apart.
const String kCreateSiteCatalogueKindIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_site_catalogue_kind_lat_lon '
    'ON site_catalogue (kind, latitude, longitude)';
