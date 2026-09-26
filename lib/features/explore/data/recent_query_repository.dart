import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/text/fuzzy_match.dart' as fuzzy;
import 'package:submersion/features/explore/domain/query_model.dart';

class RecentQuery {
  final String sentence;
  final String locale;
  final ParsedQuery parsed;
  final DateTime lastUsedAt;
  const RecentQuery({
    required this.sentence,
    required this.locale,
    required this.parsed,
    required this.lastUsedAt,
  });
}

/// The last [cap] Explore sentences with their parse, in the local cache
/// database (never synced, never backed up).
class RecentQueryRepository {
  RecentQueryRepository({LocalCacheDatabase? database}) : _database = database;
  final LocalCacheDatabase? _database;
  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  static const int cap = 20;

  static String keyFor(String sentence, String locale) =>
      '${fuzzy.normalize(sentence).replaceAll(RegExp(r'\s+'), ' ')}|$locale';

  Future<List<RecentQuery>> list({int limit = cap}) async {
    final rows =
        await (_db.select(_db.recentQueries)
              ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])
              ..limit(limit))
            .get();
    final out = <RecentQuery>[];
    final stale = <String>[];
    for (final r in rows) {
      if (r.schemaVersion != kQuerySchemaVersion) {
        stale.add(r.key);
        continue;
      }
      try {
        final parsed = ParsedQuery.fromJson(
          (jsonDecode(r.parsedJson) as Map).cast<String, Object?>(),
        );
        out.add(
          RecentQuery(
            sentence: r.sentence,
            locale: r.locale,
            parsed: parsed,
            lastUsedAt: DateTime.fromMillisecondsSinceEpoch(r.lastUsedAt),
          ),
        );
      } on QuerySchemaException {
        stale.add(r.key);
      } on FormatException {
        stale.add(r.key);
      }
    }
    if (stale.isNotEmpty) {
      await (_db.delete(
        _db.recentQueries,
      )..where((t) => t.key.isIn(stale))).go();
    }
    return out;
  }

  Future<void> record(
    String sentence,
    String locale,
    ParsedQuery parsed,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.recentQueries)
        .insertOnConflictUpdate(
          RecentQueriesCompanion(
            key: Value(keyFor(sentence, locale)),
            sentence: Value(sentence),
            locale: Value(locale),
            parsedJson: Value(jsonEncode(parsed.toJson())),
            schemaVersion: Value(parsed.schemaVersion),
            subject: Value(parsed.subject.name),
            lastUsedAt: Value(now),
          ),
        );
    // Keep the newest [cap] rows.
    await _db.customStatement(
      'DELETE FROM recent_queries WHERE key NOT IN '
      '(SELECT key FROM recent_queries ORDER BY last_used_at DESC LIMIT $cap)',
    );
  }

  Future<void> clear() => _db.delete(_db.recentQueries).go();

  /// Change tick for the list provider.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.recentQueries));
}
