import 'package:submersion/features/rules/domain/rule_subject.dart';

/// One field a rule run changed on one dive or site (#3513). [field] is a
/// `BulkField.name`, a `DiveCollection.name`, `notes`, a
/// `SiteRuleField.name`, a `SiteCollection.name` or `description`; [subject]
/// tells the dive and site meanings apart. [before] and [after] are
/// JSON-encodable: a map of column values for a set field, a sorted id list
/// (buddies: `{id, role}` maps) for a membership, the full text for an
/// append.
class RuleChange {
  const RuleChange({
    required this.subject,
    required this.targetId,
    required this.ruleId,
    required this.ruleName,
    required this.field,
    required this.before,
    required this.after,
  });

  final RuleSubject subject;
  final String targetId;

  /// Null once the rule that made the change is deleted.
  final String? ruleId;
  final String ruleName;
  final String field;
  final Object? before;
  final Object? after;
}

/// One history entry: a run of the rules that changed something.
class RuleRun {
  const RuleRun({
    required this.id,
    required this.diverId,
    required this.trigger,
    required this.sourceLabel,
    required this.deviceLabel,
    required this.ranAt,
    required this.changedCount,
    required this.undoneAt,
  });

  final String id;
  final String? diverId;
  final RuleRunTrigger trigger;
  final String? sourceLabel;
  final String? deviceLabel;
  final DateTime ranAt;

  /// Distinct dives and sites the run changed.
  final int changedCount;
  final DateTime? undoneAt;

  bool get isUndone => undoneAt != null;
}
