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
      defaultDiveType: _prefs.getString(SettingsKeys.defaultDiveType) ?? 'recreational',
      defaultTankVolume: _prefs.getDouble(SettingsKeys.defaultTankVolume) ?? 12.0,
      defaultStartPressure: _prefs.getInt(SettingsKeys.defaultStartPressure) ?? 200,
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
