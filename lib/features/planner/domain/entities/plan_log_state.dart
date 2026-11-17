import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Where a planned dive stands in the log (issue #4203): the rule the
/// planned dives writer and an agent's plan documents share.
enum PlanLogState {
  /// No entry in the log: never written there, or its entry was deleted
  /// since, which leaves a link to nothing.
  planned('planned'),

  /// Written to the log as a planned entry, not yet dived.
  loggedAsPlanned('logged_as_planned'),

  /// Its entry has been dived: the log owns it now.
  dived('dived');

  const PlanLogState(this.wireName);

  /// The name an agent sees.
  final String wireName;

  /// The state of a dive whose entry in the log is [entry], or null for
  /// none.
  static PlanLogState of(Dive? entry) => ofPlannedFlag(entry?.isPlanned);

  /// The same rule read from the entry's `is_planned` flag alone, for a
  /// reader that needs nothing else of the entry: null when there is no
  /// entry.
  static PlanLogState ofPlannedFlag(bool? isPlanned) => switch (isPlanned) {
    null => PlanLogState.planned,
    true => PlanLogState.loggedAsPlanned,
    false => PlanLogState.dived,
  };
}
