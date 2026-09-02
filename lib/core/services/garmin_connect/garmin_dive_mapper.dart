import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

/// A dive mapped from a Garmin FIT export, plus the device identity fields
/// needed to resolve/create the owning [DiveComputer] record (kept separate
/// from [DownloadedDive], which has no computer-identity fields of its own).
class GarminParsedDive {
  const GarminParsedDive({
    required this.dive,
    this.deviceModel,
    this.serialNumber,
    this.firmwareVersion,
  });

  final DownloadedDive dive;
  final String? deviceModel;
  final String? serialNumber;
  final String? firmwareVersion;
}

/// Converts an [ImportedDive] (as produced by the existing
/// `FitParserService.parseFitFile` from a downloaded Garmin FIT file) into a
/// [DownloadedDive], the same shape a BLE/USB dive computer download
/// produces -- so the rest of the import pipeline (tanks, gas switches,
/// duplicate detection, consolidation) is shared with [DiveComputerAdapter]
/// and the Suunto cloud adapter, rather than falling back to the
/// [ImportedDiveConverter] path that drops tanks and gas switches.
class GarminDiveMapper {
  const GarminDiveMapper._();

  static GarminParsedDive map(
    ImportedDive imported, {
    required int activityId,
    double? fallbackLatitude,
    double? fallbackLongitude,
  }) {
    final tanks = _mapTanks(imported.tanks);
    final gasSwitches = _mapGasSwitches(imported.gasSwitches);
    final profile = _mapProfile(imported.profile);

    // The FIT file's own entry position is only set when the watch already
    // had a GPS fix the instant it started recording -- easy to miss
    // underwater/on descent. Connect's activity list carries its own
    // start-position estimate (derived from the full track or phone-assisted
    // positioning), which fills the gap when the FIT file's is missing.
    // Both the FIT file's own position and the fallback are used as pairs --
    // never mixing a lat from one source with a long from the other.
    final hasFitEntryPosition =
        imported.latitude != null && imported.longitude != null;
    final hasFallbackEntryPosition =
        fallbackLatitude != null && fallbackLongitude != null;
    final entryLatitude = hasFitEntryPosition
        ? imported.latitude
        : (hasFallbackEntryPosition ? fallbackLatitude : null);
    final entryLongitude = hasFitEntryPosition
        ? imported.longitude
        : (hasFallbackEntryPosition ? fallbackLongitude : null);

    final dive = DownloadedDive(
      diveNumber: imported.diveNumber,
      startTime: imported.startTime,
      durationSeconds: imported.durationSeconds,
      maxDepth: imported.maxDepth,
      avgDepth: imported.avgDepth,
      minTemperature: imported.minTemperature,
      maxTemperature: imported.maxTemperature,
      entryLatitude: entryLatitude,
      entryLongitude: entryLongitude,
      exitLatitude: imported.exitLatitude,
      exitLongitude: imported.exitLongitude,
      profile: profile,
      tanks: tanks,
      gasSwitches: gasSwitches,
      // A Garmin activity ID is stable and unique per dive, so it makes an
      // exact-match fingerprint for detectDuplicate -- re-running the import
      // skips already-imported dives instantly instead of relying solely on
      // fuzzy time/depth/duration matching.
      rawFingerprint: _fingerprintFor(activityId),
      decoAlgorithm: (imported.decoModel?.isNotEmpty ?? false)
          ? imported.decoModel
          : null,
      gfLow: imported.gfLow,
      gfHigh: imported.gfHigh,
    );

    return GarminParsedDive(
      dive: dive,
      deviceModel: imported.computerModel,
      serialNumber: imported.computerSerial,
      firmwareVersion: imported.computerFirmware,
    );
  }

  static Uint8List _fingerprintFor(int activityId) =>
      Uint8List.fromList(utf8.encode('garmin-activity-$activityId'));

  static List<DownloadedTank> _mapTanks(List<ImportedTank> tanks) {
    return [
      for (final tank in tanks)
        DownloadedTank(
          index: tank.order,
          o2Percent: tank.o2Percent ?? 21.0,
          hePercent: tank.hePercent ?? 0.0,
          startPressure: tank.startPressureBar,
          endPressure: tank.endPressureBar,
          volumeLiters: tank.volumeLiters,
        ),
    ];
  }

  static List<GasSwitchEvent> _mapGasSwitches(
    List<ImportedGasSwitch> gasSwitches,
  ) {
    return [
      for (final gasSwitch in gasSwitches)
        GasSwitchEvent(
          timeSeconds: gasSwitch.timeSeconds,
          depth: gasSwitch.depth ?? 0.0,
          toTankIndex: gasSwitch.tankIndex,
        ),
    ];
  }

  /// Maps profile samples 1:1, except a sample with more than one
  /// simultaneous tank-pressure reading (multiple air-integration
  /// transmitters): the first reading rides on the main sample, and every
  /// additional reading becomes an extra minimal sample at the same
  /// timestamp/depth. [ProfileSample] carries only one pressure/tankIndex
  /// pair per row, so this mirrors how multi-transmitter dive-computer
  /// downloads are represented elsewhere in this app (see
  /// SuuntoDiveParser._buildProfile, which documents the same convention).
  static List<ProfileSample> _mapProfile(List<ImportedProfileSample> profile) {
    final result = <ProfileSample>[];
    for (final sample in profile) {
      final pressures = sample.tankPressures ?? const [];

      result.add(
        ProfileSample(
          timeSeconds: sample.timeSeconds,
          depth: sample.depth,
          temperature: sample.temperature,
          heartRate: sample.heartRate,
          cns: sample.cns,
          ndl: sample.ndlSeconds,
          tts: sample.ttsSeconds,
          ceiling: sample.ceiling,
          pressure: pressures.isEmpty ? null : pressures.first.pressureBar,
          tankIndex: pressures.isEmpty ? null : pressures.first.tankIndex,
        ),
      );

      for (final extra in pressures.skip(1)) {
        result.add(
          ProfileSample(
            timeSeconds: sample.timeSeconds,
            depth: sample.depth,
            pressure: extra.pressureBar,
            tankIndex: extra.tankIndex,
          ),
        );
      }
    }
    return result;
  }
}
