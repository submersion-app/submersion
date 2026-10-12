import 'dart:math' as math;

import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';

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

  /// The window the diver last settled on: the one [seat] placed for a new
  /// range or span, or the one [report] last described. A navigation that
  /// ends where it began reports nothing, so the range keeps its label.
  ChartViewport? _settled;

  /// Full x range of the last [seat], for turning a viewport into dates.
  ({double min, double span})? _fullX;

  /// The scale of the last [seat], for turning axis positions into dates.
  TrendTimeScale _scale = TrendTimeScale.identity;

  /// The viewport to draw for [range] over data spanning [fullMin]..[fullMax]
  /// (axis positions under [scale]), given the [current] one.
  ///
  /// A new window only when the range or the data's span changed since the
  /// last seat; otherwise [current], with its zoom limit matched to the span.
  /// A threshold change that moves the collapsed span counts as a span
  /// change, so a custom window is re-seated on its own dates.
  ChartViewport seat(
    TrendRange range,
    ChartViewport current,
    double fullMin,
    double fullMax, {
    TrendTimeScale scale = TrendTimeScale.identity,
  }) {
    final span = (fullMax - fullMin).clamp(1.0, double.infinity);
    final zoomLimit = math.max(
      ChartViewport.maxZoom,
      span / minWindow.inMilliseconds,
    );
    final dataSpan = (first: fullMin.round(), last: fullMax.round());
    _fullX = (min: fullMin, span: span);
    _scale = scale;
    final rangeSettled = range == _appliedRange || range == _reportedRange;
    if (rangeSettled && _appliedSpan == dataSpan) {
      _appliedRange = range;
      return current.zoomLimit == zoomLimit
          ? current
          : current.withZoomLimit(zoomLimit);
    }
    final window = trendRangeFractions(
      range,
      scale.toDate(fullMin),
      scale.toDate(fullMax),
      toAxis: scale.toAxis,
    );
    _appliedRange = range;
    _reportedRange = null;
    _appliedSpan = dataSpan;
    return _settled = ChartViewport.forWindow(
      window.start,
      window.end,
      zoomLimit: zoomLimit,
    );
  }

  /// The range [viewport] shows: [TrendRange.all] when unzoomed, otherwise a
  /// custom range of the visible dates. Null before the first [seat], and
  /// when [viewport] shows the window last seated or reported.
  TrendRange? report(ChartViewport viewport) {
    final full = _fullX;
    if (full == null) return null;
    if (_settled?.sameWindowAs(viewport) ?? false) return null;
    _settled = viewport;
    final next = viewport.isZoomed
        ? TrendRange.custom(
            _scale.toDate(full.min + viewport.windowStart * full.span),
            _scale.toDate(full.min + viewport.windowEnd * full.span),
          )
        : TrendRange.all;
    _reportedRange = next;
    return next;
  }
}
