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

/// Each diver's last [cap] Explore sentences with their parse, in the local
/// cache database (never synced, never backed up).
///
/// Scoped to the diver who asked: a sentence names that diver's buddies and
/// sites, and a pinned mention carries one of their entity ids.
class RecentQueryRepository {
  RecentQueryRepository({LocalCacheDatabase? database}) : _database = database;
  final LocalCacheDatabase? _database;
  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  static const int cap = 20;

  /// The sentence as the key compares it: a retyped sentence that differs
  /// only in case, accents or spacing is the same row.
  static String keyFor(String sentence) =>
      fuzzy.normalize(sentence).replaceAll(RegExp(r'\s+'), ' ');

  /// The diver's recent sentences in [locale], newest first.
  Future<List<RecentQuery>> list({
    required String diverId,
    required String locale,
    int limit = cap,
  }) async {
    final rows =
        await (_db.select(_db.recentQueries)
              ..where(
                (t) => t.diverId.equals(diverId) & t.locale.equals(locale),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.lastUsedAt)])
              ..limit(limit))
            .get();
    final out = <RecentQuery>[];
    final stale = <String>[];
    for (final r in rows) {
      if (r.schemaVersion < kMinReadableQuerySchemaVersion ||
          r.schemaVersion > kQuerySchemaVersion) {
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
      await (_db.delete(_db.recentQueries)..where(
            (t) =>
                t.diverId.equals(diverId) &
                t.locale.equals(locale) &
                t.key.isIn(stale),
          ))
          .go();
    }
    return out;
  }

  Future<void> record(
    String sentence,
    String locale,
    ParsedQuery parsed, {
    required String diverId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.recentQueries)
        .insertOnConflictUpdate(
          RecentQueriesCompanion(
            diverId: Value(diverId),
            key: Value(keyFor(sentence)),
            sentence: Value(sentence),
            locale: Value(locale),
            parsedJson: Value(jsonEncode(parsed.toJson())),
            schemaVersion: Value(parsed.schemaVersion),
            subject: Value(parsed.subject.name),
            lastUsedAt: Value(now),
          ),
        );
    // Keep the diver's newest [cap] rows; another diver's are theirs.
    await _db.customStatement(
      'DELETE FROM recent_queries WHERE diver_id = ? AND rowid NOT IN '
      '(SELECT rowid FROM recent_queries WHERE diver_id = ? '
      'ORDER BY last_used_at DESC LIMIT $cap)',
      [diverId, diverId],
    );
  }

  /// Change tick for the list provider.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.recentQueries));
}
