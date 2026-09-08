import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A metric an overlaid source can draw its own trace of, alongside the
/// active source's. Metrics missing here (heart rate, SAC, markers, tank
/// pressures) are only ever drawn for the active source.
enum LegendMetric {
  depth,
  temperature,
  decoStops,
  ceiling,
  ndl,
  tts,
  gtr,
  cns,
  otu,
  ppO2,
  ppN2,
  ppHe,
  mod,
  density,
  gf,
  surfaceGf,
  meanDepth,
}

/// An overlaid source as the legend sees it: its display name, which metrics
/// it has data for, and how its traces are coloured.
@immutable
class LegendOverlaySource {
  final String name;

  /// Metrics this source has data for; a trace is drawn (and listed) for each
  /// that is switched on.
  final Set<LegendMetric> metrics;

  /// When true the source's traces are lighter tints of each metric's own
  /// colour, by position in the overlay list. When false every trace uses
  /// [color] (a planned profile, for instance).
  final bool tintByMetric;
  final Color color;

  const LegendOverlaySource({
    required this.name,
    required this.metrics,
    this.tintByMetric = true,
    this.color = Colors.transparent,
  });
}

/// Configuration for what data is available in the chart.
/// This determines which toggles appear in the legend.
class ProfileLegendConfig {
  /// Display name of the active source's computer, used to label its entries
  /// on multi-source dives. Null when unknown; entries then stay unsuffixed.
  final String? activeSourceName;

  /// Sources overlaid on the active one, in drawing order. Empty for a
  /// single-source dive.
  final List<LegendOverlaySource> overlays;

  final bool hasTemperatureData;
  final bool hasPressureData;
  final bool hasHeartRateData;
  final bool hasSacCurve;
  final bool hasCeilingCurve;
  final bool hasDecoStopCurve;
  final bool hasAscentRates;
  final bool hasEvents;
  final bool hasMaxDepthMarker;
  final bool hasPressureMarkers;
  final bool hasGasSwitches;
  final bool hasPhotoMarkers;
  final bool hasMultiTankPressure;
  final bool hasGasData;
  final List<DiveTank>? tanks;
  final Map<String, List<TankPressurePoint>>? tankPressures;

  /// Tank IDs whose pressure series is a synthesized linear estimate (#197),
  /// labelled with a "(est.)" suffix in the Tank Pressures section.
  final Set<String> estimatedTankIds;

  /// Owning dive computer's colour for each tank id, on multi-source dives
  /// only. Lets the Cylinders / Tank Pressures rows mark which computer a
  /// tank belongs to when two computers logged tanks with the same gas mix
  /// (identical gas-colour swatches otherwise).
  final Map<String, Color>? tankSourceColors;

  // Advanced decompression/gas data availability
  final bool hasNdlData;
  final bool hasPpO2Data;
  final bool hasPpN2Data;
  final bool hasPpHeData;
  final bool hasModData;
  final bool hasDensityData;
  final bool hasGfData;
  final bool hasSurfaceGfData;
  final bool hasMeanDepthData;
  final bool hasTtsData;

  /// Whether any sample has a gas time remaining value (calculated or from
  /// the computer); a curve of nothing but blanks does not count.
  final bool hasGtrData;
  final bool hasCnsData;
  final bool hasOtuData;

  /// Whether any O2 cell reported a raw millivolt reading (issue #810).
  final bool hasO2CellMvData;
  const ProfileLegendConfig({
    this.activeSourceName,
    this.overlays = const [],
    this.hasTemperatureData = false,
    this.hasPressureData = false,
    this.hasHeartRateData = false,
    this.hasSacCurve = false,
    this.hasCeilingCurve = false,
    this.hasDecoStopCurve = false,
    this.hasAscentRates = false,
    this.hasEvents = false,
    this.hasMaxDepthMarker = false,
    this.hasPressureMarkers = false,
    this.hasGasSwitches = false,
    this.hasPhotoMarkers = false,
    this.hasMultiTankPressure = false,
    this.hasGasData = false,
    this.tanks,
    this.tankPressures,
    this.estimatedTankIds = const {},
    this.tankSourceColors,
    this.hasNdlData = false,
    this.hasPpO2Data = false,
    this.hasPpN2Data = false,
    this.hasPpHeData = false,
    this.hasModData = false,
    this.hasDensityData = false,
    this.hasGfData = false,
    this.hasSurfaceGfData = false,
    this.hasMeanDepthData = false,
    this.hasTtsData = false,
    this.hasGtrData = false,
    this.hasCnsData = false,
    this.hasOtuData = false,
    this.hasO2CellMvData = false,
  });

  bool get hasTankListSection =>
      hasGasSwitches && !hasMultiTankPressure && (tanks?.length ?? 0) > 1;

  /// Whether any secondary toggles should be shown
  bool get hasSecondaryToggles =>
      hasCeilingCurve ||
      hasDecoStopCurve ||
      hasHeartRateData ||
      hasSacCurve ||
      hasAscentRates ||
      hasMaxDepthMarker ||
      hasPressureMarkers ||
      hasGasSwitches ||
      hasPhotoMarkers ||
      hasTankListSection ||
      hasGasData ||
      hasMultiTankPressure ||
      hasNdlData ||
      hasPpO2Data ||
      hasPpN2Data ||
      hasPpHeData ||
      hasModData ||
      hasDensityData ||
      hasGfData ||
      hasSurfaceGfData ||
      hasMeanDepthData ||
      hasTtsData ||
      hasGtrData ||
      hasCnsData ||
      hasOtuData ||
      hasO2CellMvData;
}
