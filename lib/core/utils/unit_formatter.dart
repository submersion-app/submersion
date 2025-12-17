import '../constants/units.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';

/// Utility class for formatting values with the correct units based on settings
class UnitFormatter {
  final AppSettings settings;

  const UnitFormatter(this.settings);

  // ============================================================================
  // Depth
  // ============================================================================

  /// Format depth value with unit symbol
  String formatDepth(double? value, {int decimals = 1}) {
    if (value == null) return '--';
    final converted = DepthUnit.meters.convert(value, settings.depthUnit);
    return '${converted.toStringAsFixed(decimals)}${settings.depthUnit.symbol}';
  }

  /// Get depth unit symbol
  String get depthSymbol => settings.depthUnit.symbol;

  /// Convert depth from meters to user's preferred unit
  double convertDepth(double meters) {
    return DepthUnit.meters.convert(meters, settings.depthUnit);
  }

  /// Convert depth from user's preferred unit to meters (for storage)
  double depthToMeters(double value) {
    return settings.depthUnit.convert(value, DepthUnit.meters);
  }

  // ============================================================================
  // Temperature
  // ============================================================================

  /// Format temperature value with unit symbol
  String formatTemperature(double? value, {int decimals = 0}) {
    if (value == null) return '--';
    final converted = TemperatureUnit.celsius.convert(value, settings.temperatureUnit);
    return '${converted.toStringAsFixed(decimals)}°${settings.temperatureUnit.symbol}';
  }

  /// Get temperature unit symbol
  String get temperatureSymbol => '°${settings.temperatureUnit.symbol}';

  /// Convert temperature from celsius to user's preferred unit
  double convertTemperature(double celsius) {
    return TemperatureUnit.celsius.convert(celsius, settings.temperatureUnit);
  }

  /// Convert temperature from user's preferred unit to celsius (for storage)
  double temperatureToCelsius(double value) {
    return settings.temperatureUnit.convert(value, TemperatureUnit.celsius);
  }

  // ============================================================================
  // Pressure
  // ============================================================================

  /// Format pressure value with unit symbol
  String formatPressure(double? value, {int decimals = 0}) {
    if (value == null) return '--';
    final converted = PressureUnit.bar.convert(value, settings.pressureUnit);
    return '${converted.toStringAsFixed(decimals)} ${settings.pressureUnit.symbol}';
  }

  /// Format pressure value without unit (for ranges like "200 → 50")
  String formatPressureValue(double? value, {int decimals = 0}) {
    if (value == null) return '--';
    final converted = PressureUnit.bar.convert(value, settings.pressureUnit);
    return converted.toStringAsFixed(decimals);
  }

  /// Get pressure unit symbol
  String get pressureSymbol => settings.pressureUnit.symbol;

  /// Convert pressure from bar to user's preferred unit
  double convertPressure(double bar) {
    return PressureUnit.bar.convert(bar, settings.pressureUnit);
  }

  /// Convert pressure from user's preferred unit to bar (for storage)
  double pressureToBar(double value) {
    return settings.pressureUnit.convert(value, PressureUnit.bar);
  }

  // ============================================================================
  // Volume
  // ============================================================================

  /// Format volume value with unit symbol
  String formatVolume(double? value, {int decimals = 0}) {
    if (value == null) return '--';
    final converted = VolumeUnit.liters.convert(value, settings.volumeUnit);
    return '${converted.toStringAsFixed(decimals)} ${settings.volumeUnit.symbol}';
  }

  /// Format tank volume - handles gas capacity conversion for imperial units
  /// For cuft, calculates gas capacity from physical volume and working pressure
  String formatTankVolume(double? volumeLiters, int? workingPressureBar, {int decimals = 0}) {
    if (volumeLiters == null) return '--';
    
    if (settings.volumeUnit == VolumeUnit.cubicFeet) {
      if (workingPressureBar != null && workingPressureBar > 0) {
        // Calculate gas capacity in cubic feet
        // cuft = (liters * working_pressure_bar) / 28.3168
        final cuft = (volumeLiters * workingPressureBar) / 28.3168;
        return '${cuft.toStringAsFixed(decimals)} ${settings.volumeUnit.symbol}';
      } else {
        // No working pressure - use approximate conversion assuming 200 bar
        // This is a reasonable default for most tanks
        final cuft = (volumeLiters * 200) / 28.3168;
        return '~${cuft.toStringAsFixed(decimals)} ${settings.volumeUnit.symbol}';
      }
    }
    
    // For liters, just show physical volume
    return '${volumeLiters.toStringAsFixed(decimals)} ${settings.volumeUnit.symbol}';
  }

  /// Get volume unit symbol
  String get volumeSymbol => settings.volumeUnit.symbol;

  /// Convert volume from liters to user's preferred unit
  double convertVolume(double liters) {
    return VolumeUnit.liters.convert(liters, settings.volumeUnit);
  }

  /// Convert volume from user's preferred unit to liters (for storage)
  double volumeToLiters(double value) {
    return settings.volumeUnit.convert(value, VolumeUnit.liters);
  }

  // ============================================================================
  // Weight
  // ============================================================================

  /// Format weight value with unit symbol
  String formatWeight(double? value, {int decimals = 1}) {
    if (value == null) return '--';
    final converted = WeightUnit.kilograms.convert(value, settings.weightUnit);
    return '${converted.toStringAsFixed(decimals)} ${settings.weightUnit.symbol}';
  }

  /// Get weight unit symbol
  String get weightSymbol => settings.weightUnit.symbol;

  /// Convert weight from kg to user's preferred unit
  double convertWeight(double kg) {
    return WeightUnit.kilograms.convert(kg, settings.weightUnit);
  }

  /// Convert weight from user's preferred unit to kg (for storage)
  double weightToKg(double value) {
    return settings.weightUnit.convert(value, WeightUnit.kilograms);
  }
}

