import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_buoyancy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/buoyancy_curve.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// What a profile surface hands `DiveProfileChart` for the buoyancy line
/// (issue #4593): whether the toggle is offered, and the line's values.
typedef ChartBuoyancyInputs = ({bool available, List<double?>? curve});

/// The buoyancy inputs for [diveId]'s chart, which draws [drawn].
///
/// Whether the line can be offered comes from the dive alone. The simulation
/// is watched only while the line is on or the right axis reads buoyancy:
/// the dashboard's recent-dive preview renders on the app's first frame and
/// must not run the model for a line nobody asked for.
ChartBuoyancyInputs watchChartBuoyancy(
  WidgetRef ref,
  String diveId,
  List<DiveProfilePoint> drawn,
) {
  // Select the answer, not the AsyncValue: any dive edit (a note, a
  // favourite) recomputes the check through a loading state, and the dive
  // page keeps its chart instance through such edits (#3816).
  final available = ref.watch(
    buoyancyModelableProvider(diveId).select((a) => a.value ?? false),
  );
  if (!available) return (available: false, curve: null);
  // The line's own toggle, or the right axis reading buoyancy: every other
  // right-axis metric reads without its line shown, and without the curve
  // this one would silently fall back to another metric.
  final defaultAxis = ref.watch(
    settingsProvider.select((s) => s.defaultRightAxisMetric),
  );
  final wanted = ref.watch(
    profileLegendProvider.select(
      (s) =>
          s.showBuoyancy ||
          effectiveRightAxisMetricOf(s, defaultAxis) ==
              ProfileRightAxisMetric.buoyancy,
    ),
  );
  if (!wanted) return (available: true, curve: null);
  // The result only: a reload keeps the previous value, so the chart is not
  // rebuilt until a new model actually arrives.
  final result = ref.watch(
    chartBuoyancyTwinProvider(diveId).select((a) => a.value),
  );
  if (result == null) return (available: true, curve: null);
  return (available: true, curve: _alignedCurve(result, drawn));
}

/// The aligned curve for each model result, kept while the drawn series has
/// the same sample times. The chart keys its cached bars on the curve's
/// identity, so a new list on every frame would redraw its analysis layer
/// each time. Surfaces rebuild the drawn list per build (heart rate merged
/// in), so the times are compared, not the list's identity.
final _alignedByResult = Expando<(List<int>, List<double?>)>('buoyancyCurve');

List<double?> _alignedCurve(
  BuoyancyTwinResult result,
  List<DiveProfilePoint> drawn,
) {
  final cached = _alignedByResult[result];
  if (cached != null && _sameTimes(cached.$1, drawn)) return cached.$2;
  final curve = alignBuoyancyCurve(drawn, result.samples);
  _alignedByResult[result] = ([for (final p in drawn) p.timestamp], curve);
  return curve;
}

bool _sameTimes(List<int> times, List<DiveProfilePoint> drawn) {
  if (times.length != drawn.length) return false;
  for (var i = 0; i < times.length; i++) {
    if (times[i] != drawn[i].timestamp) return false;
  }
  return true;
}
