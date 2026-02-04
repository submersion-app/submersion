import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

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
  static const String sacUnit = 'sac_unit';
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
  final AltitudeUnit altitudeUnit;
  final SacUnit sacUnit;
  final TimeFormat timeFormat;
  final DateFormatPreference dateFormat;
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

  // Appearance settings
  /// Show depth-based colored backgrounds on dive cards in the dive list
  final bool showDepthColoredDiveCards;

  /// Show dive site map as background on dive cards in the dive list
  final bool showMapBackgroundOnDiveCards;

  /// Show dive site map as background on site cards in the site list
  final bool showMapBackgroundOnSiteCards;

  // Dive profile marker settings
  /// Show max depth marker on dive profile chart
  final bool showMaxDepthMarker;

  /// Show pressure threshold markers (2/3, 1/2, 1/3) on dive profile chart
  final bool showPressureThresholdMarkers;

  // Dive profile chart default visibility settings
  /// Default metric for the right Y-axis on dive profile charts
  final ProfileRightAxisMetric defaultRightAxisMetric;

  /// Default visibility for temperature on dive profile
  final bool defaultShowTemperature;

  /// Default visibility for pressure on dive profile
  final bool defaultShowPressure;

  /// Default visibility for heart rate on dive profile
  final bool defaultShowHeartRate;

  /// Default visibility for SAC rate on dive profile
  final bool defaultShowSac;

  /// Default visibility for events on dive profile
  final bool defaultShowEvents;

  /// Default visibility for ppO2 on dive profile
  final bool defaultShowPpO2;

  /// Default visibility for ppN2 on dive profile
  final bool defaultShowPpN2;

  /// Default visibility for ppHe on dive profile
  final bool defaultShowPpHe;

  /// Default visibility for gas density on dive profile
  final bool defaultShowGasDensity;

  /// Default visibility for GF% on dive profile
  final bool defaultShowGf;

  /// Default visibility for Surface GF on dive profile
  final bool defaultShowSurfaceGf;

  /// Default visibility for mean depth on dive profile
  final bool defaultShowMeanDepth;

  /// Default visibility for TTS on dive profile
  final bool defaultShowTts;

  /// Default visibility for gas switch markers on dive profile
  final bool defaultShowGasSwitchMarkers;

  // Notification settings
  final bool notificationsEnabled;
  final List<int> serviceReminderDays;
  final TimeOfDay reminderTime;

  const AppSettings({
    this.depthUnit = DepthUnit.meters,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.pressureUnit = PressureUnit.bar,
    this.volumeUnit = VolumeUnit.liters,
    this.weightUnit = WeightUnit.kilograms,
    this.altitudeUnit = AltitudeUnit.meters,
    this.sacUnit = SacUnit.pressurePerMin,
    this.timeFormat = TimeFormat.twelveHour,
    this.dateFormat = DateFormatPreference.mmmDYYYY,
    this.themeMode = ThemeMode.system,
    this.defaultDiveType = 'recreational',
    this.defaultTankVolume = 12.0,
    this.defaultStartPressure = 200,
    // Decompression defaults
    this.gfLow = 50,
    this.gfHigh = 85,
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
    // Appearance defaults
    this.showDepthColoredDiveCards = false,
    this.showMapBackgroundOnDiveCards = false,
    this.showMapBackgroundOnSiteCards = false,
    // Dive profile marker defaults
    this.showMaxDepthMarker = true,
    this.showPressureThresholdMarkers = false,
    // Dive profile chart defaults
    this.defaultRightAxisMetric = ProfileRightAxisMetric.temperature,
    this.defaultShowTemperature = true,
    this.defaultShowPressure = false,
    this.defaultShowHeartRate = false,
    this.defaultShowSac = false,
    this.defaultShowEvents = true,
    this.defaultShowPpO2 = false,
    this.defaultShowPpN2 = false,
    this.defaultShowPpHe = false,
    this.defaultShowGasDensity = false,
    this.defaultShowGf = false,
    this.defaultShowSurfaceGf = false,
    this.defaultShowMeanDepth = false,
    this.defaultShowTts = false,
    this.defaultShowGasSwitchMarkers = true,
    // Notification defaults
    this.notificationsEnabled = true,
    this.serviceReminderDays = const [7, 14, 30],
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
  });

  /// Compute the current unit preset based on actual unit values
  UnitPreset get unitPreset {
    final isAllMetric =
        depthUnit == DepthUnit.meters &&
        temperatureUnit == TemperatureUnit.celsius &&
        pressureUnit == PressureUnit.bar &&
        volumeUnit == VolumeUnit.liters &&
        weightUnit == WeightUnit.kilograms &&
        altitudeUnit == AltitudeUnit.meters;

    final isAllImperial =
        depthUnit == DepthUnit.feet &&
        temperatureUnit == TemperatureUnit.fahrenheit &&
        pressureUnit == PressureUnit.psi &&
        volumeUnit == VolumeUnit.cubicFeet &&
        weightUnit == WeightUnit.pounds &&
        altitudeUnit == AltitudeUnit.feet;

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
    AltitudeUnit? altitudeUnit,
    SacUnit? sacUnit,
    TimeFormat? timeFormat,
    DateFormatPreference? dateFormat,
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
    bool? showDepthColoredDiveCards,
    bool? showMapBackgroundOnDiveCards,
    bool? showMapBackgroundOnSiteCards,
    bool? showMaxDepthMarker,
    bool? showPressureThresholdMarkers,
    ProfileRightAxisMetric? defaultRightAxisMetric,
    bool? defaultShowTemperature,
    bool? defaultShowPressure,
    bool? defaultShowHeartRate,
    bool? defaultShowSac,
    bool? defaultShowEvents,
    bool? defaultShowPpO2,
    bool? defaultShowPpN2,
    bool? defaultShowPpHe,
    bool? defaultShowGasDensity,
    bool? defaultShowGf,
    bool? defaultShowSurfaceGf,
    bool? defaultShowMeanDepth,
    bool? defaultShowTts,
    bool? defaultShowGasSwitchMarkers,
    bool? notificationsEnabled,
    List<int>? serviceReminderDays,
    TimeOfDay? reminderTime,
  }) {
    return AppSettings(
      depthUnit: depthUnit ?? this.depthUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      pressureUnit: pressureUnit ?? this.pressureUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      weightUnit: weightUnit ?? this.weightUnit,
      altitudeUnit: altitudeUnit ?? this.altitudeUnit,
      sacUnit: sacUnit ?? this.sacUnit,
      timeFormat: timeFormat ?? this.timeFormat,
      dateFormat: dateFormat ?? this.dateFormat,
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
      showDepthColoredDiveCards:
          showDepthColoredDiveCards ?? this.showDepthColoredDiveCards,
      showMapBackgroundOnDiveCards:
          showMapBackgroundOnDiveCards ?? this.showMapBackgroundOnDiveCards,
      showMapBackgroundOnSiteCards:
          showMapBackgroundOnSiteCards ?? this.showMapBackgroundOnSiteCards,
      showMaxDepthMarker: showMaxDepthMarker ?? this.showMaxDepthMarker,
      showPressureThresholdMarkers:
          showPressureThresholdMarkers ?? this.showPressureThresholdMarkers,
      defaultRightAxisMetric:
          defaultRightAxisMetric ?? this.defaultRightAxisMetric,
      defaultShowTemperature:
          defaultShowTemperature ?? this.defaultShowTemperature,
      defaultShowPressure: defaultShowPressure ?? this.defaultShowPressure,
      defaultShowHeartRate: defaultShowHeartRate ?? this.defaultShowHeartRate,
      defaultShowSac: defaultShowSac ?? this.defaultShowSac,
      defaultShowEvents: defaultShowEvents ?? this.defaultShowEvents,
      defaultShowPpO2: defaultShowPpO2 ?? this.defaultShowPpO2,
      defaultShowPpN2: defaultShowPpN2 ?? this.defaultShowPpN2,
      defaultShowPpHe: defaultShowPpHe ?? this.defaultShowPpHe,
      defaultShowGasDensity:
          defaultShowGasDensity ?? this.defaultShowGasDensity,
      defaultShowGf: defaultShowGf ?? this.defaultShowGf,
      defaultShowSurfaceGf: defaultShowSurfaceGf ?? this.defaultShowSurfaceGf,
      defaultShowMeanDepth: defaultShowMeanDepth ?? this.defaultShowMeanDepth,
      defaultShowTts: defaultShowTts ?? this.defaultShowTts,
      defaultShowGasSwitchMarkers:
          defaultShowGasSwitchMarkers ?? this.defaultShowGasSwitchMarkers,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      serviceReminderDays: serviceReminderDays ?? this.serviceReminderDays,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

/// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

/// Repository provider for diver settings
final diverSettingsRepositoryProvider = Provider<DiverSettingsRepository>((
  ref,
) {
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
        _isLoading =
            false; // Allow loading even if previous load was in progress
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    // Get current diver ID directly (more reliable than going through FutureProvider)
    final currentId = _ref.read(currentDiverIdProvider);
    final repository = _ref.read(diverRepositoryProvider);

    String? diverId = currentId;

    // Validate that the current diver ID actually exists in the database.
    // This handles the case where the database was deleted/recreated but
    // SharedPreferences still has a stale diver ID.
    if (diverId != null) {
      final diver = await repository.getDiverById(diverId);
      if (diver == null) {
        // Stale ID - clear it and fall through to default diver
        diverId = null;
      }
    }

    // If no valid current diver ID, try to get default diver
    if (diverId == null) {
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

      // Schedule notifications with the loaded settings
      _scheduleNotificationsIfNeeded();
    } finally {
      _isLoading = false;
    }
  }

  void _scheduleNotificationsIfNeeded() {
    // Use Future.microtask to avoid calling during build
    Future.microtask(() async {
      if (!state.notificationsEnabled) return;

      final diverId = _validatedDiverId;
      final scheduler = NotificationScheduler();

      try {
        await scheduler.scheduleAll(settings: state, diverId: diverId);
      } catch (e) {
        // Log but don't rethrow - notification scheduling shouldn't block settings
        LoggerService.forClass(
          SettingsNotifier,
        ).error('Failed to schedule notifications', e, StackTrace.current);
      }
    });
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

  Future<void> setSacUnit(SacUnit unit) async {
    state = state.copyWith(sacUnit: unit);
    await _saveSettings();
  }

  Future<void> setAltitudeUnit(AltitudeUnit unit) async {
    state = state.copyWith(altitudeUnit: unit);
    await _saveSettings();
  }

  Future<void> setTimeFormat(TimeFormat format) async {
    state = state.copyWith(timeFormat: format);
    await _saveSettings();
  }

  Future<void> setDateFormat(DateFormatPreference format) async {
    state = state.copyWith(dateFormat: format);
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

  // Appearance setters

  Future<void> setShowDepthColoredDiveCards(bool value) async {
    state = state.copyWith(showDepthColoredDiveCards: value);
    await _saveSettings();
  }

  Future<void> setShowMapBackgroundOnDiveCards(bool value) async {
    state = state.copyWith(showMapBackgroundOnDiveCards: value);
    await _saveSettings();
  }

  Future<void> setShowMapBackgroundOnSiteCards(bool value) async {
    state = state.copyWith(showMapBackgroundOnSiteCards: value);
    await _saveSettings();
  }

  Future<void> setShowMaxDepthMarker(bool value) async {
    state = state.copyWith(showMaxDepthMarker: value);
    await _saveSettings();
  }

  Future<void> setShowPressureThresholdMarkers(bool value) async {
    state = state.copyWith(showPressureThresholdMarkers: value);
    await _saveSettings();
  }

  // Dive profile chart defaults setters

  Future<void> setDefaultRightAxisMetric(ProfileRightAxisMetric metric) async {
    state = state.copyWith(defaultRightAxisMetric: metric);
    await _saveSettings();
  }

  Future<void> setDefaultShowTemperature(bool value) async {
    state = state.copyWith(defaultShowTemperature: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowPressure(bool value) async {
    state = state.copyWith(defaultShowPressure: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowHeartRate(bool value) async {
    state = state.copyWith(defaultShowHeartRate: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowSac(bool value) async {
    state = state.copyWith(defaultShowSac: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowEvents(bool value) async {
    state = state.copyWith(defaultShowEvents: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowPpO2(bool value) async {
    state = state.copyWith(defaultShowPpO2: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowPpN2(bool value) async {
    state = state.copyWith(defaultShowPpN2: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowPpHe(bool value) async {
    state = state.copyWith(defaultShowPpHe: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowGasDensity(bool value) async {
    state = state.copyWith(defaultShowGasDensity: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowGf(bool value) async {
    state = state.copyWith(defaultShowGf: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowSurfaceGf(bool value) async {
    state = state.copyWith(defaultShowSurfaceGf: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowMeanDepth(bool value) async {
    state = state.copyWith(defaultShowMeanDepth: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowTts(bool value) async {
    state = state.copyWith(defaultShowTts: value);
    await _saveSettings();
  }

  Future<void> setDefaultShowGasSwitchMarkers(bool value) async {
    state = state.copyWith(defaultShowGasSwitchMarkers: value);
    await _saveSettings();
  }

  // Notification settings setters

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _saveSettings();
  }

  Future<void> setServiceReminderDays(List<int> days) async {
    // Sort and deduplicate
    final sortedDays = days.toSet().toList()..sort((a, b) => b.compareTo(a));
    state = state.copyWith(serviceReminderDays: sortedDays);
    await _saveSettings();
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    state = state.copyWith(reminderTime: time);
    await _saveSettings();
  }

  Future<void> toggleReminderDay(int days) async {
    final current = List<int>.from(state.serviceReminderDays);
    if (current.contains(days)) {
      // Don't allow removing the last day
      if (current.length > 1) {
        current.remove(days);
      }
    } else {
      current.add(days);
    }
    await setServiceReminderDays(current);
  }

  /// Set all units to metric
  Future<void> setMetric() async {
    state = state.copyWith(
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      weightUnit: WeightUnit.kilograms,
      altitudeUnit: AltitudeUnit.meters,
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
      altitudeUnit: AltitudeUnit.feet,
    );
    await _saveSettings();
  }
}

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
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

final sacUnitProvider = Provider<SacUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.sacUnit));
});

final altitudeUnitProvider = Provider<AltitudeUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.altitudeUnit));
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

/// Appearance settings convenience providers
final showDepthColoredDiveCardsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.showDepthColoredDiveCards));
});

final showMapBackgroundOnDiveCardsProvider = Provider<bool>((ref) {
  return ref.watch(
    settingsProvider.select((s) => s.showMapBackgroundOnDiveCards),
  );
});

final showMapBackgroundOnSiteCardsProvider = Provider<bool>((ref) {
  return ref.watch(
    settingsProvider.select((s) => s.showMapBackgroundOnSiteCards),
  );
});

final showMaxDepthMarkerProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.showMaxDepthMarker));
});

final showPressureThresholdMarkersProvider = Provider<bool>((ref) {
  return ref.watch(
    settingsProvider.select((s) => s.showPressureThresholdMarkers),
  );
});

/// Time/Date format convenience providers
final timeFormatProvider = Provider<TimeFormat>((ref) {
  return ref.watch(settingsProvider.select((s) => s.timeFormat));
});

final dateFormatProvider = Provider<DateFormatPreference>((ref) {
  return ref.watch(settingsProvider.select((s) => s.dateFormat));
});

/// Notification settings convenience providers
final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.notificationsEnabled));
});

final serviceReminderDaysProvider = Provider<List<int>>((ref) {
  return ref.watch(settingsProvider.select((s) => s.serviceReminderDays));
});

final reminderTimeProvider = Provider<TimeOfDay>((ref) {
  return ref.watch(settingsProvider.select((s) => s.reminderTime));
});

/// Dive profile chart defaults convenience providers
final defaultRightAxisMetricProvider = Provider<ProfileRightAxisMetric>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultRightAxisMetric));
});

final defaultShowTemperatureProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowTemperature));
});

final defaultShowPressureProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowPressure));
});

final defaultShowHeartRateProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowHeartRate));
});

final defaultShowSacProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowSac));
});

final defaultShowEventsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowEvents));
});

final defaultShowPpO2Provider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowPpO2));
});

final defaultShowPpN2Provider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowPpN2));
});

final defaultShowPpHeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowPpHe));
});

final defaultShowGasDensityProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowGasDensity));
});

final defaultShowGfProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowGf));
});

final defaultShowSurfaceGfProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowSurfaceGf));
});

final defaultShowMeanDepthProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowMeanDepth));
});

final defaultShowTtsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.defaultShowTts));
});

final defaultShowGasSwitchMarkersProvider = Provider<bool>((ref) {
  return ref.watch(
    settingsProvider.select((s) => s.defaultShowGasSwitchMarkers),
  );
});
