import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Logbook rules and their run history (#3513). Every column is keyed by
/// entity: names like `trigger` and `field` mean different things elsewhere.
final Map<String, ConflictField> ruleOverrides = {
  'rules.triggers': ConflictField(
    (l) => l.settings_conflict_field_ruleTriggers,
    FieldKind.shortText,
  ),
  'rules.conditionJson': ConflictField(
    (l) => l.settings_conflict_field_ruleCondition,
    FieldKind.opaque,
  ),
  'rules.actionsJson': ConflictField(
    (l) => l.settings_conflict_field_ruleActions,
    FieldKind.opaque,
  ),
  'ruleRuns.trigger': ConflictField(
    (l) => l.settings_conflict_field_ruleRunTrigger,
    FieldKind.shortText,
  ),
  'ruleRuns.sourceLabel': ConflictField(
    (l) => l.settings_conflict_field_ruleRunSource,
    FieldKind.shortText,
  ),
  'ruleRuns.deviceLabel': ConflictField(
    (l) => l.settings_conflict_field_ruleRunDevice,
    FieldKind.shortText,
  ),
  'ruleRuns.ranAt': ConflictField(
    (l) => l.settings_conflict_field_ruleRunAt,
    FieldKind.dateTime,
  ),
  'ruleRuns.changedCount': ConflictField(
    (l) => l.settings_conflict_field_ruleRunChangedCount,
    FieldKind.number,
  ),
  'ruleRuns.undoneAt': ConflictField(
    (l) => l.settings_conflict_field_ruleRunUndoneAt,
    FieldKind.dateTime,
  ),
  'ruleRunChanges.runId': ConflictField(
    (l) => l.settings_conflict_field_ruleRun,
    FieldKind.opaque,
  ),
  'ruleRunChanges.targetId': ConflictField(
    (l) => l.settings_conflict_field_ruleTarget,
    FieldKind.opaque,
  ),
  'ruleRunChanges.ruleName': ConflictField(
    (l) => l.settings_conflict_field_ruleName,
    FieldKind.shortText,
  ),
  'ruleRunChanges.field': ConflictField(
    (l) => l.settings_conflict_field_ruleChangeField,
    FieldKind.shortText,
  ),
  'ruleRunChanges.beforeJson': ConflictField(
    (l) => l.settings_conflict_field_ruleChangeBefore,
    FieldKind.opaque,
  ),
  'ruleRunChanges.afterJson': ConflictField(
    (l) => l.settings_conflict_field_ruleChangeAfter,
    FieldKind.opaque,
  ),
};
