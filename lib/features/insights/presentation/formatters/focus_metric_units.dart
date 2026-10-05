import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One [FocusMetric] in the diver's units: its symbol, conversion both ways,
/// and formatting. Storage is litres or bar per minute, metres, minutes,
/// kilograms and Celsius.
class FocusMetricUnits {
  const FocusMetricUnits(this.metric, this.units);

  final FocusMetric metric;
  final UnitFormatter units;

  /// Sub-zero water is real (ice diving); nothing else can be negative.
  bool get allowsNegative => metric == FocusMetric.waterTemp;

  String symbol(AppLocalizations l10n) => switch (metric) {
    FocusMetric.rmv => units.rmvSymbol,
    FocusMetric.sac => units.sacSymbol,
    FocusMetric.maxDepth => units.depthSymbol,
    FocusMetric.bottomTime => l10n.insights_focus_unit_minutes,
    FocusMetric.weight => units.weightSymbol,
    FocusMetric.waterTemp => units.temperatureSymbol,
  };

  double toDisplay(double storage) => switch (metric) {
    FocusMetric.rmv => units.convertRmv(storage),
    FocusMetric.sac => units.convertSac(storage),
    FocusMetric.maxDepth => units.convertDepth(storage),
    FocusMetric.bottomTime => storage,
    FocusMetric.weight => units.convertWeight(storage),
    FocusMetric.waterTemp => units.convertTemperature(storage),
  };

  double toStorage(double display) => switch (metric) {
    FocusMetric.rmv => units.volumeToLiters(display),
    FocusMetric.sac => units.pressureToBar(display),
    FocusMetric.maxDepth => units.depthToMeters(display),
    FocusMetric.bottomTime => display,
    FocusMetric.weight => units.weightToKg(display),
    FocusMetric.waterTemp => units.temperatureToCelsius(display),
  };

  String format(double storage, AppLocalizations l10n) => switch (metric) {
    FocusMetric.rmv => units.formatRmv(storage),
    FocusMetric.sac => units.formatSac(storage),
    FocusMetric.maxDepth => units.formatDepth(storage),
    FocusMetric.bottomTime => l10n.surfaceInterval_format_minutes(
      storage.toStringAsFixed(0),
    ),
    FocusMetric.weight => units.formatWeight(storage),
    FocusMetric.waterTemp => units.formatTemperature(storage),
  };
}
