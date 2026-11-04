import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/checklist_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/saved_query_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/json_object_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart'
    show BulkField;
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_actions_json.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// A rule's actions as the store keeps them, or a refusal: a list this
/// version reads, with one action at least and none it does not know.
Map<String, Object?> _actions(Map<String, Object?> raw) {
  final List<RuleAction> actions;
  try {
    actions = ruleActionsFromJson(raw);
  } on RuleJsonException catch (e) {
    throw FieldRefusal('These actions cannot be read: ${e.message}.');
  }
  if (actions.isEmpty) {
    throw const FieldRefusal('A rule does at least one thing.');
  }
  if (actions.any((a) => a is UnknownRuleAction)) {
    throw const FieldRefusal('An action is of a kind this app does not know.');
  }
  return ruleActionsToJson(actions);
}

/// Automation rules, through the repository the rule edit page saves with.
/// A save never runs a rule. A rule a newer version wrote, or one holding
/// an action this version does not know, is read only, as the page shows it.
class RuleWrites extends WritableEntry {
  RuleWrites(this._r);

  final RecordRepositories _r;

  static const _copy = 'duplicate_of';

  @override
  String get name => 'rules';

  @override
  String get table => 'rules';

  @override
  String get note =>
      'condition is a stored query, {"version": 1, "node": ...}, as saved '
      'queries hold one, or null to match everything; actions is '
      '{"version": 1, "actions": [...]}, at least one. sort_order is the '
      'place among the profile\'s rules of the subject, which run in order.';

  @override
  late final Map<String, FieldCodec> fields = {
    'subject': FieldCodec.enumName(RuleSubject.values),
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'enabled': const FieldCodec.flag(),
    'triggers': FieldCodec.enumSet(RuleTrigger.values, min: 1),
    'condition': const JsonObjectCodec(
      shape: 'a stored query object',
      nullable: true,
    ),
    'actions': const JsonObjectCodec(
      shape: 'an actions object',
      normalize: _actions,
    ),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
    _copy: const FieldCodec.reference('rules'),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get createOnly => const {'subject', _copy};

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => values[_copy] == null
      ? {'triggers': RuleTrigger.afterImport.name}
      : const {};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final v = check.values;
    final String subject;
    if (check.kind == ChangeKind.create) {
      // A rule, new or copied, joins the end of its subject's order.
      if (v['sort_order'] != null) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'sort_order: a new rule goes last; move it with an update.',
        );
      }
      if (v[_copy] case final String from) {
        subject = (await _rule(from, check.ownerId)).subject.name;
      } else {
        final missing = [
          for (final key in const ['subject', 'name', 'actions'])
            if (v[key] == null) key,
        ];
        if (missing.isNotEmpty) {
          return PlanBlock(
            BlockReason.missingField,
            'A new rules record needs ${missing.join(', ')}, or $_copy.',
          );
        }
        subject = v['subject']! as String;
      }
    } else {
      final rule = await _rule(check.id!, check.ownerId);
      if (rule.problem == RuleLoadProblem.newerVersion ||
          rule.actions.any((a) => a is UnknownRuleAction)) {
        return const PlanBlock(
          BlockReason.notPermitted,
          'A newer version of the app wrote this rule; it is read only here.',
        );
      }
      if (check.kind == ChangeKind.delete) return null;
      if (v['sort_order'] case final int at
          when at >= (await _order(rule.subject, check.ownerId)).length) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'sort_order: past the last of this subject\'s rules.',
        );
      }
      subject = rule.subject.name;
    }
    if (v['actions'] case final String actions) {
      final problem = await _actionRefsProblem(
        ruleActionsFromJson(JsonObjectCodec.decoded(actions)),
        check.ownerId,
      );
      if (problem != null) return problem;
    }
    if (v['condition'] case final String condition) {
      return (await checkedQuery(
        _r,
        key: 'condition',
        subject: RuleSubject.values.byName(subject).querySubject.name,
        query: JsonObjectCodec.decoded(condition),
        diverId: check.ownerId,
      )).problem;
    }
    return null;
  }

  /// Why [actions] name a record [ownerId] cannot use, or null: the rule
  /// page offers the profile's own tags, buddies, gear, courses, types,
  /// roles, centers and trips, and the applier only checks that an id
  /// exists when the rule runs.
  Future<PlanBlock?> _actionRefsProblem(
    List<RuleAction> actions,
    String? ownerId,
  ) async {
    if (ownerId == null) return null;
    final named = <String, Set<String>>{};
    void add(String entity, Iterable<String?> ids) =>
        (named[entity] ??= {}).addAll(ids.nonNulls);
    for (final action in actions) {
      switch (action) {
        case DiveMembershipAction(:final collection, :final ids):
          add(switch (collection) {
            DiveCollection.diveTypes => 'dive_types',
            DiveCollection.tags => 'tags',
            DiveCollection.equipment => 'equipment',
            DiveCollection.buddies => 'buddies',
            DiveCollection.courses => 'courses',
          }, ids);
          add('dive_roles', [action.buddyRoleId]);
        case SiteMembershipAction(:final collection, :final ids):
          add(switch (collection) {
            SiteCollection.tags => 'tags',
            SiteCollection.siteTypes => 'site_types',
          }, ids);
        case SetDiveFieldAction(:final field, :final values):
          switch (field) {
            case BulkField.diveCenter:
              add('centers', [values['diveCenterId'] as String?]);
            case BulkField.trip:
              add('trips', [values['tripId'] as String?]);
            default:
              break;
          }
        default:
          break;
      }
    }
    final catalog = RecordCatalog(_r);
    final reader = RecordReader(_r.db);
    for (final MapEntry(key: entity, value: ids) in named.entries) {
      if (ids.isEmpty) continue;
      final entry = catalog.named(entity);
      final hidden = ids.difference(
        (await reader.visibleIds(entry, ids.toList(), ownerId)).toSet(),
      );
      for (final id in hidden) {
        final exists = await countRows(entry.table, 'id = ?1', id) > 0;
        return PlanBlock(
          exists
              ? BlockReason.otherProfileReference
              : BlockReason.unknownReference,
          exists
              ? 'actions: $entity $id belongs to another profile.'
              : 'actions: no $entity record has id $id.',
        );
      }
    }
    return null;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final repo = _r.rules;
    if (values[_copy] case final String from) {
      final copy = await repo.duplicate(from, nameSuffix: ' (copy)');
      final rest = {...values}..remove(_copy);
      if (rest.isNotEmpty) await _update(copy, diverId, rest);
      return copy;
    }
    final id = await repo.create(
      diverId: diverId,
      subject: RuleSubject.values.byName(values['subject']! as String),
      name: values['name']! as String,
      triggers: _triggers(values['triggers']),
      condition: switch (values['condition']) {
        final String c => queryNodeFromJson(JsonObjectCodec.decoded(c)),
        _ => null,
      },
      actions: ruleActionsFromJson(JsonObjectCodec.decoded(values['actions'])),
    );
    if (values['enabled'] == false) await repo.setEnabled(id, false);
    return id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) =>
      _update(id, ownerId, update.values);

  Future<void> _update(
    String id,
    String? ownerId,
    Map<String, Object?> v,
  ) async {
    final repo = _r.rules;
    final rule = await _rule(id, ownerId);
    if (v.keys.any((k) => k != 'sort_order')) {
      await repo.update(
        Rule(
          id: id,
          diverId: rule.diverId,
          subject: rule.subject,
          name: v['name'] as String? ?? rule.name,
          enabled: v['enabled'] as bool? ?? rule.enabled,
          triggers: v.containsKey('triggers')
              ? _triggers(v['triggers'])
              : rule.triggers,
          condition: v.containsKey('condition')
              ? switch (v['condition']) {
                  final String c => queryNodeFromJson(
                    JsonObjectCodec.decoded(c),
                  ),
                  _ => null,
                }
              : rule.condition,
          conditionJson: rule.conditionJson,
          actions: v.containsKey('actions')
              ? ruleActionsFromJson(JsonObjectCodec.decoded(v['actions']))
              : rule.actions,
          actionsJson: rule.actionsJson,
          sortOrder: rule.sortOrder,
          createdAt: rule.createdAt,
          updatedAt: rule.updatedAt,
          // A rule that loaded with a problem keeps its stored condition
          // unless this change replaces it.
          problem: v.containsKey('condition') ? null : rule.problem,
        ),
      );
    }
    if (v['sort_order'] case final int at) {
      await repo.reorder(placed(await _order(rule.subject, ownerId), id, at));
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.rules.delete(id);

  Future<Rule> _rule(String id, String? ownerId) async =>
      await _r.rules.getById(id, names: await queryNames(_r, ownerId)) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Rule $id no longer exists.',
        details: {'id': id},
      ));

  /// The profile's rules of [subject], in run order.
  Future<List<String>> _order(RuleSubject subject, String? ownerId) async {
    if (ownerId == null) return const [];
    final rows = [
      for (final row in await _r.rules.rowsFor(ownerId))
        if (row.subject == subject.name) row,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [for (final row in rows) row.id];
  }

  static Set<RuleTrigger> _triggers(Object? parsed) => {
    for (final name in '${parsed ?? ''}'.split(','))
      if (name.isNotEmpty) RuleTrigger.values.byName(name),
  };
}
