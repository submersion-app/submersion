import 'dart:math' as math;

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Whether [metric] has any renderable data for this chart's curves.
///
/// [hasMultiTankPressure] is passed in rather than recomputed here because it
/// is a cheap State-level getter used by many other call sites too.
bool hasDataForMetric(
  ProfileRightAxisMetric metric,
  DiveProfileChart config, {
  required bool hasMultiTankPressure,
}) {
  switch (metric) {
    case ProfileRightAxisMetric.temperature:
      return config.profile.any((p) => p.temperature != null);
    case ProfileRightAxisMetric.pressure:
      return hasMultiTankPressure;
    case ProfileRightAxisMetric.heartRate:
      return config.profile.any((p) => p.heartRate != null);
    case ProfileRightAxisMetric.sac:
      return config.sacCurve != null && config.sacCurve!.any((s) => s > 0);
    case ProfileRightAxisMetric.ascentRate:
      return config.ascentRates != null && config.ascentRates!.isNotEmpty;
    case ProfileRightAxisMetric.ndl:
      return config.ndlCurve != null && config.ndlCurve!.isNotEmpty;
    case ProfileRightAxisMetric.ppO2:
      return config.ppO2Curve != null && config.ppO2Curve!.isNotEmpty;
    case ProfileRightAxisMetric.ppN2:
      return config.ppN2Curve != null && config.ppN2Curve!.isNotEmpty;
    case ProfileRightAxisMetric.ppHe:
      return config.ppHeCurve != null &&
          config.ppHeCurve!.any((v) => v > 0.001);
    case ProfileRightAxisMetric.gasDensity:
      return config.densityCurve != null && config.densityCurve!.isNotEmpty;
    case ProfileRightAxisMetric.gf:
      return config.gfCurve != null && config.gfCurve!.isNotEmpty;
    case ProfileRightAxisMetric.surfaceGf:
      return config.surfaceGfCurve != null && config.surfaceGfCurve!.isNotEmpty;
    case ProfileRightAxisMetric.meanDepth:
      return config.meanDepthCurve != null && config.meanDepthCurve!.isNotEmpty;
    case ProfileRightAxisMetric.tts:
      return config.ttsCurve != null && config.ttsCurve!.isNotEmpty;
    case ProfileRightAxisMetric.gtr:
      return config.gtrCurve != null && config.gtrCurve!.any((v) => v != null);
    case ProfileRightAxisMetric.cns:
      return config.cnsCurve != null && config.cnsCurve!.isNotEmpty;
    case ProfileRightAxisMetric.otu:
      return config.otuCurve != null && config.otuCurve!.isNotEmpty;
    case ProfileRightAxisMetric.o2CellMv:
      return config.o2CellMvCurves != null &&
          config.o2CellMvCurves!.any((c) => c.any((v) => v != null));
  }
}

/// Get the min/max value range for a metric.
///
/// [hasMultiTankPressure], [cnsMaxScale], [otuMaxScale], [gfMaxScale],
/// [surfaceGfMaxScale], [ttsMaxScale], [ppO2MaxScale], [ppN2MaxScale],
/// [ppHeMaxScale] and [densityMaxScale] are passed in rather than recomputed
/// here because they are State-level values shared with many other call
/// sites (the ones with a line of their own, so an extreme dive never plots
/// past its own axis -- see buildGfLine/buildSurfaceGfLine/buildTtsLine/
/// buildPpO2Line/buildPpN2Line/buildPpHeLine/buildDensityLine). [o2CellMvMax]
/// is passed in because it is memoized on a State field keyed by
/// curve-list identity.
({double min, double max})? getMetricRange(
  ProfileRightAxisMetric metric,
  UnitFormatter units,
  DiveProfileChart config, {
  required bool hasMultiTankPressure,
  required double cnsMaxScale,
  required double otuMaxScale,
  required double gfMaxScale,
  required double surfaceGfMaxScale,
  required double ttsMaxScale,
  required double ppO2MaxScale,
  required double ppN2MaxScale,
  required double ppHeMaxScale,
  required double densityMaxScale,
  required int? Function(List<List<int?>>) o2CellMvMax,
  required ({double min, double max})? Function(List<AscentRatePoint>?)
  ascentRateAxisRange,
}) {
  switch (metric) {
    case ProfileRightAxisMetric.temperature:
      final temps = config.profile
          .where((p) => p.temperature != null)
          .map((p) => units.convertTemperature(p.temperature!));
      if (temps.isEmpty) return null;
      return (min: temps.reduce(math.min) - 1, max: temps.reduce(math.max) + 1);

    case ProfileRightAxisMetric.pressure:
      if (!hasMultiTankPressure || config.tankPressures == null) return null;
      final range = tankPressureRange(config.tankPressures!);
      if (range == null) return null;
      return (min: range.min - 10, max: range.max + 10);

    case ProfileRightAxisMetric.heartRate:
      final hrs = config.profile
          .where((p) => p.heartRate != null)
          .map((p) => p.heartRate!.toDouble());
      if (hrs.isEmpty) return null;
      return (min: hrs.reduce(math.min) - 5, max: hrs.reduce(math.max) + 5);

    case ProfileRightAxisMetric.sac:
      if (config.sacCurve == null) return null;
      final sacs = config.sacCurve!.where((s) => s > 0);
      if (sacs.isEmpty) return null;
      return (min: 0.0, max: sacs.reduce(math.max) * 1.2);

    case ProfileRightAxisMetric.ascentRate:
      return ascentRateAxisRange(config.ascentRates);

    case ProfileRightAxisMetric.ndl:
      return (min: 0.0, max: 3600.0); // 0-60 minutes

    case ProfileRightAxisMetric.ppO2:
      return (min: 0.0, max: ppO2MaxScale);

    case ProfileRightAxisMetric.ppN2:
      return (min: 0.0, max: ppN2MaxScale);

    case ProfileRightAxisMetric.ppHe:
      return (min: 0.0, max: ppHeMaxScale);

    case ProfileRightAxisMetric.gasDensity:
      return (min: 0.0, max: densityMaxScale);

    case ProfileRightAxisMetric.gf:
      return (min: 0.0, max: gfMaxScale);

    case ProfileRightAxisMetric.surfaceGf:
      return (min: 0.0, max: surfaceGfMaxScale);

    case ProfileRightAxisMetric.meanDepth:
      if (config.meanDepthCurve == null) return null;
      final depths = config.meanDepthCurve!;
      if (depths.isEmpty) return null;
      return (min: 0.0, max: depths.reduce(math.max) * 1.1);

    case ProfileRightAxisMetric.tts:
      return (min: 0.0, max: ttsMaxScale);

    case ProfileRightAxisMetric.gtr:
      return (min: 0.0, max: 3600.0); // 0-60 minutes

    case ProfileRightAxisMetric.cns:
      if (config.cnsCurve == null || config.cnsCurve!.isEmpty) return null;
      return (min: 0.0, max: cnsMaxScale);

    case ProfileRightAxisMetric.otu:
      if (config.otuCurve == null || config.otuCurve!.isEmpty) return null;
      return (min: 0.0, max: otuMaxScale);

    case ProfileRightAxisMetric.o2CellMv:
      final curves = config.o2CellMvCurves;
      if (curves == null) return null;
      // Zero-anchored and data-driven, so levels stay comparable across
      // dives. Cells sit around 30-70 mV.
      final maxMv = o2CellMvMax(curves);
      if (maxMv == null) return null;
      return (min: 0.0, max: maxMv * 1.2);
  }
}

/// Build axis label text for the right axis (e.g. "Temp (°C)").
String rightAxisLabel(
  ProfileRightAxisMetric metric,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  final name = profileMetricShortName(l10n, metric);
  final perMin = l10n.units_profileMetric_min;
  switch (metric) {
    case ProfileRightAxisMetric.temperature:
      return '$name (${units.temperatureSymbol})';
    case ProfileRightAxisMetric.pressure:
      return '$name (${units.pressureSymbol})';
    case ProfileRightAxisMetric.meanDepth:
      return '$name (${units.depthSymbol})';
    case ProfileRightAxisMetric.sac:
      return '$name (${units.pressureSymbol}/$perMin)';
    case ProfileRightAxisMetric.ascentRate:
      return '$name (${units.depthSymbol}/$perMin)';
    default:
      final suffix = profileMetricUnitSuffix(l10n, metric);
      if (suffix != null) return '$name ($suffix)';
      return name;
  }
}

/// Localized display name for a right-axis metric.
///
/// [ProfileRightAxisMetric.displayName] is a hardcoded English literal baked
/// into the enum, so the axis picker rendered English under every locale.
/// The `enum_profileMetric_*` keys already ship translated.
String profileMetricName(
  AppLocalizations l10n,
  ProfileRightAxisMetric metric,
) => switch (metric) {
  ProfileRightAxisMetric.temperature => l10n.enum_profileMetric_temperature,
  ProfileRightAxisMetric.pressure => l10n.enum_profileMetric_pressure,
  ProfileRightAxisMetric.heartRate => l10n.enum_profileMetric_heartRate,
  ProfileRightAxisMetric.sac => l10n.enum_profileMetric_sacRate,
  ProfileRightAxisMetric.ascentRate => l10n.enum_profileMetric_ascentRate,
  ProfileRightAxisMetric.ndl => l10n.enum_profileMetric_ndl,
  ProfileRightAxisMetric.ppO2 => l10n.enum_profileMetric_ppO2,
  ProfileRightAxisMetric.ppN2 => l10n.enum_profileMetric_ppN2,
  ProfileRightAxisMetric.ppHe => l10n.enum_profileMetric_ppHe,
  ProfileRightAxisMetric.gasDensity => l10n.enum_profileMetric_gasDensity,
  ProfileRightAxisMetric.gf => l10n.enum_profileMetric_gf,
  ProfileRightAxisMetric.surfaceGf => l10n.enum_profileMetric_surfaceGf,
  ProfileRightAxisMetric.meanDepth => l10n.enum_profileMetric_meanDepth,
  ProfileRightAxisMetric.tts => l10n.enum_profileMetric_tts,
  ProfileRightAxisMetric.gtr => l10n.enum_profileMetric_gtr,
  ProfileRightAxisMetric.cns => l10n.enum_profileMetric_cns,
  ProfileRightAxisMetric.otu => l10n.enum_profileMetric_otu,
  ProfileRightAxisMetric.o2CellMv => l10n.enum_profileMetric_o2CellMv,
};

/// Localized short name for a right-axis metric, used on the axis itself
/// where there is only room for an abbreviation.
String profileMetricShortName(
  AppLocalizations l10n,
  ProfileRightAxisMetric metric,
) => switch (metric) {
  ProfileRightAxisMetric.temperature =>
    l10n.enum_profileMetric_temperature_short,
  ProfileRightAxisMetric.pressure => l10n.enum_profileMetric_pressure_short,
  ProfileRightAxisMetric.heartRate => l10n.enum_profileMetric_heartRate_short,
  ProfileRightAxisMetric.sac => l10n.enum_profileMetric_sacRate_short,
  ProfileRightAxisMetric.ascentRate => l10n.enum_profileMetric_ascentRate_short,
  ProfileRightAxisMetric.ndl => l10n.enum_profileMetric_ndl_short,
  ProfileRightAxisMetric.ppO2 => l10n.enum_profileMetric_ppO2_short,
  ProfileRightAxisMetric.ppN2 => l10n.enum_profileMetric_ppN2_short,
  ProfileRightAxisMetric.ppHe => l10n.enum_profileMetric_ppHe_short,
  ProfileRightAxisMetric.gasDensity => l10n.enum_profileMetric_gasDensity_short,
  ProfileRightAxisMetric.gf => l10n.enum_profileMetric_gf_short,
  ProfileRightAxisMetric.surfaceGf => l10n.enum_profileMetric_surfaceGf_short,
  ProfileRightAxisMetric.meanDepth => l10n.enum_profileMetric_meanDepth_short,
  ProfileRightAxisMetric.tts => l10n.enum_profileMetric_tts_short,
  ProfileRightAxisMetric.gtr => l10n.enum_profileMetric_gtr_short,
  ProfileRightAxisMetric.cns => l10n.enum_profileMetric_cns_short,
  ProfileRightAxisMetric.otu => l10n.enum_profileMetric_otu_short,
  ProfileRightAxisMetric.o2CellMv => l10n.enum_profileMetric_o2CellMv_short,
};

/// Localized unit suffix for the metrics whose unit is fixed rather than
/// taken from the diver's unit settings. Metrics that go through
/// [UnitFormatter] (temperature, pressure, mean depth, SAC, ascent rate)
/// return null: the caller appends the formatter's own symbol.
String? profileMetricUnitSuffix(
  AppLocalizations l10n,
  ProfileRightAxisMetric metric,
) => switch (metric) {
  ProfileRightAxisMetric.heartRate => l10n.units_profileMetric_bpm,
  ProfileRightAxisMetric.ndl ||
  ProfileRightAxisMetric.tts ||
  ProfileRightAxisMetric.gtr => l10n.units_profileMetric_min,
  ProfileRightAxisMetric.ppO2 ||
  ProfileRightAxisMetric.ppN2 ||
  ProfileRightAxisMetric.ppHe => l10n.units_pressure_bar,
  ProfileRightAxisMetric.gasDensity => l10n.units_profileMetric_gPerL,
  ProfileRightAxisMetric.gf ||
  ProfileRightAxisMetric.surfaceGf ||
  ProfileRightAxisMetric.cns => l10n.units_profileMetric_percent,
  _ => null,
};

/// Localized header for a metric category in the right-axis picker.
String profileMetricCategoryName(
  AppLocalizations l10n,
  ProfileMetricCategory category,
) => switch (category) {
  ProfileMetricCategory.primary => l10n.enum_profileMetricCategory_primary,
  ProfileMetricCategory.decompression =>
    l10n.enum_profileMetricCategory_decompression,
  ProfileMetricCategory.gasAnalysis =>
    l10n.enum_profileMetricCategory_gasAnalysis,
  ProfileMetricCategory.gradientFactor =>
    l10n.enum_profileMetricCategory_gradientFactor,
  ProfileMetricCategory.other => l10n.enum_profileMetricCategory_other,
};
