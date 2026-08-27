/// Combined "career" lifetime totals: app-logged dives plus a per-diver
/// manually-entered offset of dives/time accumulated before the diver started
/// using Submersion (issue #331). Pure value object (no I/O) so the combine
/// logic is unit-testable in isolation.
class CareerTotals {
  final int loggedDives;
  final int loggedTimeSeconds;
  final int priorDives;
  final int priorTimeSeconds;

  /// The date to show as "Diving since". Non-null only when the diver entered
  /// a value (then reconciled to be no later than their first logged dive).
  final DateTime? divingSinceResolved;

  const CareerTotals._({
    required this.loggedDives,
    required this.loggedTimeSeconds,
    required this.priorDives,
    required this.priorTimeSeconds,
    required this.divingSinceResolved,
  });

  factory CareerTotals.from({
    required int loggedDives,
    required int loggedTimeSeconds,
    DateTime? firstLoggedDive,
    int? priorDives,
    int? priorTimeSeconds,
    DateTime? divingSince,
  }) {
    final pDives = (priorDives == null || priorDives < 0) ? 0 : priorDives;
    final pTime = (priorTimeSeconds == null || priorTimeSeconds < 0)
        ? 0
        : priorTimeSeconds;

    DateTime? resolved;
    if (divingSince != null) {
      resolved =
          (firstLoggedDive != null && firstLoggedDive.isBefore(divingSince))
          ? firstLoggedDive
          : divingSince;
    }

    return CareerTotals._(
      loggedDives: loggedDives,
      loggedTimeSeconds: loggedTimeSeconds,
      priorDives: pDives,
      priorTimeSeconds: pTime,
      divingSinceResolved: resolved,
    );
  }

  int get combinedDives => loggedDives + priorDives;
  int get combinedTimeSeconds => loggedTimeSeconds + priorTimeSeconds;

  bool get hasPriorDives => priorDives > 0;
  bool get hasPriorTime => priorTimeSeconds > 0;
  bool get hasPriorExperience =>
      hasPriorDives || hasPriorTime || divingSinceResolved != null;

  /// "Xh Ym" formatting, matching DiveStatistics. Used for the headline total
  /// AND the logged/prior breakdown so they always reconcile -- no dropped
  /// minutes, and no misleading "0h" when prior time is under an hour.
  static String _formatHm(int seconds) {
    final d = Duration(seconds: seconds);
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  String get loggedTimeFormatted => _formatHm(loggedTimeSeconds);
  String get priorTimeFormatted => _formatHm(priorTimeSeconds);
  String get combinedTimeFormatted => _formatHm(combinedTimeSeconds);
}
