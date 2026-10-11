import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';

/// The CASE branches that turn a dive row's visibility into a distribution
/// key, shared by the visibility distribution and the Focus factor rows so
/// the two can never disagree (issue #3226).
///
/// Keys: a [VisibilityBand] name for a measured distance, and for a range
/// that sits wholly inside one band; [visibilityRangeSpanningKey] for a range
/// that crosses a band edge. A measured distance wins over a range on the
/// same row, as in every other reader. The caller adds the legacy `ELSE`.
///
/// The range branch is the SQL twin of [VisibilityScale.bandForRange]; keep
/// them in step. A NULL end makes its comparison NULL, which reads as false,
/// so an open end never satisfies a bound on that side.
abstract final class VisibilityBandSql {
  /// The WHEN branches over columns prefixed by [prefix] (`''` or `'d.'`).
  static String whenBranches(String prefix) {
    final p = prefix;
    return '''
      WHEN ${p}visibility_meters IS NOT NULL THEN
        CASE
          WHEN ${p}visibility_meters >= ? THEN 'excellent'
          WHEN ${p}visibility_meters >= ? THEN 'good'
          WHEN ${p}visibility_meters >= ? THEN 'moderate'
          ELSE 'poor'
        END
      WHEN ${p}visibility_min_meters IS NOT NULL
        OR ${p}visibility_max_meters IS NOT NULL THEN
        CASE
          WHEN ${p}visibility_min_meters >= ? THEN 'excellent'
          WHEN ${p}visibility_min_meters >= ?
            AND ${p}visibility_max_meters <= ? THEN 'good'
          WHEN ${p}visibility_min_meters >= ?
            AND ${p}visibility_max_meters <= ? THEN 'moderate'
          WHEN ${p}visibility_max_meters <= ? THEN 'poor'
          ELSE '$visibilityRangeSpanningKey'
        END''';
  }

  /// The values [whenBranches] binds, in placeholder order.
  static List<double> params(VisibilityScale s) => [
    s.excellentAtOrAboveM,
    s.goodAtOrAboveM,
    s.moderateAtOrAboveM,
    s.excellentAtOrAboveM,
    s.goodAtOrAboveM,
    s.excellentAtOrAboveM,
    s.moderateAtOrAboveM,
    s.goodAtOrAboveM,
    s.moderateAtOrAboveM,
  ];
}
