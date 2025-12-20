import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/units.dart';

/// Unit system preset
enum UnitPreset {
  metric('Metric'),
  imperial('Imperial'),
  custom('Custom');

  final String displayName;
  const UnitPreset(this.displayName);
}

/// Keys for SharedPreferences
class SettingsKeys {
  static const String depthUnit = 'depth_unit';
  static const String temperatureUnit = 'temperature_unit';
  static const String pressureUnit = 'pressure_unit';
  static const String volumeUnit = 'volume_unit';
  static const String weightUnit = 'weight_unit';
  static const String unitPreset = 'unit_preset';
  static const String themeMode = 'theme_mode';
  static const String defaultDiveType = 'default_dive_type';
  static const String defaultTankVolume = 'default_tank_volume';
  static const String defaultStartPressure = 'default_start_pressure';

  // Decompression & Safety settings
  static const String gfLow = 'gf_low';
  static const String gfHigh = 'gf_high';
  static const String ppO2MaxWorking = 'ppo2_max_working';
  static const String ppO2MaxDeco = 'ppo2_max_deco';
  static const String cnsWarningThreshold = 'cns_warning_threshold';
  static const String ascentRateWarning = 'ascent_rate_warning';
  static const String ascentRateCritical = 'ascent_rate_critical';
  static const String showCeilingOnProfile = 'show_ceiling_on_profile';
  static const String showAscentRateColors = 'show_ascent_rate_colors';
  static const String showNdlOnProfile = 'show_ndl_on_profile';
  static const String lastStopDepth = 'last_stop_depth';
  static const String decoStopIncrement = 'deco_stop_increment';
}

/// App settings state
class AppSettings {
  final DepthUnit depthUnit;
  final TemperatureUnit temperatureUnit;
  final PressureUnit pressureUnit;
  final VolumeUnit volumeUnit;
  final WeightUnit weightUnit;
  final ThemeMode themeMode;
  final String defaultDiveType;
  final double defaultTankVolume;
  final int defaultStartPressure;

  // Decompression & Safety settings
  /// Gradient Factor Low (0-100, typically 30)
  final int gfLow;

  /// Gradient Factor High (0-100, typically 70)
  final int gfHigh;

  /// Maximum ppO2 for working/bottom gas (typically 1.4 bar)
  final double ppO2MaxWorking;

  /// Maximum ppO2 for deco gas (typically 1.6 bar)
  final double ppO2MaxDeco;

  /// CNS% warning threshold (typically 80%)
  final int cnsWarningThreshold;

  /// Ascent rate warning threshold in m/min (typically 9)
  final double ascentRateWarning;

  /// Ascent rate critical threshold in m/min (typically 12)
  final double ascentRateCritical;

  /// Show ceiling curve on dive profile
  final bool showCeilingOnProfile;

  /// Show color-coded ascent rate on dive profile
  final bool showAscentRateColors;

  /// Show NDL values on dive profile
  final bool showNdlOnProfile;

  /// Last deco stop depth in meters (typically 3 or 6)
  final double lastStopDepth;

  /// Deco stop increment in meters (typically 3)
  final double decoStopIncrement;

  const AppSettings({
    this.depthUnit = DepthUnit.meters,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.pressureUnit = PressureUnit.bar,
    this.volumeUnit = VolumeUnit.liters,
    this.weightUnit = WeightUnit.kilograms,
    this.themeMode = ThemeMode.system,
    this.defaultDiveType = 'recreational',
    this.defaultTankVolume = 12.0,
    this.defaultStartPressure = 200,
    // Decompression defaults
    this.gfLow = 30,
    this.gfHigh = 70,
    this.ppO2MaxWorking = 1.4,
    this.ppO2MaxDeco = 1.6,
    this.cnsWarningThreshold = 80,
    this.ascentRateWarning = 9.0,
    this.ascentRateCritical = 12.0,
    this.showCeilingOnProfile = true,
    this.showAscentRateColors = true,
    this.showNdlOnProfile = true,
    this.lastStopDepth = 3.0,
    this.decoStopIncrement = 3.0,
  });

  /// Compute the current unit preset based on actual unit values
  UnitPreset get unitPreset {
    final isAllMetric = depthUnit == DepthUnit.meters &&
        temperatureUnit == TemperatureUnit.celsius &&
        pressureUnit == PressureUnit.bar &&
        volumeUnit == VolumeUnit.liters &&
        weightUnit == WeightUnit.kilograms;

    final isAllImperial = depthUnit == DepthUnit.feet &&
        temperatureUnit == TemperatureUnit.fahrenheit &&
        pressureUnit == PressureUnit.psi &&
        volumeUnit == VolumeUnit.cubicFeet &&
        weightUnit == WeightUnit.pounds;

    if (isAllMetric) return UnitPreset.metric;
    if (isAllImperial) return UnitPreset.imperial;
    return UnitPreset.custom;
  }

  /// Whether using metric units (convenience getter)
  bool get isMetric => unitPreset == UnitPreset.metric;

  /// Gradient factors as decimal (0.0-1.0) for use in algorithms
  double get gfLowDecimal => gfLow / 100.0;
  double get gfHighDecimal => gfHigh / 100.0;

  /// Gradient factor string representation (e.g., "30/70")
  String get gfDisplay => '$gfLow/$gfHigh';

  AppSettings copyWith({
    DepthUnit? depthUnit,
    TemperatureUnit? temperatureUnit,
    PressureUnit? pressureUnit,
    VolumeUnit? volumeUnit,
    WeightUnit? weightUnit,
    ThemeMode? themeMode,
    String? defaultDiveType,
    double? defaultTankVolume,
    int? defaultStartPressure,
    int? gfLow,
    int? gfHigh,
    double? ppO2MaxWorking,
    double? ppO2MaxDeco,
    int? cnsWarningThreshold,
    double? ascentRateWarning,
    double? ascentRateCritical,
    bool? showCeilingOnProfile,
    bool? showAscentRateColors,
    bool? showNdlOnProfile,
    double? lastStopDepth,
    double? decoStopIncrement,
  }) {
    return AppSettings(
      depthUnit: depthUnit ?? this.depthUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      pressureUnit: pressureUnit ?? this.pressureUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      weightUnit: weightUnit ?? this.weightUnit,
      themeMode: themeMode ?? this.themeMode,
      defaultDiveType: defaultDiveType ?? this.defaultDiveType,
      defaultTankVolume: defaultTankVolume ?? this.defaultTankVolume,
      defaultStartPressure: defaultStartPressure ?? this.defaultStartPressure,
      gfLow: gfLow ?? this.gfLow,
      gfHigh: gfHigh ?? this.gfHigh,
      ppO2MaxWorking: ppO2MaxWorking ?? this.ppO2MaxWorking,
      ppO2MaxDeco: ppO2MaxDeco ?? this.ppO2MaxDeco,
      cnsWarningThreshold: cnsWarningThreshold ?? this.cnsWarningThreshold,
      ascentRateWarning: ascentRateWarning ?? this.ascentRateWarning,
      ascentRateCritical: ascentRateCritical ?? this.ascentRateCritical,
      showCeilingOnProfile: showCeilingOnProfile ?? this.showCeilingOnProfile,
      showAscentRateColors: showAscentRateColors ?? this.showAscentRateColors,
      showNdlOnProfile: showNdlOnProfile ?? this.showNdlOnProfile,
      lastStopDepth: lastStopDepth ?? this.lastStopDepth,
      decoStopIncrement: decoStopIncrement ?? this.decoStopIncrement,
    );
  }
}

/// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

/// Settings notifier that persists to SharedPreferences
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(const AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    state = AppSettings(
      depthUnit: _loadEnum(
        SettingsKeys.depthUnit,
        DepthUnit.values,
        DepthUnit.meters,
      ),
      temperatureUnit: _loadEnum(
        SettingsKeys.temperatureUnit,
        TemperatureUnit.values,
        TemperatureUnit.celsius,
      ),
      pressureUnit: _loadEnum(
        SettingsKeys.pressureUnit,
        PressureUnit.values,
        PressureUnit.bar,
      ),
      volumeUnit: _loadEnum(
        SettingsKeys.volumeUnit,
        VolumeUnit.values,
        VolumeUnit.liters,
      ),
      weightUnit: _loadEnum(
        SettingsKeys.weightUnit,
        WeightUnit.values,
        WeightUnit.kilograms,
      ),
      themeMode: _loadThemeMode(),
      defaultDiveType:
          _prefs.getString(SettingsKeys.defaultDiveType) ?? 'recreational',
      defaultTankVolume:
          _prefs.getDouble(SettingsKeys.defaultTankVolume) ?? 12.0,
      defaultStartPressure:
          _prefs.getInt(SettingsKeys.defaultStartPressure) ?? 200,
      // Decompression settings
      gfLow: _prefs.getInt(SettingsKeys.gfLow) ?? 30,
      gfHigh: _prefs.getInt(SettingsKeys.gfHigh) ?? 70,
      ppO2MaxWorking: _prefs.getDouble(SettingsKeys.ppO2MaxWorking) ?? 1.4,
      ppO2MaxDeco: _prefs.getDouble(SettingsKeys.ppO2MaxDeco) ?? 1.6,
      cnsWarningThreshold:
          _prefs.getInt(SettingsKeys.cnsWarningThreshold) ?? 80,
      ascentRateWarning:
          _prefs.getDouble(SettingsKeys.ascentRateWarning) ?? 9.0,
      ascentRateCritical:
          _prefs.getDouble(SettingsKeys.ascentRateCritical) ?? 12.0,
      showCeilingOnProfile:
          _prefs.getBool(SettingsKeys.showCeilingOnProfile) ?? true,
      showAscentRateColors:
          _prefs.getBool(SettingsKeys.showAscentRateColors) ?? true,
      showNdlOnProfile: _prefs.getBool(SettingsKeys.showNdlOnProfile) ?? true,
      lastStopDepth: _prefs.getDouble(SettingsKeys.lastStopDepth) ?? 3.0,
      decoStopIncrement:
          _prefs.getDouble(SettingsKeys.decoStopIncrement) ?? 3.0,
    );
  }

  T _loadEnum<T extends Enum>(String key, List<T> values, T defaultValue) {
    final stored = _prefs.getString(key);
    if (stored == null) return defaultValue;
    return values.firstWhere(
      (e) => e.name == stored,
      orElse: () => defaultValue,
    );
  }

  ThemeMode _loadThemeMode() {
    final stored = _prefs.getString(SettingsKeys.themeMode);
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setDepthUnit(DepthUnit unit) async {
    await _prefs.setString(SettingsKeys.depthUnit, unit.name);
    state = state.copyWith(depthUnit: unit);
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    await _prefs.setString(SettingsKeys.temperatureUnit, unit.name);
    state = state.copyWith(temperatureUnit: unit);
  }

  Future<void> setPressureUnit(PressureUnit unit) async {
    await _prefs.setString(SettingsKeys.pressureUnit, unit.name);
    state = state.copyWith(pressureUnit: unit);
  }

  Future<void> setVolumeUnit(VolumeUnit unit) async {
    await _prefs.setString(SettingsKeys.volumeUnit, unit.name);
    state = state.copyWith(volumeUnit: unit);
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    await _prefs.setString(SettingsKeys.weightUnit, unit.name);
    state = state.copyWith(weightUnit: unit);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    await _prefs.setString(SettingsKeys.themeMode, value);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setDefaultDiveType(String diveType) async {
    await _prefs.setString(SettingsKeys.defaultDiveType, diveType);
    state = state.copyWith(defaultDiveType: diveType);
  }

  Future<void> setDefaultTankVolume(double volume) async {
    await _prefs.setDouble(SettingsKeys.defaultTankVolume, volume);
    state = state.copyWith(defaultTankVolume: volume);
  }

  Future<void> setDefaultStartPressure(int pressure) async {
    await _prefs.setInt(SettingsKeys.defaultStartPressure, pressure);
    state = state.copyWith(defaultStartPressure: pressure);
  }

  // Decompression & Safety setters

  Future<void> setGfLow(int value) async {
    final clamped = value.clamp(0, 100);
    await _prefs.setInt(SettingsKeys.gfLow, clamped);
    state = state.copyWith(gfLow: clamped);
  }

  Future<void> setGfHigh(int value) async {
    final clamped = value.clamp(0, 100);
    await _prefs.setInt(SettingsKeys.gfHigh, clamped);
    state = state.copyWith(gfHigh: clamped);
  }

  /// Set both gradient factors at once
  Future<void> setGradientFactors(int low, int high) async {
    final clampedLow = low.clamp(0, 100);
    final clampedHigh = high.clamp(clampedLow, 100);
    await _prefs.setInt(SettingsKeys.gfLow, clampedLow);
    await _prefs.setInt(SettingsKeys.gfHigh, clampedHigh);
    state = state.copyWith(gfLow: clampedLow, gfHigh: clampedHigh);
  }

  Future<void> setPpO2MaxWorking(double value) async {
    final clamped = value.clamp(1.0, 1.6);
    await _prefs.setDouble(SettingsKeys.ppO2MaxWorking, clamped);
    state = state.copyWith(ppO2MaxWorking: clamped);
  }

  Future<void> setPpO2MaxDeco(double value) async {
    final clamped = value.clamp(1.2, 1.6);
    await _prefs.setDouble(SettingsKeys.ppO2MaxDeco, clamped);
    state = state.copyWith(ppO2MaxDeco: clamped);
  }

  Future<void> setCnsWarningThreshold(int value) async {
    final clamped = value.clamp(50, 100);
    await _prefs.setInt(SettingsKeys.cnsWarningThreshold, clamped);
    state = state.copyWith(cnsWarningThreshold: clamped);
  }

  Future<void> setAscentRateWarning(double value) async {
    final clamped = value.clamp(3.0, 18.0);
    await _prefs.setDouble(SettingsKeys.ascentRateWarning, clamped);
    state = state.copyWith(ascentRateWarning: clamped);
  }

  Future<void> setAscentRateCritical(double value) async {
    final clamped = value.clamp(6.0, 20.0);
    await _prefs.setDouble(SettingsKeys.ascentRateCritical, clamped);
    state = state.copyWith(ascentRateCritical: clamped);
  }

  Future<void> setShowCeilingOnProfile(bool value) async {
    await _prefs.setBool(SettingsKeys.showCeilingOnProfile, value);
    state = state.copyWith(showCeilingOnProfile: value);
  }

  Future<void> setShowAscentRateColors(bool value) async {
    await _prefs.setBool(SettingsKeys.showAscentRateColors, value);
    state = state.copyWith(showAscentRateColors: value);
  }

  Future<void> setShowNdlOnProfile(bool value) async {
    await _prefs.setBool(SettingsKeys.showNdlOnProfile, value);
    state = state.copyWith(showNdlOnProfile: value);
  }

  Future<void> setLastStopDepth(double value) async {
    final clamped = value.clamp(3.0, 6.0);
    await _prefs.setDouble(SettingsKeys.lastStopDepth, clamped);
    state = state.copyWith(lastStopDepth: clamped);
  }

  Future<void> setDecoStopIncrement(double value) async {
    final clamped = value.clamp(1.0, 3.0);
    await _prefs.setDouble(SettingsKeys.decoStopIncrement, clamped);
    state = state.copyWith(decoStopIncrement: clamped);
  }

  /// Set all units to metric
  Future<void> setMetric() async {
    await setDepthUnit(DepthUnit.meters);
    await setTemperatureUnit(TemperatureUnit.celsius);
    await setPressureUnit(PressureUnit.bar);
    await setVolumeUnit(VolumeUnit.liters);
    await setWeightUnit(WeightUnit.kilograms);
  }

  /// Set all units to imperial
  Future<void> setImperial() async {
    await setDepthUnit(DepthUnit.feet);
    await setTemperatureUnit(TemperatureUnit.fahrenheit);
    await setPressureUnit(PressureUnit.psi);
    await setVolumeUnit(VolumeUnit.cubicFeet);
    await setWeightUnit(WeightUnit.pounds);
  }
}

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});

/// Convenience providers for individual settings
final depthUnitProvider = Provider<DepthUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.depthUnit));
});

final temperatureUnitProvider = Provider<TemperatureUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.temperatureUnit));
});

final pressureUnitProvider = Provider<PressureUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.pressureUnit));
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider.select((s) => s.themeMode));
});

/// Decompression settings convenience providers
final gfLowProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider.select((s) => s.gfLow));
});

final gfHighProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider.select((s) => s.gfHigh));
});

final gfLowDecimalProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.gfLowDecimal));
});

final gfHighDecimalProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.gfHighDecimal));
});

final ppO2MaxWorkingProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.ppO2MaxWorking));
});

final ppO2MaxDecoProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.ppO2MaxDeco));
});

final cnsWarningThresholdProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider.select((s) => s.cnsWarningThreshold));
});

final ascentRateWarningProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.ascentRateWarning));
});

final ascentRateCriticalProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.ascentRateCritical));
});

final showCeilingOnProfileProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.showCeilingOnProfile));
});

final showAscentRateColorsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.showAscentRateColors));
});

final showNdlOnProfileProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.showNdlOnProfile));
});

final lastStopDepthProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.lastStopDepth));
});

final decoStopIncrementProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider.select((s) => s.decoStopIncrement));
});
