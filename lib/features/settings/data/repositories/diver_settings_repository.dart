import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class DiverSettingsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
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
  Future<AppSettings> createSettingsForDiver(
    String diverId, {
    AppSettings? settings,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final s = settings ?? const AppSettings();

      await _db
          .into(_db.diverSettings)
          .insert(
            DiverSettingsCompanion(
              id: Value(id),
              diverId: Value(diverId),
              depthUnit: Value(s.depthUnit.name),
              temperatureUnit: Value(s.temperatureUnit.name),
              pressureUnit: Value(s.pressureUnit.name),
              volumeUnit: Value(s.volumeUnit.name),
              weightUnit: Value(s.weightUnit.name),
              altitudeUnit: Value(s.altitudeUnit.name),
              sacUnit: Value(s.sacUnit.name),
              timeFormat: Value(s.timeFormat.name),
              dateFormat: Value(s.dateFormat.name),
              themeMode: Value(_themeModeToString(s.themeMode)),
              locale: Value(s.locale),
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
              showDepthColoredDiveCards: Value(s.showDepthColoredDiveCards),
              cardColorAttribute: Value(s.cardColorAttribute.name),
              cardColorGradientPreset: Value(s.cardColorGradientPreset),
              cardColorGradientStart: Value(s.cardColorGradientStart),
              cardColorGradientEnd: Value(s.cardColorGradientEnd),
              showMapBackgroundOnDiveCards: Value(
                s.showMapBackgroundOnDiveCards,
              ),
              showMapBackgroundOnSiteCards: Value(
                s.showMapBackgroundOnSiteCards,
              ),
              showMaxDepthMarker: Value(s.showMaxDepthMarker),
              showPressureThresholdMarkers: Value(
                s.showPressureThresholdMarkers,
              ),
              defaultRightAxisMetric: Value(s.defaultRightAxisMetric.name),
              defaultShowTemperature: Value(s.defaultShowTemperature),
              defaultShowPressure: Value(s.defaultShowPressure),
              defaultShowHeartRate: Value(s.defaultShowHeartRate),
              defaultShowSac: Value(s.defaultShowSac),
              defaultShowEvents: Value(s.defaultShowEvents),
              defaultShowPpO2: Value(s.defaultShowPpO2),
              defaultShowPpN2: Value(s.defaultShowPpN2),
              defaultShowPpHe: Value(s.defaultShowPpHe),
              defaultShowGasDensity: Value(s.defaultShowGasDensity),
              defaultShowGf: Value(s.defaultShowGf),
              defaultShowSurfaceGf: Value(s.defaultShowSurfaceGf),
              defaultShowMeanDepth: Value(s.defaultShowMeanDepth),
              defaultShowTts: Value(s.defaultShowTts),
              defaultShowGasSwitchMarkers: Value(s.defaultShowGasSwitchMarkers),
              notificationsEnabled: Value(s.notificationsEnabled),
              serviceReminderDays: Value(
                _formatReminderDays(s.serviceReminderDays),
              ),
              reminderTime: Value(_formatReminderTime(s.reminderTime)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'diverSettings',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created settings for diver: $diverId');
      return s;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create settings for diver: $diverId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update settings for a diver
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.diverSettings,
      )..where((t) => t.diverId.equals(diverId))).write(
        DiverSettingsCompanion(
          depthUnit: Value(settings.depthUnit.name),
          temperatureUnit: Value(settings.temperatureUnit.name),
          pressureUnit: Value(settings.pressureUnit.name),
          volumeUnit: Value(settings.volumeUnit.name),
          weightUnit: Value(settings.weightUnit.name),
          altitudeUnit: Value(settings.altitudeUnit.name),
          sacUnit: Value(settings.sacUnit.name),
          timeFormat: Value(settings.timeFormat.name),
          dateFormat: Value(settings.dateFormat.name),
          themeMode: Value(_themeModeToString(settings.themeMode)),
          locale: Value(settings.locale),
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
          showDepthColoredDiveCards: Value(settings.showDepthColoredDiveCards),
          cardColorAttribute: Value(settings.cardColorAttribute.name),
          cardColorGradientPreset: Value(settings.cardColorGradientPreset),
          cardColorGradientStart: Value(settings.cardColorGradientStart),
          cardColorGradientEnd: Value(settings.cardColorGradientEnd),
          showMapBackgroundOnDiveCards: Value(
            settings.showMapBackgroundOnDiveCards,
          ),
          showMapBackgroundOnSiteCards: Value(
            settings.showMapBackgroundOnSiteCards,
          ),
          showMaxDepthMarker: Value(settings.showMaxDepthMarker),
          showPressureThresholdMarkers: Value(
            settings.showPressureThresholdMarkers,
          ),
          defaultRightAxisMetric: Value(settings.defaultRightAxisMetric.name),
          defaultShowTemperature: Value(settings.defaultShowTemperature),
          defaultShowPressure: Value(settings.defaultShowPressure),
          defaultShowHeartRate: Value(settings.defaultShowHeartRate),
          defaultShowSac: Value(settings.defaultShowSac),
          defaultShowEvents: Value(settings.defaultShowEvents),
          defaultShowPpO2: Value(settings.defaultShowPpO2),
          defaultShowPpN2: Value(settings.defaultShowPpN2),
          defaultShowPpHe: Value(settings.defaultShowPpHe),
          defaultShowGasDensity: Value(settings.defaultShowGasDensity),
          defaultShowGf: Value(settings.defaultShowGf),
          defaultShowSurfaceGf: Value(settings.defaultShowSurfaceGf),
          defaultShowMeanDepth: Value(settings.defaultShowMeanDepth),
          defaultShowTts: Value(settings.defaultShowTts),
          defaultShowGasSwitchMarkers: Value(
            settings.defaultShowGasSwitchMarkers,
          ),
          notificationsEnabled: Value(settings.notificationsEnabled),
          serviceReminderDays: Value(
            _formatReminderDays(settings.serviceReminderDays),
          ),
          reminderTime: Value(_formatReminderTime(settings.reminderTime)),
          updatedAt: Value(now),
        ),
      );
      final row = await (_db.select(
        _db.diverSettings,
      )..where((t) => t.diverId.equals(diverId))).getSingleOrNull();
      if (row != null) {
        await _syncRepository.markRecordPending(
          entityType: 'diverSettings',
          recordId: row.id,
          localUpdatedAt: now,
        );
        SyncEventBus.notifyLocalChange();
      }
      _log.info('Updated settings for diver: $diverId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update settings for diver: $diverId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get or create settings for a diver (ensures settings always exist)
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    final existing = await getSettingsForDiver(diverId);
    if (existing != null) {
      return existing;
    }
    return createSettingsForDiver(diverId, settings: defaultSettings);
  }

  /// Delete settings for a diver
  Future<void> deleteSettingsForDiver(String diverId) async {
    try {
      final rows = await (_db.select(
        _db.diverSettings,
      )..where((t) => t.diverId.equals(diverId))).get();
      await (_db.delete(
        _db.diverSettings,
      )..where((t) => t.diverId.equals(diverId))).go();
      for (final row in rows) {
        await _syncRepository.logDeletion(
          entityType: 'diverSettings',
          recordId: row.id,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted settings for diver: $diverId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete settings for diver: $diverId',
        e,
        stackTrace,
      );
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
      altitudeUnit: _parseAltitudeUnit(row.altitudeUnit),
      sacUnit: _parseSacUnit(row.sacUnit),
      timeFormat: _parseTimeFormat(row.timeFormat),
      dateFormat: _parseDateFormat(row.dateFormat),
      themeMode: _parseThemeMode(row.themeMode),
      locale: row.locale,
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
      cardColorAttribute: CardColorAttribute.fromName(row.cardColorAttribute),
      cardColorGradientPreset: row.cardColorGradientPreset,
      cardColorGradientStart: row.cardColorGradientStart,
      cardColorGradientEnd: row.cardColorGradientEnd,
      showMapBackgroundOnDiveCards: row.showMapBackgroundOnDiveCards,
      showMapBackgroundOnSiteCards: row.showMapBackgroundOnSiteCards,
      showMaxDepthMarker: row.showMaxDepthMarker,
      showPressureThresholdMarkers: row.showPressureThresholdMarkers,
      defaultRightAxisMetric: _parseRightAxisMetric(row.defaultRightAxisMetric),
      defaultShowTemperature: row.defaultShowTemperature,
      defaultShowPressure: row.defaultShowPressure,
      defaultShowHeartRate: row.defaultShowHeartRate,
      defaultShowSac: row.defaultShowSac,
      defaultShowEvents: row.defaultShowEvents,
      defaultShowPpO2: row.defaultShowPpO2,
      defaultShowPpN2: row.defaultShowPpN2,
      defaultShowPpHe: row.defaultShowPpHe,
      defaultShowGasDensity: row.defaultShowGasDensity,
      defaultShowGf: row.defaultShowGf,
      defaultShowSurfaceGf: row.defaultShowSurfaceGf,
      defaultShowMeanDepth: row.defaultShowMeanDepth,
      defaultShowTts: row.defaultShowTts,
      defaultShowGasSwitchMarkers: row.defaultShowGasSwitchMarkers,
      notificationsEnabled: row.notificationsEnabled,
      serviceReminderDays: _parseReminderDays(row.serviceReminderDays),
      reminderTime: _parseReminderTime(row.reminderTime),
    );
  }

  DepthUnit _parseDepthUnit(String value) {
    return DepthUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DepthUnit.meters,
    );
  }

  ProfileRightAxisMetric _parseRightAxisMetric(String value) {
    return ProfileRightAxisMetric.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProfileRightAxisMetric.temperature,
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

  AltitudeUnit _parseAltitudeUnit(String value) {
    return AltitudeUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AltitudeUnit.meters,
    );
  }

  SacUnit _parseSacUnit(String value) {
    return SacUnit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SacUnit.pressurePerMin,
    );
  }

  TimeFormat _parseTimeFormat(String value) {
    return TimeFormat.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TimeFormat.twelveHour,
    );
  }

  DateFormatPreference _parseDateFormat(String value) {
    return DateFormatPreference.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DateFormatPreference.mmmDYYYY,
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

  List<int> _parseReminderDays(String json) {
    try {
      final trimmed = json.trim();
      if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
        return const [7, 14, 30];
      }
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isEmpty) return const [7, 14, 30];
      return inner.split(',').map((s) => int.parse(s.trim())).toList();
    } catch (_) {
      return const [7, 14, 30];
    }
  }

  TimeOfDay _parseReminderTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatReminderDays(List<int> days) => '[${days.join(', ')}]';

  String _formatReminderTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
