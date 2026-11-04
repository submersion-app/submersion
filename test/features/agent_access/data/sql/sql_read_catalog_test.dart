import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/agent_access/data/sql/sql_read_catalog_io.dart';

void main() {
  late Directory directory;
  late Database db;

  int rootOf(String name) =>
      db.select('SELECT rootpage FROM sqlite_schema WHERE name = ?', [
            name,
          ]).first['rootpage']
          as int;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('sql_catalog');
    db = sqlite3.open(p.join(directory.path, 'catalog.db'));
    db.execute('''
      CREATE TABLE dives (id TEXT PRIMARY KEY NOT NULL, name TEXT);
      CREATE INDEX idx_dives_name ON dives (name);
      CREATE TABLE connected_accounts (id TEXT PRIMARY KEY NOT NULL);
      CREATE TABLE media_subscriptions (
        id TEXT PRIMARY KEY NOT NULL,
        display_name TEXT,
        credentials_host_id TEXT
      );
      CREATE INDEX idx_sub_name ON media_subscriptions (display_name);
      CREATE INDEX idx_sub_cred ON media_subscriptions (credentials_host_id);
      CREATE INDEX idx_sub_expr ON media_subscriptions (lower(display_name));
    ''');
  });

  tearDown(() {
    db.close();
    directory.deleteSync(recursive: true);
  });

  test('maps tables and indexes by root page', () {
    final catalog = SqlReadCatalog.load(db);
    final table = catalog.root(rootOf('dives'))!;
    expect(table.table, 'dives');
    expect(table.denied, isFalse);
    final index = catalog.root(rootOf('idx_dives_name'))!;
    expect(index.table, 'dives');
    expect(index.denied, isFalse);
  });

  test('root 1 is the readable schema catalogue', () {
    final root = SqlReadCatalog.load(db).root(1)!;
    expect(root.table, 'sqlite_schema');
    expect(root.denied, isFalse);
  });

  test('a page nothing maps to is unknown', () {
    expect(SqlReadCatalog.load(db).root(99999), isNull);
  });

  test('a denied table and its autoindex are denied', () {
    final catalog = SqlReadCatalog.load(db);
    expect(catalog.root(rootOf('connected_accounts'))!.denied, isTrue);
    expect(
      catalog.root(rootOf('sqlite_autoindex_connected_accounts_1'))!.denied,
      isTrue,
    );
    expect(
      catalog
          .root(rootOf('sqlite_autoindex_connected_accounts_1'))!
          .indexOfReadableTable,
      isFalse,
    );
  });

  test('reports where a denied column sits', () {
    final root = SqlReadCatalog.load(db).root(rootOf('media_subscriptions'))!;
    expect(root.denied, isFalse);
    expect(root.deniedColumns, {2: 'credentials_host_id'});
  });

  test('an index over a denied column is denied, others are not', () {
    final catalog = SqlReadCatalog.load(db);
    expect(catalog.root(rootOf('idx_sub_cred'))!.denied, isTrue);
    expect(catalog.root(rootOf('idx_sub_cred'))!.indexOfReadableTable, isTrue);
    expect(catalog.root(rootOf('idx_sub_name'))!.denied, isFalse);
  });

  test('an expression index over a denied column is denied', () {
    db.execute('''
      CREATE INDEX idx_sub_plain ON media_subscriptions
        (lower(credentials_host_id));
      CREATE INDEX idx_sub_upper ON media_subscriptions
        (LOWER(CREDENTIALS_HOST_ID));
      CREATE INDEX idx_sub_quoted ON media_subscriptions
        (lower("credentials_host_id"));
    ''');
    final catalog = SqlReadCatalog.load(db);
    for (final index in ['idx_sub_plain', 'idx_sub_upper', 'idx_sub_quoted']) {
      expect(catalog.root(rootOf(index))!.denied, isTrue, reason: index);
    }
  });

  test('an expression index over other columns is not denied', () {
    expect(
      SqlReadCatalog.load(db).root(rootOf('idx_sub_expr'))!.denied,
      isFalse,
    );
  });

  test('a partial index is denied when its predicate names one', () {
    db.execute('''
      CREATE INDEX idx_sub_partial ON media_subscriptions (display_name)
        WHERE credentials_host_id IS NOT NULL;
      CREATE INDEX idx_sub_clean ON media_subscriptions (display_name)
        WHERE display_name IS NOT NULL;
    ''');
    final catalog = SqlReadCatalog.load(db);
    expect(catalog.root(rootOf('idx_sub_partial'))!.denied, isTrue);
    expect(catalog.root(rootOf('idx_sub_clean'))!.denied, isFalse);
  });

  test('a WITHOUT ROWID table holding a denied column is denied whole', () {
    db.execute('''
      DROP TABLE media_subscriptions;
      CREATE TABLE media_subscriptions (
        id TEXT PRIMARY KEY NOT NULL,
        credentials_host_id TEXT
      ) WITHOUT ROWID;
    ''');
    final root = SqlReadCatalog.load(db).root(rootOf('media_subscriptions'))!;
    expect(root.denied, isTrue);
  });

  test('a table with a generated column and a denied one is denied whole', () {
    db.execute('''
      DROP TABLE media_subscriptions;
      CREATE TABLE media_subscriptions (
        id TEXT PRIMARY KEY NOT NULL,
        twice TEXT GENERATED ALWAYS AS (id || id) VIRTUAL,
        credentials_host_id TEXT
      );
    ''');
    final root = SqlReadCatalog.load(db).root(rootOf('media_subscriptions'))!;
    expect(root.denied, isTrue);
  });
}
