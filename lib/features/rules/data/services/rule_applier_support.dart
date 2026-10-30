import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/existing_row_ids.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/data/services/rule_target_scope.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';

/// What applying one action to a set of targets did (#3513).
class AppliedAction {
  const AppliedAction(this.changes, {this.skippedMissingRef = false});

  static const none = AppliedAction([]);

  /// One per target the action actually changed.
  final List<RuleChange> changes;

  /// True when the action named something that no longer exists (a deleted
  /// tag, gear item, buddy...) and was skipped, wholly or in part.
  final bool skippedMissingRef;
}

/// Queues what bulk edit queues after writing dives (quality findings,
/// sensor summaries, derived metrics, each read from fields a rule can
/// set) for the dives a run or an undo changed.
void refreshAfterRuleWrites(Iterable<String> diveIds) {
  final ids = diveIds.toSet();
  if (ids.isEmpty) return;
  scheduleQualityScan(ids);
  scheduleSensorSummaryRefresh(ids);
  scheduleDerivedMetricsRefresh(ids);
}

/// [ids] in slices of [kRuleIdChunk], so no `IN (...)` list grows past
/// SQLite's variable limit.
Iterable<List<String>> ruleIdChunks(List<String> ids) =>
    seriesIdChunks(ids, size: kRuleIdChunk);

/// `?, ?, ...` for [n] bound ids.
String ruleIdPlaceholders(int n) => List.filled(n, '?').join(', ');

/// One change [rule] made to [targetId]'s [field].
RuleChange ruleChange(
  Rule rule,
  String targetId,
  String field,
  Object? before,
  Object? after,
) => RuleChange(
  subject: rule.subject,
  targetId: targetId,
  ruleId: rule.id,
  ruleName: rule.name,
  field: field,
  before: before,
  after: after,
);

/// [ids] that still exist in [table], in order, and whether any did not:
/// an action naming a deleted item skips it and says so.
Future<({List<String> present, bool missing})> presentRefs(
  AppDatabase db,
  TableInfo<Table, dynamic> table,
  List<String> ids,
) async {
  final exists = await existingRowIds(db, table, ids);
  final present = [
    for (final id in ids)
      if (exists.contains(id)) id,
  ];
  return (present: present, missing: present.length < ids.toSet().length);
}

/// Each target's linked ids from a junction [table], sorted, keyed by the
/// target id in [ownerColumn]. Targets with no links map to an empty list.
Future<Map<String, List<String>>> linkedIds(
  AppDatabase db, {
  required String table,
  required String ownerColumn,
  required String linkColumn,
  required List<String> ownerIds,
}) async {
  final out = {for (final id in ownerIds) id: <String>[]};
  for (final chunk in ruleIdChunks(ownerIds)) {
    final rows = await db
        .customSelect(
          'SELECT $ownerColumn AS o, $linkColumn AS l FROM $table '
          'WHERE $ownerColumn IN (${ruleIdPlaceholders(chunk.length)})',
          variables: [for (final id in chunk) Variable.withString(id)],
        )
        .get();
    for (final r in rows) {
      out[r.read<String>('o')]!.add(r.read<String>('l'));
    }
  }
  for (final list in out.values) {
    list.sort();
  }
  return out;
}

/// Each row's [columns] from [table], as stored (booleans read back as
/// 0/1), keyed by id.
Future<Map<String, Map<String, Object?>>> columnValues(
  AppDatabase db, {
  required String table,
  required List<String> columns,
  required List<String> ids,
}) async {
  final out = <String, Map<String, Object?>>{};
  for (final chunk in ruleIdChunks(ids)) {
    final rows = await db
        .customSelect(
          'SELECT id, ${columns.join(', ')} FROM $table '
          'WHERE id IN (${ruleIdPlaceholders(chunk.length)})',
          variables: [for (final id in chunk) Variable.withString(id)],
        )
        .get();
    for (final r in rows) {
      out[r.read<String>('id')] = {for (final c in columns) c: r.data[c]};
    }
  }
  return out;
}

/// A value as SQLite stores it, so a written value compares equal to the
/// same value read back.
Object? storedForm(Object? v) => v is bool ? (v ? 1 : 0) : v;

/// Whether two column maps hold the same values (3 equals 3.0).
bool sameColumns(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key)) return false;
    if (storedForm(e.value) != storedForm(b[e.key])) return false;
  }
  return true;
}

/// Whether two sorted lists hold the same items.
bool sameList(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].toString() != b[i].toString()) return false;
  }
  return true;
}
