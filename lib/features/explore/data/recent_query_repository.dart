import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/fuzzy_match.dart' as fuzzy;
import 'package:submersion/features/explore/domain/query_model.dart';

const _log = LoggerService('RecentQueries');

/// Whether a recent search was typed into the field or asked of the model.
enum RecentQueryKind { typed, asked }

class RecentQuery {
  final String sentence;
  final String locale;
  final RecentQueryKind kind;

  /// A typed search's query, stored as its tree so it prints in the
  /// diver's current units; null for an asked sentence.
  final QueryNode? node;

  /// The stored parse, or null when an older prompt wrote it and the
  /// sentence must be asked again (see [kMinReplayableQuerySchemaVersion]).
  final ParsedQuery? parsed;
  final DateTime lastUsedAt;
  const RecentQuery({
    required this.sentence,
    required this.locale,
    required this.parsed,
    required this.lastUsedAt,
    this.kind = RecentQueryKind.asked,
    this.node,
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

  /// A typed search's key: its tree with the ref labels left out, so a
  /// rename does not split one search into two rows (the list prints the
  /// current names), compared like a sentence (case, accents). Prefixed, so
  /// it never meets an asked key; those stay as the v18 rows have them.
  static String typedKeyFor(QueryNode node) =>
      'typed:${keyFor(jsonEncode(queryNodeToJson(_withoutLabels(node))))}';

  static QueryNode _withoutLabels(QueryNode node) => switch (node) {
    AndNode(:final children) => AndNode(children.map(_withoutLabels).toList()),
    OrNode(:final children) => OrNode(children.map(_withoutLabels).toList()),
    NotNode(:final child) => NotNode(_withoutLabels(child)),
    ScopedNode(:final path, :final inner) => ScopedNode(
      path,
      _withoutLabels(inner),
    ),
    ConditionNode(:final path, :final op, :final value) => ConditionNode(
      path,
      op,
      switch (value) {
        RefValue(:final id) => RefValue(id, ''),
        ListValue(:final items) => ListValue([
          for (final i in items) i is RefValue ? RefValue(i.id, '') : i,
        ]),
        _ => value,
      },
    ),
    TextNode() => node,
  };

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
      if (r.kind == RecentQueryKind.typed.name) {
        final node = _readTyped(r.parsedJson);
        if (node == null) {
          stale.add(r.key);
        } else {
          out.add(
            RecentQuery(
              sentence: r.sentence,
              locale: r.locale,
              parsed: null,
              kind: RecentQueryKind.typed,
              node: node,
              lastUsedAt: DateTime.fromMillisecondsSinceEpoch(r.lastUsedAt),
            ),
          );
        }
        continue;
      }
      if (r.schemaVersion < kMinReadableQuerySchemaVersion ||
          r.schemaVersion > kQuerySchemaVersion) {
        stale.add(r.key);
        continue;
      }
      try {
        final parsed = r.schemaVersion < kMinReplayableQuerySchemaVersion
            ? null
            : ParsedQuery.fromJson(
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

  /// A typed row's tree, or null (logged) when this build cannot read it:
  /// bad JSON, not an object, or an unknown node or value.
  static QueryNode? _readTyped(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) throw const FormatException('not an object');
      return queryNodeFromJson(decoded.cast<String, Object?>());
    } on QueryJsonException catch (e) {
      _log.warning('Dropping a typed recent: ${e.message}');
    } on FormatException catch (e) {
      _log.warning('Dropping a typed recent: ${e.message}');
    }
    return null;
  }

  Future<void> record(
    String sentence,
    String locale,
    ParsedQuery parsed, {
    required String diverId,
  }) => _upsert(
    diverId: diverId,
    key: keyFor(sentence),
    sentence: sentence,
    locale: locale,
    json: jsonEncode(parsed.toJson()),
    schemaVersion: parsed.schemaVersion,
    subject: parsed.subject.name,
    kind: RecentQueryKind.asked,
  );

  /// A query the diver typed and committed (#2773). Stored as its tree, so
  /// it prints in the diver's current units when shown.
  Future<void> recordTyped(
    String text,
    QueryNode node, {
    required String locale,
    required String diverId,
  }) => _upsert(
    diverId: diverId,
    key: typedKeyFor(node),
    sentence: text,
    locale: locale,
    json: jsonEncode(queryNodeToJson(node)),
    schemaVersion: 0,
    subject: 'dives',
    kind: RecentQueryKind.typed,
  );

  /// Writes (or bumps) one row, then trims the diver's list.
  Future<void> _upsert({
    required String diverId,
    required String key,
    required String sentence,
    required String locale,
    required String json,
    required int schemaVersion,
    required String subject,
    required RecentQueryKind kind,
  }) async {
    await _db
        .into(_db.recentQueries)
        .insertOnConflictUpdate(
          RecentQueriesCompanion(
            diverId: Value(diverId),
            key: Value(key),
            sentence: Value(sentence),
            locale: Value(locale),
            parsedJson: Value(json),
            schemaVersion: Value(schemaVersion),
            subject: Value(subject),
            kind: Value(kind.name),
            lastUsedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    await _trim(diverId);
  }

  /// Keeps the diver's newest [cap] rows; another diver's are theirs.
  Future<void> _trim(String diverId) => _db.customStatement(
    'DELETE FROM recent_queries WHERE diver_id = ? AND rowid NOT IN '
    '(SELECT rowid FROM recent_queries WHERE diver_id = ? '
    'ORDER BY last_used_at DESC LIMIT $cap)',
    [diverId, diverId],
  );

  /// Change tick for the list provider.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.recentQueries));
}
