import 'dart:math' as math;

import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';

/// Keeps a date chart's [ChartViewport] and its [TrendRange] in step.
///
/// The chart hands it the range its caller asked for and the data's x span
/// on every build; the seater decides whether that means a new window. It
/// also turns a settled viewport back into a range to report.
class TrendWindowSeater {
  /// The narrowest window a zoom can reach: a week, however long the data.
  static const minWindow = Duration(days: 7);

  TrendRange? _appliedRange;

  /// The last range [report] produced. A caller that stores it passes it
  /// straight back, which must not re-seat the viewport the diver is looking
  /// at; a caller that ignores it must not snap the chart back either.
  TrendRange? _reportedRange;
  ({int first, int last})? _appliedSpan;

  /// Full x range of the last [seat], for turning a viewport into dates.
  ({double min, double span})? _fullX;

  static DateTime _date(double ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);

  /// The viewport to draw for [range] over data spanning [fullMin]..[fullMax]
  /// (epoch milliseconds), given the [current] one.
  ///
  /// A new window only when the range or the data's span changed since the
  /// last seat; otherwise [current], with its zoom limit matched to the span.
  ChartViewport seat(
    TrendRange range,
    ChartViewport current,
    double fullMin,
    double fullMax,
  ) {
    final span = (fullMax - fullMin).clamp(1.0, double.infinity);
    final zoomLimit = math.max(
      ChartViewport.maxZoom,
      span / minWindow.inMilliseconds,
    );
    final dataSpan = (first: fullMin.round(), last: fullMax.round());
    _fullX = (min: fullMin, span: span);
    final rangeSettled = range == _appliedRange || range == _reportedRange;
    if (rangeSettled && _appliedSpan == dataSpan) {
      _appliedRange = range;
      return current.zoomLimit == zoomLimit
          ? current
          : current.withZoomLimit(zoomLimit);
    }
    final window = trendRangeFractions(range, _date(fullMin), _date(fullMax));
    _appliedRange = range;
    _reportedRange = null;
    _appliedSpan = dataSpan;
    return ChartViewport.forWindow(
      window.start,
      window.end,
      zoomLimit: zoomLimit,
    );
  }

  /// The range [viewport] shows: [TrendRange.all] when unzoomed, otherwise a
  /// custom range of the visible dates. Null before the first [seat].
  TrendRange? report(ChartViewport viewport) {
    final full = _fullX;
    if (full == null) return null;
    final next = viewport.isZoomed
        ? TrendRange.custom(
            _date(full.min + viewport.windowStart * full.span),
            _date(full.min + viewport.windowEnd * full.span),
          )
        : TrendRange.all;
    _reportedRange = next;
    return next;
  }
}
