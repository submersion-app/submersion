import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/units.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../presentation/providers/settings_providers.dart';

class DiverSettingsRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiverSettingsRepository);

  /// Get settings for a specific diver
  Future<AppSettings?> getSettingsForDiver(String diverId) async {
    try {
      final query = _db.select(_db.diverSettings)
        ..where((t) => t.diverId.equals(diverId));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToAppSettings(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get settings for diver: $diverId', e, stackTrace);
      rethrow;
    }
  }

  /// Create default settings for a diver
  Future<AppSettings> createSettingsForDiver(String diverId, {AppSettings? settings}) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final s = settings ?? const AppSettings();

      await _db.into(_db.diverSettings).insert(DiverSettingsCompanion(
        id: Value(id),
        diverId: Value(diverId),
        depthUnit: Value(s.depthUnit.name),
        temperatureUnit: Value(s.temperatureUnit.name),
        pressureUnit: Value(s.pressureUnit.name),
        volumeUnit: Value(s.volumeUnit.name),
        weightUnit: Value(s.weightUnit.name),
        themeMode: Value(_themeModeToString(s.themeMode)),
        defaultDiveType: Value(s.defaultDiveType),
        defaultTankVolume: Value(s.defaultTankVolume),
        defaultStartPressure: Value(s.defaultStartPressure),
        gfLow: Value(s.gfLow),
        gfHigh: Value(s.gfHigh),
        ppO2MaxWorking: Value(s.ppO2MaxWorking),
        ppO2MaxDeco: Value(s.ppO2MaxDeco),
        cnsWarningThreshold: Value(s.cnsWarningThreshold),
        ascentRateWarning: Value(s.ascentRateWarning),
        ascentRateCritical: Value(s.ascentRateCritical),
        showCeilingOnProfile: Value(s.showCeilingOnProfile),
        showAscentRateColors: Value(s.showAscentRateColors),
        showNdlOnProfile: Value(s.showNdlOnProfile),
        lastStopDepth: Value(s.lastStopDepth),
        decoStopIncrement: Value(s.decoStopIncrement),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),);

      _log.info('Created settings for diver: $diverId');
      return s;
    } catch (e, stackTrace) {
      _log.error('Failed to create settings for diver: $diverId', e, stackTrace);
      rethrow;
    }
  }

  /// Update settings for a diver
  Future<void> updateSettingsForDiver(String diverId, AppSettings settings) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.diverSettings)..where((t) => t.diverId.equals(diverId))).write(
        DiverSettingsCompanion(
          depthUnit: Value(settings.depthUnit.name),
          temperatureUnit: Value(settings.temperatureUnit.name),
          pressureUnit: Value(settings.pressureUnit.name),
          volumeUnit: Value(settings.volumeUnit.name),
          weightUnit: Value(settings.weightUnit.name),
          themeMode: Value(_themeModeToString(settings.themeMode)),
          defaultDiveType: Value(settings.defaultDiveType),
          defaultTankVolume: Value(settings.defaultTankVolume),
          defaultStartPressure: Value(settings.defaultStartPressure),
          gfLow: Value(settings.gfLow),
          gfHigh: Value(settings.gfHigh),
          ppO2MaxWorking: Value(settings.ppO2MaxWorking),
          ppO2MaxDeco: Value(settings.ppO2MaxDeco),
          cnsWarningThreshold: Value(settings.cnsWarningThreshold),
          ascentRateWarning: Value(settings.ascentRateWarning),
          ascentRateCritical: Value(settings.ascentRateCritical),
          showCeilingOnProfile: Value(settings.showCeilingOnProfile),
          showAscentRateColors: Value(settings.showAscentRateColors),
          showNdlOnProfile: Value(settings.showNdlOnProfile),
          lastStopDepth: Value(settings.lastStopDepth),
          decoStopIncrement: Value(settings.decoStopIncrement),
          updatedAt: Value(now),
        ),
      );
      _log.info('Updated settings for diver: $diverId');
    } catch (e, stackTrace) {
      _log.error('Failed to update settings for diver: $diverId', e, stackTrace);
      rethrow;
    }
  }

  /// Get or create settings for a diver (ensures settings always exist)
  Future<AppSettings> getOrCreateSettingsForDiver(String diverId, {AppSettings? defaultSettings}) async {
    final existing = await getSettingsForDiver(diverId);
    if (existing != null) {
      return existing;
    }
    return createSettingsForDiver(diverId, settings: defaultSettings);
  }

  /// Delete settings for a diver
  Future<void> deleteSettingsForDiver(String diverId) async {
    try {
      await (_db.delete(_db.diverSettings)..where((t) => t.diverId.equals(diverId))).go();
      _log.info('Deleted settings for diver: $diverId');
    } catch (e, stackTrace) {
      _log.error('Failed to delete settings for diver: $diverId', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  AppSettings _mapRowToAppSettings(DiverSetting row) {
    return AppSettings(
      depthUnit: _parseDepthUnit(row.depthUnit),
      temperatureUnit: _parseTemperatureUnit(row.temperatureUnit),
      pressureUnit: _parsePressureUnit(row.pressureUnit),
      volumeUnit: _parseVolumeUnit(row.volumeUnit),
      weightUnit: _parseWeightUnit(row.weightUnit),
      themeMode: _parseThemeMode(row.themeMode),
      defaultDiveType: row.defaultDiveType,
      defaultTankVolume: row.defaultTankVolume,
      defaultStartPressure: row.defaultStartPressure,
      gfLow: row.gfLow,
      gfHigh: row.gfHigh,
      ppO2MaxWorking: row.ppO2MaxWorking,
      ppO2MaxDeco: row.ppO2MaxDeco,
      cnsWarningThreshold: row.cnsWarningThreshold,
      ascentRateWarning: row.ascentRateWarning,
      ascentRateCritical: row.ascentRateCritical,
      showCeilingOnProfile: row.showCeilingOnProfile,
      showAscentRateColors: row.showAscentRateColors,
      showNdlOnProfile: row.showNdlOnProfile,
      lastStopDepth: row.lastStopDepth,
      decoStopIncrement: row.decoStopIncrement,
    );
  }

  DepthUnit _parseDepthUnit(String value) {
    return DepthUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DepthUnit.meters,
    );
  }

  TemperatureUnit _parseTemperatureUnit(String value) {
    return TemperatureUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TemperatureUnit.celsius,
    );
  }

  PressureUnit _parsePressureUnit(String value) {
    return PressureUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PressureUnit.bar,
    );
  }

  VolumeUnit _parseVolumeUnit(String value) {
    return VolumeUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VolumeUnit.liters,
    );
  }

  WeightUnit _parseWeightUnit(String value) {
    return WeightUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WeightUnit.kilograms,
    );
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
