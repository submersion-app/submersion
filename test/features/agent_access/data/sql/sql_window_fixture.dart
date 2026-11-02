import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_connection_setup.dart';
import 'package:submersion/features/agent_access/data/sql/sql_denied_set.dart';

/// The view [SqlWindowFixture] puts over a denied table.
String deniedViewOf(String table) => 'v_probe_$table';

/// A database file carrying the app's real schema, on disk because a worker's
/// read-only connection cannot share an in-memory database.
///
/// A view over each denied table is added directly, standing in for a schema
/// that gained one somehow: the window itself can never create one.
class SqlWindowFixture {
  SqlWindowFixture._(this._directory, this.path);

  final Directory _directory;
  final String path;

  static Future<SqlWindowFixture> create({String? keyHex}) async {
    final directory = Directory.systemTemp.createTempSync('sql_window');
    final path = p.join(directory.path, 'window.db');
    final app = AppDatabase(
      NativeDatabase(
        File(path),
        setup: (db) => applyMainDatabaseSetup(db, keyHex: keyHex),
      ),
    );
    // Any read runs the migrations that create the schema.
    await app.customSelect('SELECT 1').get();
    await app.close();

    final raw = sqlite.sqlite3.open(path);
    try {
      applyConnectionBasics(raw, keyHex: keyHex);
      final existing = {
        for (final row in raw.select('SELECT name FROM sqlite_schema'))
          row['name'] as String,
      };
      for (final table in kSqlDeniedTables) {
        if (!existing.contains(table)) continue;
        raw.execute(
          'CREATE VIEW ${deniedViewOf(table)} AS SELECT * FROM $table',
        );
      }
      raw.execute('''
        INSERT INTO media_subscriptions
          (id, manifest_url, format, display_name, credentials_host_id,
           created_at, updated_at)
        VALUES ('sub-1', 'https://example.test/feed', 'atom', 'Feed',
                'host-secret', 1, 1)
      ''');
      raw.execute('''
        CREATE TABLE IF NOT EXISTS probe_blobs (id INTEGER PRIMARY KEY, b BLOB)
      ''');
    } finally {
      raw.close();
    }
    return SqlWindowFixture._(directory, path);
  }

  /// Writes through a connection of its own, for a test that needs a row.
  void execute(String sql, {String? keyHex}) {
    final raw = sqlite.sqlite3.open(path);
    try {
      applyConnectionBasics(raw, keyHex: keyHex);
      raw.execute(sql);
    } finally {
      raw.close();
    }
  }

  void dispose() => _directory.deleteSync(recursive: true);
}
