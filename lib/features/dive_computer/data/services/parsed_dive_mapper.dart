import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Convert a Pigeon ParsedDive to the app's DownloadedDive format.
DownloadedDive parsedDiveToDownloaded(pigeon.ParsedDive parsed) {
  // Some computers (e.g. Shearwater) don't provide top-level min/max
  // temperature — derive from profile samples when missing.
  final sampleTemps = parsed.samples
      .map((s) => s.temperatureCelsius)
      .whereType<double>()
      .toList();
  final minTemp =
      parsed.minTemperatureCelsius ??
      (sampleTemps.isNotEmpty
          ? sampleTemps.reduce((a, b) => a < b ? a : b)
          : null);
  final maxTemp =
      parsed.maxTemperatureCelsius ??
      (sampleTemps.isNotEmpty
          ? sampleTemps.reduce((a, b) => a > b ? a : b)
          : null);

  return DownloadedDive(
    startTime: DateTime.utc(
      parsed.dateTimeYear,
      parsed.dateTimeMonth,
      parsed.dateTimeDay,
      parsed.dateTimeHour,
      parsed.dateTimeMinute,
      parsed.dateTimeSecond,
    ),
    durationSeconds: parsed.durationSeconds,
    maxDepth: parsed.maxDepthMeters,
    // libdivecomputer zero-initializes this field; `0.0` means "not reported".
    avgDepth: parsed.avgDepthMeters != 0.0 ? parsed.avgDepthMeters : null,
    minTemperature: minTemp,
    maxTemperature: maxTemp,
    entryLatitude: _validCoord(parsed.entryLatitude, parsed.entryLongitude),
    entryLongitude: _validCoord(parsed.entryLongitude, parsed.entryLatitude),
    exitLatitude: _validCoord(parsed.exitLatitude, parsed.exitLongitude),
    exitLongitude: _validCoord(parsed.exitLongitude, parsed.exitLatitude),
    fingerprint: parsed.fingerprint,
    decoAlgorithm: parsed.decoAlgorithm,
    gfLow: parsed.gfLow,
    gfHigh: parsed.gfHigh,
    decoConservatism: parsed.decoConservatism,
    profile: parsed.samples
        .map(
          (s) => ProfileSample(
            timeSeconds: s.timeSeconds,
            depth: s.depthMeters,
            temperature: s.temperatureCelsius,
            pressure: s.pressureBar,
            tankIndex: s.tankIndex,
            heartRate: s.heartRate,
            setpoint: s.setpoint,
            ppo2: s.ppo2,
            cns: s.cns,
            rbt: s.rbt,
            decoType: s.decoType,
            decoTime: s.decoTime,
            decoDepth: s.decoDepth,
            tts: s.tts,
            ndl: s.decoType == 0 ? s.decoTime : null,
            ceiling: s.decoType != null && s.decoType != 0 ? s.decoDepth : null,
            o2Sensor1: s.o2Sensor1,
            o2Sensor2: s.o2Sensor2,
            o2Sensor3: s.o2Sensor3,
            o2Sensor4: s.o2Sensor4,
            o2Sensor5: s.o2Sensor5,
            o2Sensor6: s.o2Sensor6,
          ),
        )
        .toList(),
    // Gas-mix linking, tankless synthesis, and gas-switch derivation live in
    // the shared resolver so the download and reparse paths cannot drift apart.
    tanks: resolveParsedTanks(parsed),
    gasSwitches: resolveGasSwitches(parsed),
    events: parsed.events
        .map(
          (e) => DownloadedEvent(
            timeSeconds: e.timeSeconds,
            type: e.type,
            flags: e.data != null ? int.tryParse(e.data!['flags'] ?? '') : null,
            value: e.data != null ? int.tryParse(e.data!['value'] ?? '') : null,
          ),
        )
        .toList(),
    rawData: parsed.rawData,
    rawFingerprint: parsed.rawFingerprint,
  );
}

/// Returns [value] unless it is null or part of a libdivecomputer sentinel
/// invalid-fix pair: (0,0) or (-1,-1). [other] is the paired coordinate.
double? _validCoord(double? value, double? other) {
  if (value == null || other == null) return null;
  if (value == 0.0 && other == 0.0) return null;
  if (value == -1.0 && other == -1.0) return null;
  return value;
}
