/// The canonical SQL predicate deciding which dives contribute to
/// *descriptive* statistics.
///
/// Every term is written in the affirmative: it states what a dive must be in
/// order to *count*. Two always apply:
///
/// - `excluded_from_stats = 0` keeps dives the diver has NOT ticked "exclude
///   from statistics" on (issue #526). A dive they did tick, say a 90 minute
///   session at 12 ft that is not an official dive by most agency standards,
///   has the column set to 1 and is dropped here.
/// - `is_planned = 0` keeps dives that actually happened, dropping entries the
///   planner created for a dive that was never made. Nothing filtered on this
///   before, so a planned dive inflated every total; that is a behaviour fix
///   carried by this predicate, not by the migration, which only adds columns.
///
/// The [gas] variant adds two more, for SAC/RMV and gas-mix aggregates:
///
/// - `excluded_from_gas_stats = 0` keeps dives the diver has NOT ticked
///   "exclude from gas statistics" on (issue #1272). They tick it when the
///   gas figure is unrepresentative, say after purging the tank down to
///   500 psi for an end-of-dive weight check.
/// - `dive_mode <> 'gauge'` keeps dives that are not gauge-mode, which carry
///   no usable gas data. This rule predates the exclusion flags and was
///   hand-copied into seven queries in InsightsRepository; it now lives
///   here, which is the point.
///
/// The [consumptionRate] variant adds one more to the gas variant, for SAC
/// and RMV averages, trends and records (issue #3673):
///
/// - `dive_mode NOT IN ('ccr', 'scr')` keeps open-circuit dives. A
///   rebreather's cylinders do not drain with the diver's breathing, so
///   their drop is not a consumption rate, as `DerivedMetricsService` and
///   `Dive.sac` already hold. It stays out of the gas variant because the
///   gas mixes and the litres drawn on a loop are still real: gas-mix
///   counts, gas used and the SAC breakdown by cylinder role keep these
///   dives.
///
/// **This is deliberately NOT folded into `buildFilteredDiveIdSubquery`.**
/// That function implements the diver's transient *view* filter and correctly
/// returns an empty no-op when no axis is active. This scope is a persistent
/// property of the dive and must apply unconditionally. Merging the two would
/// either make the exclusion evaporate for every diver who never opens the
/// filter sheet, or silently scope the deliberately-unfiltered surfaces
/// (dashboard quick stats, the dive-log summary while the list is unfiltered,
/// species detail page).
///
/// **Operational counts deliberately ignore this scope.** Equipment service
/// intervals, course-requirement progress, and the logbook list header all
/// count excluded dives on purpose; each carries a doc comment saying so. A
/// practice dive still cycled the regulator, and a dive the diver linked to a
/// course requirement was linked on purpose.
///
/// See
/// `docs/design/specs/2026-08-28-exclude-dive-from-statistics-design.md`.
class DiveStatsScope {
  const DiveStatsScope._();

  /// The rebreather dive modes as an SQL list, for `dive_mode IN ...`: the
  /// one place the rule's modes are written, so the scope and the per-dive
  /// SAC SQL (`diveSacPressureSql`) cannot drift apart.
  static const String rebreatherModesSql = "('ccr', 'scr')";

  /// The bare predicate, with no leading conjunction. Use when the query has
  /// no WHERE clause yet: `WHERE ${DiveStatsScope.predicate()}`.
  ///
  /// [alias] must match the alias the query already gives the `dives` table
  /// (or `dives` itself when the query does not alias it). Queries that join
  /// `dives` to itself need one call per alias. [consumptionRate] implies
  /// [gas].
  static String predicate({
    String alias = 'd',
    bool gas = false,
    bool consumptionRate = false,
  }) {
    final parts = <String>[
      '$alias.excluded_from_stats = 0',
      '$alias.is_planned = 0',
    ];
    if (gas || consumptionRate) {
      parts.add('$alias.excluded_from_gas_stats = 0');
      parts.add("$alias.dive_mode <> 'gauge'");
    }
    if (consumptionRate) {
      parts.add('$alias.dive_mode NOT IN $rebreatherModesSql');
    }
    return parts.join(' AND ');
  }

  /// The predicate prefixed with ` AND `, for appending into an existing
  /// WHERE clause. Emits no bind placeholders, so callers never thread params
  /// for the scope.
  static String and({
    String alias = 'd',
    bool gas = false,
    bool consumptionRate = false,
  }) {
    final scope = predicate(
      alias: alias,
      gas: gas,
      consumptionRate: consumptionRate,
    );
    return ' AND $scope';
  }
}
