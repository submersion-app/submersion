import 'package:intl/intl.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
    final converted = TemperatureUnit.celsius.convert(
      value,
      settings.temperatureUnit,
    );
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

  /// Format tank volume - handles gas capacity conversion for imperial units.
  /// Pass [ratedCapacityCuft] (from a preset) for accurate display;
  /// otherwise falls back to ideal-gas calculation from volume and pressure.
  String formatTankVolume(
    double? volumeLiters,
    double? workingPressureBar, {
    double? ratedCapacityCuft,
    int decimals = 0,
  }) {
    if (volumeLiters == null) return '--';

    if (settings.volumeUnit == VolumeUnit.cubicFeet) {
      // Try to use manufacturer's rated cuft, either passed directly
      // or by matching volume/pressure against known tank presets
      var cuft = ratedCapacityCuft;
      if (cuft == null &&
          workingPressureBar != null &&
          workingPressureBar > 0) {
        final match = TankPresets.matchBySpecs(
          volumeLiters,
          workingPressureBar,
        );
        cuft = match?.ratedCapacityCuft;
      }
      if (cuft != null) {
        return '${cuft.toStringAsFixed(decimals)} ${settings.volumeUnit.symbol}';
      }
      if (workingPressureBar != null && workingPressureBar > 0) {
        // Ideal gas approximation for non-standard tanks
        final calcCuft = (volumeLiters * workingPressureBar) / 28.3168;
        return '${calcCuft.toStringAsFixed(decimals)} ${settings.volumeUnit.symbol}';
      } else {
        // No working pressure - approximate assuming 200 bar
        final calcCuft = (volumeLiters * 200) / 28.3168;
        return '~${calcCuft.toStringAsFixed(decimals)} ${settings.volumeUnit.symbol}';
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

  // ============================================================================
  // Altitude
  // ============================================================================

  /// Format altitude value with unit symbol
  String formatAltitude(double? value, {int decimals = 0}) {
    if (value == null) return '--';
    final converted = AltitudeUnit.meters.convert(value, settings.altitudeUnit);
    final formatted = NumberFormat('#,##0').format(converted.round());
    return '$formatted ${settings.altitudeUnit.symbol}';
  }

  /// Format altitude with altitude group label
  String formatAltitudeWithGroup(double? value, {int decimals = 0}) {
    if (value == null) return '--';
    final altitudeStr = formatAltitude(value, decimals: decimals);
    final group = AltitudeGroup.fromAltitude(value);
    if (group == AltitudeGroup.seaLevel) return altitudeStr;
    return '$altitudeStr (${group.displayName})';
  }

  /// Format barometric pressure
  String formatBarometricPressure(double? bar, {int decimals = 3}) {
    if (bar == null) return '--';
    return '${bar.toStringAsFixed(decimals)} bar';
  }

  /// Format barometric pressure in millibar
  String formatBarometricPressureMbar(double? bar, {int decimals = 0}) {
    if (bar == null) return '--';
    final mbar = bar * 1000;
    return '${mbar.toStringAsFixed(decimals)} mbar';
  }

  /// Get altitude unit symbol
  String get altitudeSymbol => settings.altitudeUnit.symbol;

  /// Convert altitude from meters to user's preferred unit
  double convertAltitude(double meters) {
    return AltitudeUnit.meters.convert(meters, settings.altitudeUnit);
  }

  /// Convert altitude from user's preferred unit to meters (for storage)
  double altitudeToMeters(double value) {
    return settings.altitudeUnit.convert(value, AltitudeUnit.meters);
  }

  // ============================================================================
  // Wind Speed
  // ============================================================================

  /// Whether the user prefers metric wind speed (km/h) vs imperial (knots).
  /// Derived from depth unit: meters -> metric, feet -> imperial.
  bool get _isMetricWind => settings.depthUnit == DepthUnit.meters;

  /// Format wind speed from m/s to the user's preferred unit.
  String formatWindSpeed(double? metersPerSecond, {int decimals = 0}) {
    if (metersPerSecond == null) return '--';
    final converted = convertWindSpeed(metersPerSecond);
    return '${converted.toStringAsFixed(decimals)} $windSpeedSymbol';
  }

  /// Convert wind speed from m/s to the user's preferred display unit.
  double convertWindSpeed(double metersPerSecond) {
    return _isMetricWind
        ? metersPerSecond *
              3.6 // m/s to km/h
        : metersPerSecond * 1.94384; // m/s to knots
  }

  /// Convert wind speed from the user's display unit back to m/s (for storage).
  double windSpeedToMs(double value) {
    return _isMetricWind ? value / 3.6 : value / 1.94384;
  }

  /// Wind speed unit symbol.
  String get windSpeedSymbol => _isMetricWind ? 'km/h' : 'kts';

  // ============================================================================
  // Date/Time Formatting
  // ============================================================================

  /// Format time according to user preference (12h or 24h)
  /// Example: "2:30 PM" or "14:30"
  String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat(settings.timeFormat.pattern).format(dateTime);
  }

  /// Format date according to user preference
  /// Example: "Jan 15, 2024" or "15/01/2024"
  String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat(settings.dateFormat.pattern).format(dateTime);
  }

  /// Format date and time together
  /// Example: "Jan 15, 2024 at 2:30 PM"
  /// Pass [l10n] to localize the "at" connector word.
  String formatDateTime(DateTime? dateTime, {AppLocalizations? l10n}) {
    if (dateTime == null) return '--';
    final connector = l10n?.formatter_connector_at ?? 'at';
    return '${formatDate(dateTime)} $connector ${formatTime(dateTime)}';
  }

  /// Format date and time in compact form with bullet separator
  /// Example: "Jan 15, 2024 • 2:30 PM"
  String formatDateTimeBullet(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return '${formatDate(dateTime)} • ${formatTime(dateTime)}';
  }

  /// Format month and day only (respects day-first vs month-first preference)
  /// Example: "Jan 15" or "15 Jan"
  String formatMonthDay(DateTime? dateTime) {
    if (dateTime == null) return '--';
    final pattern = settings.dateFormat.isDayFirst ? 'd MMM' : 'MMM d';
    return DateFormat(pattern).format(dateTime);
  }

  /// Format date range for display
  /// Example: "Jan 15 - Jan 20, 2024"
  /// Pass [l10n] to localize the "Until"/"From" connector words.
  String formatDateRange(
    DateTime? start,
    DateTime? end, {
    AppLocalizations? l10n,
  }) {
    if (start == null && end == null) return '--';
    if (start == null) {
      final connector = l10n?.formatter_connector_until ?? 'Until';
      return '$connector ${formatDate(end)}';
    }
    if (end == null) {
      final connector = l10n?.formatter_connector_from ?? 'From';
      return '$connector ${formatDate(start)}';
    }

    // Same year - abbreviate start date
    if (start.year == end.year) {
      return '${formatMonthDay(start)} - ${formatDate(end)}';
    }
    return '${formatDate(start)} - ${formatDate(end)}';
  }

  /// Get the time format pattern for direct use
  String get timePattern => settings.timeFormat.pattern;

  /// Get the date format pattern for direct use
  String get datePattern => settings.dateFormat.pattern;
}
