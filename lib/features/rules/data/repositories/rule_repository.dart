import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_actions_json.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// Logbook rules (#3513): create, update, reorder, duplicate, delete, each
/// stamped for sync like the saved queries repository. A diver sees only
/// their own rules.
class RuleRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(RuleRepository);

  static const entityType = 'rules';

  /// Emits whenever the `rules` table changes (a local write or a sync).
  Stream<void> watchRulesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.rules));

  /// [diverId]'s rules as stored, conditions and actions unread: enough to
  /// tell which would run.
  Future<List<RuleRow>> rowsFor(String diverId) =>
      (_db.select(_db.rules)..where((t) => t.diverId.equals(diverId))).get();

  /// [diverId]'s rules for [subject], in run order. [names] resolves the
  /// condition's references so a rule naming a deleted site or buddy loads
  /// with [RuleLoadProblem.unresolvedRef].
  Future<List<Rule>> getAll({
    required RuleSubject subject,
    required String diverId,
    required NameIndex names,
  }) async {
    final rows =
        await (_db.select(_db.rules)
              ..where(
                (t) =>
                    t.subject.equals(subject.name) & t.diverId.equals(diverId),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.name),
              ]))
            .get();
    return [for (final r in rows) ?_fromRow(r, names)];
  }

  Future<Rule?> getById(String id, {required NameIndex names}) async {
    final row = await (_db.select(
      _db.rules,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row, names);
  }

  Future<String> create({
    required String diverId,
    required RuleSubject subject,
    required String name,
    required Set<RuleTrigger> triggers,
    required QueryNode? condition,
    required List<RuleAction> actions,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxSort = await _maxSortOrder(subject, diverId);
      await _db
          .into(_db.rules)
          .insert(
            RulesCompanion.insert(
              id: id,
              diverId: Value(diverId),
              subject: subject.name,
              name: name.trim(),
              triggers: Value(formatRuleTriggers(triggers)),
              conditionJson: encodeRuleCondition(condition),
              actionsJson: jsonEncode(ruleActionsToJson(actions)),
              sortOrder: Value(maxSort + 1),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _stamp(id, now);
      return id;
    } catch (e, st) {
      _log.error('Failed to create rule', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Writes [rule]'s name, triggers, enabled flag, condition and actions.
  /// A rule that loaded with a problem keeps its stored JSON unless the
  /// caller replaced the parsed value, and keeps any trigger a newer
  /// version added.
  Future<void> update(Rule rule) async => _update(
    rule.id,
    RulesCompanion(
      name: Value(rule.name.trim()),
      enabled: Value(rule.enabled),
      triggers: Value(
        formatRuleTriggers(
          rule.triggers,
          keeping:
              (await (_db.select(
                    _db.rules,
                  )..where((t) => t.id.equals(rule.id))).getSingleOrNull())
                  ?.triggers ??
              '',
        ),
      ),
      conditionJson: Value(
        rule.problem == null
            ? encodeRuleCondition(rule.condition)
            : rule.conditionJson,
      ),
      actionsJson: Value(
        rule.problem == RuleLoadProblem.newerVersion
            ? rule.actionsJson
            : jsonEncode(ruleActionsToJson(rule.actions)),
      ),
    ),
  );

  Future<void> setEnabled(String id, bool enabled) =>
      _update(id, RulesCompanion(enabled: Value(enabled)));

  /// Numbers [orderedIds] 0..n-1 in the order given, in one transaction.
  Future<void> reorder(List<String> orderedIds) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (_db.update(
            _db.rules,
          )..where((t) => t.id.equals(orderedIds[i]))).write(
            RulesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          );
        }
      });
      for (final id in orderedIds) {
        await _syncRepository.markRecordPending(
          entityType: entityType,
          recordId: id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, st) {
      _log.error('Failed to reorder rules', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// A copy of [id] at the end of its list, named with [nameSuffix]
  /// (localised by the caller).
  Future<String> duplicate(String id, {required String nameSuffix}) async {
    final row = await (_db.select(
      _db.rules,
    )..where((t) => t.id.equals(id))).getSingle();
    final copy = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxSort = await _maxSortOrder(
      RuleSubject.values.byName(row.subject),
      row.diverId ?? '',
    );
    await _db
        .into(_db.rules)
        .insert(
          row
              .copyWith(
                id: copy,
                name: '${row.name}$nameSuffix',
                sortOrder: maxSort + 1,
                createdAt: now,
                updatedAt: now,
                hlc: const Value(null),
              )
              .toCompanion(false),
        );
    await _stamp(copy, now);
    return copy;
  }

  Future<void> delete(String id) async {
    try {
      await (_db.delete(_db.rules)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
      SyncEventBus.notifyLocalChange();
    } catch (e, st) {
      _log.error('Failed to delete rule $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _update(String id, RulesCompanion patch) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.rules)..where((t) => t.id.equals(id))).write(
        patch.copyWith(updatedAt: Value(now)),
      );
      await _stamp(id, now);
    } catch (e, st) {
      _log.error('Failed to update rule $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _stamp(String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<int> _maxSortOrder(RuleSubject subject, String diverId) async {
    final result = await _db
        .customSelect(
          'SELECT MAX(sort_order) AS max_order FROM rules '
          'WHERE subject = ? AND diver_id = ?',
          variables: [
            Variable<String>(subject.name),
            Variable<String>(diverId),
          ],
        )
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? -1;
  }

  /// Null for a row whose subject this version does not know.
  Rule? _fromRow(RuleRow row, NameIndex names) {
    final subject = RuleSubject.values.asNameMap()[row.subject];
    if (subject == null) return null;
    QueryNode? condition;
    RuleLoadProblem? problem;
    if (row.conditionJson.isNotEmpty) {
      final load = loadSavedQuery(
        SavedQuery(
          id: row.id,
          diverId: row.diverId,
          subject: subject.querySubject.name,
          name: row.name,
          queryJson: row.conditionJson,
          sortOrder: row.sortOrder,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
        ),
        appQueryRegistry,
        names,
      );
      condition = load.node;
      problem = switch (load.problem) {
        null => null,
        SavedQueryProblem.unreadable => RuleLoadProblem.unreadable,
        SavedQueryProblem.invalid => RuleLoadProblem.invalid,
        SavedQueryProblem.unknownSubject => RuleLoadProblem.unknownSubject,
        SavedQueryProblem.unresolvedRef => RuleLoadProblem.unresolvedRef,
      };
    }
    var actions = const <RuleAction>[];
    try {
      final decoded = jsonDecode(row.actionsJson);
      if (decoded is Map<String, dynamic>) {
        actions = ruleActionsFromJson(decoded);
      } else {
        problem ??= RuleLoadProblem.unreadable;
      }
    } on RuleJsonException catch (e) {
      problem = e.newerVersion
          ? RuleLoadProblem.newerVersion
          : problem ?? RuleLoadProblem.unreadable;
    } on FormatException {
      problem ??= RuleLoadProblem.unreadable;
    }
    return Rule(
      id: row.id,
      diverId: row.diverId,
      subject: subject,
      name: row.name,
      enabled: row.enabled,
      triggers: parseRuleTriggers(row.triggers),
      condition: condition,
      conditionJson: row.conditionJson,
      actions: actions,
      actionsJson: row.actionsJson,
      sortOrder: row.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      problem: problem,
    );
  }
}

/// The stored form of a rule condition: the versioned query JSON, or the
/// empty string for "matches everything".
String encodeRuleCondition(QueryNode? condition) =>
    condition == null ? '' : jsonEncode(queryNodeToJson(condition));

/// The condition [encodeRuleCondition] stored, or null for none or an
/// unreadable one.
QueryNode? decodeRuleCondition(String json) {
  if (json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    return decoded is Map<String, dynamic> ? queryNodeFromJson(decoded) : null;
  } on Object {
    return null;
  }
}
