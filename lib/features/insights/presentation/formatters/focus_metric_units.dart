import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One [FocusMetric] in the diver's units: its symbol, conversion both ways,
/// and formatting. Storage is litres or bar per minute, litres, metres,
/// minutes, kilograms, Celsius and percent.
class FocusMetricUnits {
  const FocusMetricUnits(this.metric, this.units);

  final FocusMetric metric;
  final UnitFormatter units;

  /// Sub-zero water and air are real (ice diving); nothing else can be
  /// negative.
  bool get allowsNegative =>
      metric == FocusMetric.waterTemp || metric == FocusMetric.airTemp;

  String symbol(AppLocalizations l10n) => switch (metric) {
    FocusMetric.rmv => units.rmvSymbol,
    FocusMetric.sac => units.sacSymbol,
    FocusMetric.gasUsed => units.volumeSymbol,
    FocusMetric.maxDepth ||
    FocusMetric.avgDepth ||
    FocusMetric.visibility => units.depthSymbol,
    FocusMetric.bottomTime ||
    FocusMetric.surfaceInterval => l10n.insights_focus_unit_minutes,
    FocusMetric.weight => units.weightSymbol,
    FocusMetric.waterTemp || FocusMetric.airTemp => units.temperatureSymbol,
    FocusMetric.altitude => units.altitudeSymbol,
    FocusMetric.cns => '%',
    FocusMetric.otu => l10n.insights_focus_metric_otu,
  };

  double toDisplay(double storage) => switch (metric) {
    FocusMetric.rmv => units.convertRmv(storage),
    FocusMetric.sac => units.convertSac(storage),
    FocusMetric.gasUsed => units.convertVolume(storage),
    FocusMetric.maxDepth ||
    FocusMetric.avgDepth ||
    FocusMetric.visibility => units.convertDepth(storage),
    FocusMetric.bottomTime ||
    FocusMetric.surfaceInterval ||
    FocusMetric.cns ||
    FocusMetric.otu => storage,
    FocusMetric.weight => units.convertWeight(storage),
    FocusMetric.waterTemp ||
    FocusMetric.airTemp => units.convertTemperature(storage),
    FocusMetric.altitude => units.convertAltitude(storage),
  };

  double toStorage(double display) => switch (metric) {
    FocusMetric.rmv => units.volumeToLiters(display),
    FocusMetric.sac => units.pressureToBar(display),
    FocusMetric.gasUsed => units.volumeToLiters(display),
    FocusMetric.maxDepth ||
    FocusMetric.avgDepth ||
    FocusMetric.visibility => units.depthToMeters(display),
    FocusMetric.bottomTime ||
    FocusMetric.surfaceInterval ||
    FocusMetric.cns ||
    FocusMetric.otu => display,
    FocusMetric.weight => units.weightToKg(display),
    FocusMetric.waterTemp ||
    FocusMetric.airTemp => units.temperatureToCelsius(display),
    FocusMetric.altitude => units.altitudeToMeters(display),
  };

  String format(double storage, AppLocalizations l10n) => switch (metric) {
    FocusMetric.rmv => units.formatRmv(storage),
    FocusMetric.sac => units.formatSac(storage),
    FocusMetric.gasUsed => units.formatVolume(storage),
    FocusMetric.maxDepth || FocusMetric.avgDepth => units.formatDepth(storage),
    FocusMetric.bottomTime => l10n.surfaceInterval_format_minutes(
      storage.toStringAsFixed(0),
    ),
    FocusMetric.surfaceInterval => _hoursMinutes(storage, l10n),
    FocusMetric.weight => units.formatWeight(storage),
    FocusMetric.waterTemp ||
    FocusMetric.airTemp => units.formatTemperature(storage),
    FocusMetric.visibility => units.formatDistance(storage),
    FocusMetric.altitude => units.formatAltitude(storage),
    FocusMetric.cns => '${storage.round()}%',
    FocusMetric.otu => '${storage.round()}',
  };

  /// Under an hour, the same minutes message as bottom time and the duration
  /// row; from an hour up, the Time patterns page's hours-and-minutes form.
  static String _hoursMinutes(double minutes, AppLocalizations l10n) {
    final whole = minutes.round();
    if (whole < 60) return l10n.surfaceInterval_format_minutes('$whole');
    return l10n.insights_timePatterns_surfaceInterval_formatHoursMinutes(
      whole ~/ 60,
      whole % 60,
    );
  }
}
