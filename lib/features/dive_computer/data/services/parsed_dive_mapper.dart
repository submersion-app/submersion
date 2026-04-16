import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
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
          ),
        )
        .toList(),
    tanks: parsed.tanks.map((t) {
      final gasMix = parsed.gasMixes.firstWhere(
        (g) => g.index == t.gasMixIndex,
        orElse: () => pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
      );
      return DownloadedTank(
        index: t.index,
        o2Percent: gasMix.o2Percent,
        hePercent: gasMix.hePercent,
        startPressure: t.startPressureBar,
        endPressure: t.endPressureBar,
        volumeLiters: t.volumeLiters,
      );
    }).toList(),
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
