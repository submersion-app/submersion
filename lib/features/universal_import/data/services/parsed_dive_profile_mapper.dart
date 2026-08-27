import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

/// Converts a libdivecomputer [pigeon.ParsedDive] into the profile-sample
/// maps the import pipeline consumes.
///
/// Shared by every importer that reaches libdivecomputer with raw device
/// bytes: Shearwater Cloud (`ShearwaterDiveMapper`) and MacDive SQLite
/// (`MacDiveDiveMapper`), which recovers the same Shearwater byte stream from
/// `ZDIVE.ZRAWDATA`. Keeping one implementation means a newly supported
/// sensor channel lands for both sources at once.
class ParsedDiveProfileMapper {
  const ParsedDiveProfileMapper._();

  /// Builds the `profile` value: one map per sample, with every sensor
  /// channel libdivecomputer reported.
  static List<Map<String, dynamic>> samples(pigeon.ParsedDive parsed) {
    return parsed.samples.map((s) {
      final sampleMap = <String, dynamic>{
        'timestamp': s.timeSeconds,
        'depth': s.depthMeters,
      };
      if (s.temperatureCelsius != null) {
        sampleMap['temperature'] = s.temperatureCelsius;
      }
      if (s.pressureBar != null) {
        // Key must be `allTankPressures`; `_storeTankPressures` reads only
        // this one, and the singular `pressure` key is ignored downstream.
        sampleMap['allTankPressures'] = <Map<String, dynamic>>[
          {'pressure': s.pressureBar, 'tankIndex': s.tankIndex ?? 0},
        ];
      }
      if (s.setpoint != null) {
        sampleMap['setpoint'] = s.setpoint;
      }
      if (s.ppo2 != null) {
        sampleMap['ppO2'] = s.ppo2;
      }
      // Per-cell CCR ppO2. libdivecomputer reports DC_SAMPLE_PPO2 once per
      // cell plus optionally once for the aggregate, and the native callback
      // keeps them apart; carry both, as the download path does. A dive whose
      // computer logs cells but no aggregate has its loop value averaged from
      // these downstream (resolveRebreatherPpO2), so they must survive alone.
      final cells = <double?>[
        s.o2Sensor1,
        s.o2Sensor2,
        s.o2Sensor3,
        s.o2Sensor4,
        s.o2Sensor5,
        s.o2Sensor6,
      ];
      for (var cell = 0; cell < cells.length; cell++) {
        if (cells[cell] != null) {
          sampleMap['o2Sensor${cell + 1}'] = cells[cell];
        }
      }
      // Raw cell output, carried independently of the bar values above: a
      // computer with an untrusted calibration reports these and nothing else
      // (issue #810).
      final cellMv = <int?>[
        s.o2SensorMv1,
        s.o2SensorMv2,
        s.o2SensorMv3,
        s.o2SensorMv4,
        s.o2SensorMv5,
        s.o2SensorMv6,
      ];
      for (var cell = 0; cell < cellMv.length; cell++) {
        if (cellMv[cell] != null) {
          sampleMap['o2SensorMv${cell + 1}'] = cellMv[cell];
        }
      }
      if (s.heartRate != null) {
        sampleMap['heartRate'] = s.heartRate;
      }
      if (s.cns != null) {
        sampleMap['cns'] = s.cns;
      }
      if (s.rbt != null) {
        sampleMap['rbt'] = s.rbt;
      }
      if (s.tts != null) {
        sampleMap['tts'] = s.tts;
      }
      if (s.decoType != null) {
        sampleMap['decoType'] = s.decoType;
      }
      if (s.decoDepth != null && s.decoType != null && s.decoType != 0) {
        sampleMap['ceiling'] = s.decoDepth;
      }
      if (s.decoType == 0 && s.decoTime != null) {
        sampleMap['ndl'] = s.decoTime;
      }
      return sampleMap;
    }).toList();
  }

  /// The coldest sample temperature, or null when no sample carried one.
  /// Used as a water-temperature fallback when the source metadata has none.
  static double? minSampleTemperature(pigeon.ParsedDive parsed) {
    final temps = parsed.samples
        .map((s) => s.temperatureCelsius)
        .whereType<double>()
        .toList();
    if (temps.isEmpty) return null;
    return temps.reduce((a, b) => a < b ? a : b);
  }
}
