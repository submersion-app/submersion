import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// Why a stored rule cannot run as it stands. The first four mirror
/// `SavedQueryProblem` for the condition; [newerVersion] means the action
/// list was written by a newer app.
enum RuleLoadProblem {
  unreadable,
  invalid,
  unknownSubject,
  unresolvedRef,
  newerVersion,
}

/// A diver's logbook rule (#3513): when [condition] matches a dive or site,
/// apply [actions] in order. [conditionJson] and [actionsJson] are the
/// stored forms, kept so a rule that loads with a [problem] is saved back
/// unchanged.
class Rule {
  const Rule({
    required this.id,
    required this.diverId,
    required this.subject,
    required this.name,
    required this.enabled,
    required this.triggers,
    required this.condition,
    required this.conditionJson,
    required this.actions,
    required this.actionsJson,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.problem,
  });

  final String id;
  final String? diverId;
  final RuleSubject subject;
  final String name;
  final bool enabled;
  final Set<RuleTrigger> triggers;

  /// Null matches every eligible dive or site.
  final QueryNode? condition;
  final String conditionJson;
  final List<RuleAction> actions;
  final String actionsJson;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RuleLoadProblem? problem;

  /// Only a rule that loaded cleanly, does something, and holds no action
  /// from a newer version may run.
  bool get isRunnable =>
      problem == null &&
      actions.isNotEmpty &&
      !actions.any((a) => a is UnknownRuleAction);

  Rule copyWith({
    String? name,
    bool? enabled,
    Set<RuleTrigger>? triggers,
    QueryNode? condition,
    bool clearCondition = false,
    String? conditionJson,
    List<RuleAction>? actions,
    String? actionsJson,
    int? sortOrder,
    DateTime? updatedAt,
    RuleLoadProblem? problem,
    bool clearProblem = false,
  }) => Rule(
    id: id,
    diverId: diverId,
    subject: subject,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    triggers: triggers ?? this.triggers,
    condition: clearCondition ? null : condition ?? this.condition,
    conditionJson: conditionJson ?? this.conditionJson,
    actions: actions ?? this.actions,
    actionsJson: actionsJson ?? this.actionsJson,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    problem: clearProblem ? null : problem ?? this.problem,
  );
}
