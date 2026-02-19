import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/domain/services/download_manager.dart';

/// Convert a Pigeon ParsedDive to the app's DownloadedDive format.
DownloadedDive parsedDiveToDownloaded(pigeon.ParsedDive parsed) {
  return DownloadedDive(
    startTime: DateTime.fromMillisecondsSinceEpoch(parsed.dateTimeEpoch * 1000),
    durationSeconds: parsed.durationSeconds,
    maxDepth: parsed.maxDepthMeters,
    avgDepth: parsed.avgDepthMeters,
    minTemperature: parsed.minTemperatureCelsius,
    maxTemperature: parsed.maxTemperatureCelsius,
    fingerprint: parsed.fingerprint,
    profile: parsed.samples
        .map(
          (s) => ProfileSample(
            timeSeconds: s.timeSeconds,
            depth: s.depthMeters,
            temperature: s.temperatureCelsius,
            pressure: s.pressureBar,
            tankIndex: s.tankIndex,
            heartRate: s.heartRate?.toInt(),
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
  );
}
