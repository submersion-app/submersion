import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/units.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/diver_settings_repository.dart';

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

/// Repository provider for diver settings
final diverSettingsRepositoryProvider = Provider<DiverSettingsRepository>((ref) {
  return DiverSettingsRepository();
});

/// Settings notifier that persists to database per-diver
class SettingsNotifier extends StateNotifier<AppSettings> {
  final DiverSettingsRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;
  bool _isLoading = false;

  SettingsNotifier(this._repository, this._ref) : super(const AppSettings()) {
    _initializeAndLoad();

    // Listen for diver changes and reload settings
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        // Reset diver ID immediately to prevent saving to wrong diver during switch
        _validatedDiverId = null;
        _isLoading = false; // Allow loading even if previous load was in progress
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    // Get current diver ID directly (more reliable than going through FutureProvider)
    final currentId = _ref.read(currentDiverIdProvider);

    String? diverId = currentId;

    // If no current diver ID, try to get default diver
    if (diverId == null) {
      final repository = _ref.read(diverRepositoryProvider);
      final defaultDiver = await repository.getDefaultDiver();
      diverId = defaultDiver?.id;
    }

    _validatedDiverId = diverId;
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final diverId = _validatedDiverId;
      if (diverId == null) {
        // No diver selected, use defaults
        state = const AppSettings();
        return;
      }

      // Load settings from database
      final settings = await _repository.getOrCreateSettingsForDiver(diverId);
      state = settings;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _saveSettings() async {
    final diverId = _validatedDiverId;
    if (diverId == null) return;
    await _repository.updateSettingsForDiver(diverId, state);
  }

  Future<void> setDepthUnit(DepthUnit unit) async {
    state = state.copyWith(depthUnit: unit);
    await _saveSettings();
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    state = state.copyWith(temperatureUnit: unit);
    await _saveSettings();
  }

  Future<void> setPressureUnit(PressureUnit unit) async {
    state = state.copyWith(pressureUnit: unit);
    await _saveSettings();
  }

  Future<void> setVolumeUnit(VolumeUnit unit) async {
    state = state.copyWith(volumeUnit: unit);
    await _saveSettings();
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    state = state.copyWith(weightUnit: unit);
    await _saveSettings();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _saveSettings();
  }

  Future<void> setDefaultDiveType(String diveType) async {
    state = state.copyWith(defaultDiveType: diveType);
    await _saveSettings();
  }

  Future<void> setDefaultTankVolume(double volume) async {
    state = state.copyWith(defaultTankVolume: volume);
    await _saveSettings();
  }

  Future<void> setDefaultStartPressure(int pressure) async {
    state = state.copyWith(defaultStartPressure: pressure);
    await _saveSettings();
  }

  // Decompression & Safety setters

  Future<void> setGfLow(int value) async {
    final clamped = value.clamp(0, 100);
    state = state.copyWith(gfLow: clamped);
    await _saveSettings();
  }

  Future<void> setGfHigh(int value) async {
    final clamped = value.clamp(0, 100);
    state = state.copyWith(gfHigh: clamped);
    await _saveSettings();
  }

  /// Set both gradient factors at once
  Future<void> setGradientFactors(int low, int high) async {
    final clampedLow = low.clamp(0, 100);
    final clampedHigh = high.clamp(clampedLow, 100);
    state = state.copyWith(gfLow: clampedLow, gfHigh: clampedHigh);
    await _saveSettings();
  }

  Future<void> setPpO2MaxWorking(double value) async {
    final clamped = value.clamp(1.0, 1.6);
    state = state.copyWith(ppO2MaxWorking: clamped);
    await _saveSettings();
  }

  Future<void> setPpO2MaxDeco(double value) async {
    final clamped = value.clamp(1.2, 1.6);
    state = state.copyWith(ppO2MaxDeco: clamped);
    await _saveSettings();
  }

  Future<void> setCnsWarningThreshold(int value) async {
    final clamped = value.clamp(50, 100);
    state = state.copyWith(cnsWarningThreshold: clamped);
    await _saveSettings();
  }

  Future<void> setAscentRateWarning(double value) async {
    final clamped = value.clamp(3.0, 18.0);
    state = state.copyWith(ascentRateWarning: clamped);
    await _saveSettings();
  }

  Future<void> setAscentRateCritical(double value) async {
    final clamped = value.clamp(6.0, 20.0);
    state = state.copyWith(ascentRateCritical: clamped);
    await _saveSettings();
  }

  Future<void> setShowCeilingOnProfile(bool value) async {
    state = state.copyWith(showCeilingOnProfile: value);
    await _saveSettings();
  }

  Future<void> setShowAscentRateColors(bool value) async {
    state = state.copyWith(showAscentRateColors: value);
    await _saveSettings();
  }

  Future<void> setShowNdlOnProfile(bool value) async {
    state = state.copyWith(showNdlOnProfile: value);
    await _saveSettings();
  }

  Future<void> setLastStopDepth(double value) async {
    final clamped = value.clamp(3.0, 6.0);
    state = state.copyWith(lastStopDepth: clamped);
    await _saveSettings();
  }

  Future<void> setDecoStopIncrement(double value) async {
    final clamped = value.clamp(1.0, 3.0);
    state = state.copyWith(decoStopIncrement: clamped);
    await _saveSettings();
  }

  /// Set all units to metric
  Future<void> setMetric() async {
    state = state.copyWith(
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      weightUnit: WeightUnit.kilograms,
    );
    await _saveSettings();
  }

  /// Set all units to imperial
  Future<void> setImperial() async {
    state = state.copyWith(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    );
    await _saveSettings();
  }
}

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repository = ref.watch(diverSettingsRepositoryProvider);
  return SettingsNotifier(repository, ref);
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
