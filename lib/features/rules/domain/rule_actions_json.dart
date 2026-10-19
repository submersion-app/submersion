import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

/// The stored shape of a rule's action list (#3513). Bump when an action's
/// shape changes; [ruleActionsFromJson] refuses newer versions rather than
/// guessing. A new action KIND, or a new field, collection or mode inside a
/// known kind, does not need a bump: older versions keep that action as an
/// [UnknownRuleAction] and refuse to run the rule.
const int kRuleActionsJsonVersion = 1;

/// A stored action list that cannot be read.
class RuleJsonException implements Exception {
  const RuleJsonException(this.message, {this.newerVersion = false});

  final String message;

  /// The list was written by a newer version of the app, rather than
  /// malformed: the rule is kept as stored, never rewritten here.
  final bool newerVersion;

  @override
  String toString() => 'RuleJsonException: $message';
}

Map<String, Object?> ruleActionsToJson(List<RuleAction> actions) => {
  'version': kRuleActionsJsonVersion,
  'actions': [for (final a in actions) _action(a)],
};

Map<String, Object?> _action(RuleAction a) => switch (a) {
  SetDiveFieldAction(:final field, :final values) => {
    'kind': 'setDiveField',
    'field': field.name,
    'values': values,
  },
  DiveMembershipAction(
    :final collection,
    :final mode,
    :final ids,
    :final buddyRoleId,
  ) =>
    {
      'kind': 'diveMembership',
      'collection': collection.name,
      'mode': mode.name,
      'ids': ids,
      'role': ?buddyRoleId,
    },
  AppendDiveNotesAction(:final text) => {
    'kind': 'appendDiveNotes',
    'text': text,
  },
  SetSiteFieldAction(:final field, :final value) => {
    'kind': 'setSiteField',
    'field': field.name,
    'value': value,
  },
  SiteMembershipAction(:final collection, :final mode, :final ids) => {
    'kind': 'siteMembership',
    'collection': collection.name,
    'mode': mode.name,
    'ids': ids,
  },
  AppendSiteDescriptionAction(:final text) => {
    'kind': 'appendSiteDescription',
    'text': text,
  },
  UnknownRuleAction(:final raw) => raw,
};

List<RuleAction> ruleActionsFromJson(Map<String, Object?> json) {
  final version = json['version'];
  if (version is! int) {
    throw const RuleJsonException('missing version');
  }
  if (version > kRuleActionsJsonVersion) {
    throw RuleJsonException(
      'version $version is newer than this app',
      newerVersion: true,
    );
  }
  final list = json['actions'];
  if (list is! List) throw const RuleJsonException('actions is not a list');
  return [
    for (final raw in list)
      if (raw is Map)
        _fromJson(raw.cast<String, Object?>())
      else
        throw const RuleJsonException('action is not an object'),
  ];
}

RuleAction _fromJson(Map<String, Object?> j) {
  try {
    return switch (j['kind']) {
      'setDiveField' => SetDiveFieldAction(
        _enum(BulkField.values, j['field']),
        (j['values']! as Map).cast<String, Object?>(),
      ),
      'diveMembership' => DiveMembershipAction(
        _enum(DiveCollection.values, j['collection']),
        _enum(MembershipMode.values, j['mode']),
        _ids(j['ids']),
        buddyRoleId: j['role'] as String?,
      ),
      'appendDiveNotes' => AppendDiveNotesAction(j['text']! as String),
      'setSiteField' => SetSiteFieldAction(
        _enum(SiteRuleField.values, j['field']),
        j['value']!,
      ),
      'siteMembership' => SiteMembershipAction(
        _enum(SiteCollection.values, j['collection']),
        _enum(MembershipMode.values, j['mode']),
        _ids(j['ids']),
      ),
      'appendSiteDescription' => AppendSiteDescriptionAction(
        j['text']! as String,
      ),
      _ => UnknownRuleAction(j),
    };
  } on _NewerValue {
    // Kept as stored: never run, and saved back unchanged, so editing the
    // rule here cannot erase what the newer version wrote.
    return UnknownRuleAction(j);
  } on RuleJsonException {
    rethrow;
  } on Object catch (e) {
    throw RuleJsonException('malformed ${j['kind']} action: $e');
  }
}

/// A name this version's enum lacks: a field, collection or mode a newer
/// version added.
class _NewerValue implements Exception {
  const _NewerValue();
}

T _enum<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) throw RuleJsonException('unknown value $name');
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw const _NewerValue();
}

List<String> _ids(Object? raw) => [for (final id in raw! as List) id as String];
