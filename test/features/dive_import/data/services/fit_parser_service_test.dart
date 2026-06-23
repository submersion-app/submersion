import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

/// Builds a minimal FIT file representing a dive activity.
///
/// Uses [FitFileBuilder] to construct valid FIT binary data with:
/// - FileIdMessage (device serial, activity type)
/// - SessionMessage (sport=diving, times, optional GPS)
/// - RecordMessages (depth, temperature, heart rate samples)
Uint8List buildTestDiveFitFile({
  required DateTime startTime,
  required int durationSeconds,
  required List<double> depthSamples,
  List<double?>? temperatureSamples,
  List<int?>? heartRateSamples,
  int serialNumber = 12345,
  double? startLat,
  double? startLong,
}) {
  final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);

  // FileId message: identifies this as an activity file
  final fileId = FileIdMessage()
    ..type = FileType.activity
    ..manufacturer =
        1 // Garmin
    ..product =
        3943 // Descent Mk2
    ..serialNumber = serialNumber
    ..timeCreated = startTime.millisecondsSinceEpoch;

  builder.add(fileId);

  // Record messages: time-series depth/temp/HR samples
  final sampleInterval = durationSeconds ~/ depthSamples.length;
  for (var i = 0; i < depthSamples.length; i++) {
    final record = RecordMessage()
      ..timestamp = startTime
          .add(Duration(seconds: i * sampleInterval))
          .millisecondsSinceEpoch
      ..depth = depthSamples[i];

    if (temperatureSamples != null && i < temperatureSamples.length) {
      final temp = temperatureSamples[i];
      if (temp != null) {
        record.temperature = temp.toInt();
      }
    }

    if (heartRateSamples != null && i < heartRateSamples.length) {
      final hr = heartRateSamples[i];
      if (hr != null) {
        record.heartRate = hr;
      }
    }

    builder.add(record);
  }

  // Session message: activity summary
  final endTime = startTime.add(Duration(seconds: durationSeconds));
  final session = SessionMessage()
    ..sport = Sport.diving
    ..timestamp = endTime.millisecondsSinceEpoch
    ..startTime = startTime.millisecondsSinceEpoch
    ..totalElapsedTime = durationSeconds.toDouble()
    ..totalTimerTime = durationSeconds.toDouble();

  if (startLat != null) {
    session.startPositionLat = startLat;
  }
  if (startLong != null) {
    session.startPositionLong = startLong;
  }

  builder.add(session);

  return builder.build().toBytes();
}

/// Builds a FIT file for a non-dive activity (running).
Uint8List buildTestRunningFitFile({
  required DateTime startTime,
  int durationSeconds = 1800,
  int serialNumber = 99999,
}) {
  final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);

  final fileId = FileIdMessage()
    ..type = FileType.activity
    ..manufacturer = 1
    ..serialNumber = serialNumber
    ..timeCreated = startTime.millisecondsSinceEpoch;

  builder.add(fileId);

  // Add a few record messages (no depth)
  for (var i = 0; i < 5; i++) {
    final record = RecordMessage()
      ..timestamp = startTime
          .add(Duration(seconds: i * 60))
          .millisecondsSinceEpoch
      ..heartRate = 140 + i;

    builder.add(record);
  }

  final endTime = startTime.add(Duration(seconds: durationSeconds));
  final session = SessionMessage()
    ..sport = Sport.running
    ..timestamp = endTime.millisecondsSinceEpoch
    ..startTime = startTime.millisecondsSinceEpoch
    ..totalElapsedTime = durationSeconds.toDouble()
    ..totalTimerTime = durationSeconds.toDouble();

  builder.add(session);

  return builder.build().toBytes();
}

/// Builds a feature-rich dive FIT file (deco records, gas mix, dive settings,
/// dive summary, GPS) for exercising the enriched orchestrator.
Uint8List buildRichDiveFitFile() {
  final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);
  final start = DateTime.utc(2025, 10, 13, 11, 24, 0);

  builder.add(
    FileIdMessage()
      ..type = FileType.activity
      ..manufacturer = 1
      ..product =
          4223 // Descent Mk3i
      ..serialNumber = 3502016516
      ..timeCreated = start.millisecondsSinceEpoch,
  );

  final depths = [1.6, 15.0, 29.5, 20.0, 6.0, 0.5];
  for (var i = 0; i < depths.length; i++) {
    builder.add(
      RecordMessage()
        ..timestamp = start
            .add(Duration(seconds: i * 60))
            .millisecondsSinceEpoch
        ..depth = depths[i]
        ..temperature = 24
        ..nextStopDepth = i == 2 ? 6.0 : 0.0
        ..ndlTime = i == 2 ? 0 : 99
        ..timeToSurface = i == 2 ? 480 : 0
        ..cnsLoad = i + 1,
    );
  }

  builder.add(
    DiveGasMessage()
      ..messageIndex = 0
      ..oxygenContent = 28
      ..heliumContent = 0
      ..status = DiveGasStatus.enabled,
  );

  builder.add(
    DiveSettingsMessage()
      ..waterType = WaterType.salt
      ..gfLow = 50
      ..gfHigh = 85
      ..model = TissueModelType.zhl16c,
  );

  builder.add(
    DiveSummaryMessage()
      ..diveNumber = 73
      ..bottomTime = 3263.0
      ..surfaceInterval = 4612
      ..startCns = 0
      ..endCns = 12
      ..o2Toxicity = 25,
  );

  builder.add(
    SessionMessage()
      ..sport = Sport.diving
      ..timestamp = start
          .add(const Duration(seconds: 360))
          .millisecondsSinceEpoch
      ..startTime = start.millisecondsSinceEpoch
      ..totalElapsedTime = 360.0
      ..totalTimerTime = 360.0
      ..startPositionLat = 35.815
      ..startPositionLong = 14.451,
  );

  return builder.build().toBytes();
}

/// A synthetic unnamed FIT message (e.g. tank_update/tank_summary) built the way
/// fit_tool reconstructs messages it has no profile for.
DataMessage _genericTank(int globalId, Map<int, int> values) {
  final def = DefinitionMessage(
    globalId: globalId,
    fieldDefinitions: [
      for (final id in values.keys)
        FieldDefinition(
          id: id,
          size: id == 1 || id == 2 ? 2 : 4, // pressure fields are uint16
          type: id == 1 || id == 2 ? BaseType.UINT16 : BaseType.UINT32,
        ),
    ],
  );
  final m = GenericMessage(definitionMessage: def);
  values.forEach((id, v) => m.getField(id)!.setValue(0, v, null));
  return m;
}

/// A dive FIT file with air-integration: a tank_summary (323) and a tank_update
/// (319) per record, all on one transmitter, plus one gas mix.
Uint8List buildAiDiveFitFile() {
  final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);
  final start = DateTime.utc(2025, 9, 8, 9, 19, 49);
  const sensor = 2772884913;

  builder.add(
    FileIdMessage()
      ..type = FileType.activity
      ..manufacturer = 1
      ..product = 4223
      ..serialNumber = 1
      ..timeCreated = start.millisecondsSinceEpoch,
  );

  // tank_summary: start 22125 -> 221.25 bar, end 8811 -> 88.11 bar, vol 199350.
  builder.add(_genericTank(323, {0: sensor, 1: 22125, 2: 8811, 3: 199350}));

  const depths = [2.0, 20.0, 5.0];
  const pressuresRaw = [22000, 15000, 9000];
  for (var i = 0; i < depths.length; i++) {
    final t = start.add(Duration(seconds: i * 60));
    builder.add(
      RecordMessage()
        ..timestamp = t.millisecondsSinceEpoch
        ..depth = depths[i]
        ..temperature = 26,
    );
    // tank_update at the same instant; field 253 is raw FIT-epoch seconds.
    final fitSec = t.millisecondsSinceEpoch ~/ 1000 - 631065600;
    builder.add(_genericTank(319, {253: fitSec, 0: sensor, 1: pressuresRaw[i]}));
  }

  builder.add(
    DiveGasMessage()
      ..messageIndex = 0
      ..oxygenContent = 28
      ..heliumContent = 0
      ..status = DiveGasStatus.enabled,
  );
  builder.add(
    SessionMessage()
      ..sport = Sport.diving
      ..timestamp = start
          .add(const Duration(seconds: 180))
          .millisecondsSinceEpoch
      ..startTime = start.millisecondsSinceEpoch
      ..totalElapsedTime = 180.0
      ..totalTimerTime = 180.0,
  );

  return builder.build().toBytes();
}

void main() {
  late FitParserService service;

  setUp(() {
    service = const FitParserService();
  });

  group('parseFitFile', () {
    test('returns ImportedDive for valid dive FIT file', () async {
      final startTime = DateTime(2024, 6, 15, 10, 30, 0);
      final bytes = buildTestDiveFitFile(
        startTime: startTime,
        durationSeconds: 3600, // 1 hour
        depthSamples: [0.0, 5.0, 10.0, 18.0, 20.0, 15.0, 8.0, 3.0, 0.0],
        temperatureSamples: [
          22.0,
          21.0,
          20.0,
          19.0,
          19.0,
          20.0,
          21.0,
          21.0,
          22.0,
        ],
        heartRateSamples: [70, 80, 85, 90, 88, 85, 80, 75, 70],
        serialNumber: 54321,
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.source, ImportSource.garmin);
      expect(result.maxDepth, 20.0);
      expect(result.profile, isNotEmpty);
    });

    test('returns null for non-dive FIT file (running activity)', () async {
      final bytes = buildTestRunningFitFile(
        startTime: DateTime(2024, 6, 15, 8, 0, 0),
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNull);
    });

    test('returns null for corrupt/invalid bytes', () async {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);

      final result = await service.parseFitFile(bytes);

      expect(result, isNull);
    });

    test('returns null for empty bytes', () async {
      final bytes = Uint8List(0);

      final result = await service.parseFitFile(bytes);

      expect(result, isNull);
    });

    test('extracts correct start and end times from session', () async {
      // Built as UTC so the wall-clock-as-UTC assertion is timezone-independent.
      final startTime = DateTime.utc(2024, 3, 20, 14, 0, 0);
      const durationSeconds = 2400; // 40 minutes
      final bytes = buildTestDiveFitFile(
        startTime: startTime,
        durationSeconds: durationSeconds,
        depthSamples: [0.0, 10.0, 15.0, 10.0, 0.0],
      );

      final result = await service.parseFitFile(bytes);

      // Parser stores local wall-clock time as UTC (wall-time-as-UTC convention)
      final expectedStart = DateTime.utc(2024, 3, 20, 14, 0, 0);
      expect(result, isNotNull);
      expect(result!.startTime, expectedStart);
      expect(
        result.endTime,
        expectedStart.add(const Duration(seconds: durationSeconds)),
      );
    });

    test('computes max depth from record messages', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 1800,
        depthSamples: [0.0, 5.0, 12.5, 25.3, 18.0, 10.0, 0.0],
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.maxDepth, 25.3);
    });

    test('computes average depth from record messages', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 600,
        depthSamples: [10.0, 20.0, 30.0],
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.avgDepth, 20.0);
    });

    test('extracts temperature range from records', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 1800,
        depthSamples: [0.0, 10.0, 20.0, 10.0, 0.0],
        temperatureSamples: [22.0, 20.0, 18.0, 19.0, 21.0],
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.minTemperature, 18.0);
      expect(result.maxTemperature, 22.0);
    });

    test('computes average heart rate from records', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 1200,
        depthSamples: [10.0, 20.0, 15.0, 5.0],
        heartRateSamples: [70, 80, 90, 80],
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.avgHeartRate, 80.0);
    });

    test('extracts GPS coordinates from session', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 1800,
        depthSamples: [0.0, 10.0, 0.0],
        startLat: 28.4594,
        startLong: -16.3228,
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(28.4594, 0.001));
      expect(result.longitude, closeTo(-16.3228, 0.001));
    });

    test('builds profile samples with correct time offsets', () async {
      final startTime = DateTime(2024, 1, 1, 10, 0, 0);
      final bytes = buildTestDiveFitFile(
        startTime: startTime,
        durationSeconds: 600, // 10 min, 3 samples = 200s interval
        depthSamples: [5.0, 15.0, 8.0],
        temperatureSamples: [22.0, 20.0, 21.0],
        heartRateSamples: [70, 85, 75],
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.profile.length, 3);

      expect(result.profile[0].depth, 5.0);
      expect(result.profile[0].timeSeconds, 0);
      expect(result.profile[0].temperature, 22.0);
      expect(result.profile[0].heartRate, 70);

      expect(result.profile[1].depth, 15.0);
      expect(result.profile[1].timeSeconds, 200);
      expect(result.profile[1].temperature, 20.0);
      expect(result.profile[1].heartRate, 85);

      expect(result.profile[2].depth, 8.0);
      expect(result.profile[2].timeSeconds, 400);
      expect(result.profile[2].temperature, 21.0);
      expect(result.profile[2].heartRate, 75);
    });

    test('handles missing temperature in records', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 600,
        depthSamples: [5.0, 15.0, 8.0],
        // No temperature samples
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.minTemperature, isNull);
      expect(result.maxTemperature, isNull);
      for (final sample in result.profile) {
        expect(sample.temperature, isNull);
      }
    });

    test('handles missing heart rate in records', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 600,
        depthSamples: [5.0, 15.0, 8.0],
        // No heart rate samples
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.avgHeartRate, isNull);
      for (final sample in result.profile) {
        expect(sample.heartRate, isNull);
      }
    });

    test(
      'generates stable sourceId from serial number and start time',
      () async {
        final startTime = DateTime(2024, 6, 15, 10, 30, 0);
        final bytes = buildTestDiveFitFile(
          startTime: startTime,
          durationSeconds: 1800,
          depthSamples: [0.0, 10.0, 0.0],
          serialNumber: 98765,
        );

        final result1 = await service.parseFitFile(bytes);
        final result2 = await service.parseFitFile(bytes);

        expect(result1, isNotNull);
        expect(result2, isNotNull);
        expect(result1!.sourceId, result2!.sourceId);
        expect(
          result1.sourceId,
          'garmin-98765-${startTime.millisecondsSinceEpoch}',
        );
      },
    );

    test('handles GPS-less dive (no coordinates)', () async {
      final bytes = buildTestDiveFitFile(
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        durationSeconds: 1800,
        depthSamples: [0.0, 10.0, 0.0],
        // No GPS
      );

      final result = await service.parseFitFile(bytes);

      expect(result, isNotNull);
      expect(result!.latitude, isNull);
      expect(result.longitude, isNull);
    });

    test(
      'enriched parse surfaces gas, deco, dive number, GPS, water type',
      () async {
        final dive = await service.parseFitFile(buildRichDiveFitFile());

        expect(dive, isNotNull);
        expect(dive!.diveNumber, 73);
        expect(dive.waterType, 'salt');
        expect(dive.gfLow, 50);
        expect(dive.gfHigh, 85);
        expect(dive.decoModel, 'zhl_16c');
        expect(dive.cnsEnd, 12);
        expect(dive.otu, 25);
        expect(dive.bottomTimeSeconds, 3263);
        expect(dive.surfaceIntervalSeconds, 4612);
        expect(dive.latitude, closeTo(35.815, 1e-3));
        expect(dive.computerModel, 'Descent Mk3i');
        expect(dive.sourceUuid, dive.sourceId);
        // No transmitter -> synthesize a tank from the gas mix (EAN28).
        expect(dive.tanks, hasLength(1));
        expect(dive.tanks.single.o2Percent, 28);
        expect(dive.tanks.single.startPressureBar, isNull);
        // Recorded deco values present on the deep sample.
        expect(dive.profile.any((s) => s.ceiling == 6.0), isTrue);
        expect(dive.profile.any((s) => s.ttsSeconds == 480), isTrue);
      },
    );

    test('air-integration: tank pressure from msgs 319/323 merges to samples', () async {
      final dive = await service.parseFitFile(buildAiDiveFitFile());

      expect(dive, isNotNull);
      expect(dive!.tanks, hasLength(1));
      final tank = dive.tanks.single;
      expect(tank.o2Percent, 28);
      expect(tank.startPressureBar, closeTo(221.25, 1e-6));
      expect(tank.endPressureBar, closeTo(88.11, 1e-6));
      expect(tank.volumeUsedLiters, closeTo(1993.5, 1e-6));

      // The pressure series is merged onto the contemporaneous depth samples.
      final withPressure = dive.profile
          .where((s) => s.tankPressures != null)
          .toList();
      expect(withPressure, isNotEmpty);
      final firstReading = withPressure.first.tankPressures!.single;
      expect(firstReading.tankIndex, 0);
      expect(firstReading.pressureBar, closeTo(220.0, 1e-6));
    });
  });

  group('parseFitFiles', () {
    test(
      'returns only dive files, filtering out non-dive activities',
      () async {
        final diveBytes = buildTestDiveFitFile(
          startTime: DateTime(2024, 6, 15, 10, 0, 0),
          durationSeconds: 1800,
          depthSamples: [0.0, 15.0, 0.0],
          serialNumber: 11111,
        );
        final runBytes = buildTestRunningFitFile(
          startTime: DateTime(2024, 6, 15, 8, 0, 0),
          serialNumber: 22222,
        );
        final dive2Bytes = buildTestDiveFitFile(
          startTime: DateTime(2024, 6, 15, 14, 0, 0),
          durationSeconds: 2400,
          depthSamples: [0.0, 20.0, 0.0],
          serialNumber: 33333,
        );

        final results = await service.parseFitFiles(
          [diveBytes, runBytes, dive2Bytes],
          fileNames: ['dive1.fit', 'run.fit', 'dive2.fit'],
        );

        expect(results.length, 2);
        expect(results[0].maxDepth, 15.0);
        expect(results[1].maxDepth, 20.0);
      },
    );

    test('returns empty list for all-invalid files', () async {
      final corruptBytes = Uint8List.fromList([0, 1, 2]);
      final runBytes = buildTestRunningFitFile(
        startTime: DateTime(2024, 1, 1, 8, 0, 0),
      );

      final results = await service.parseFitFiles([corruptBytes, runBytes]);

      expect(results, isEmpty);
    });

    test('returns empty list for empty input', () async {
      final results = await service.parseFitFiles([]);

      expect(results, isEmpty);
    });
  });
}
