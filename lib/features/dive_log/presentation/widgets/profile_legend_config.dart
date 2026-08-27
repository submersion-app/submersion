import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Configuration for what data is available in the chart.
/// This determines which toggles appear in the legend.
class ProfileLegendConfig {
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
  final bool hasCnsData;
  final bool hasOtuData;

  /// Whether any O2 cell reported a raw millivolt reading (issue #810).
  final bool hasO2CellMvData;
  const ProfileLegendConfig({
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
      hasCnsData ||
      hasOtuData ||
      hasO2CellMvData;
}
