import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';

/// A rich dive FIT file (deco records, gas, settings, summary, GPS) built with
/// fit_tool's named messages.
Uint8List _richFitBytes() {
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

  final depths = [1.6, 29.5, 6.0, 0.5];
  for (var i = 0; i < depths.length; i++) {
    builder.add(
      RecordMessage()
        ..timestamp = start
            .add(Duration(seconds: i * 60))
            .millisecondsSinceEpoch
        ..depth = depths[i]
        ..temperature = 24
        ..nextStopDepth = i == 1 ? 6.0 : 0.0
        ..timeToSurface = i == 1 ? 480 : 0
        ..ndlTime = i == 1 ? 0 : 99
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
          .add(const Duration(seconds: 3600))
          .millisecondsSinceEpoch
      ..startTime = start.millisecondsSinceEpoch
      ..totalElapsedTime = 3600.0
      ..totalTimerTime = 3600.0
      ..startPositionLat = 35.815
      ..startPositionLong = 14.451,
  );

  return builder.build().toBytes();
}

DataMessage _genericTank(int globalId, Map<int, int> values) {
  final def = DefinitionMessage(
    globalId: globalId,
    fieldDefinitions: [
      for (final id in values.keys)
        FieldDefinition(
          id: id,
          size: id == 1 || id == 2 ? 2 : 4,
          type: id == 1 || id == 2 ? BaseType.UINT16 : BaseType.UINT32,
        ),
    ],
  );
  final m = GenericMessage(definitionMessage: def);
  values.forEach((id, v) => m.getField(id)!.setValue(0, v, null));
  return m;
}

/// A dive with air-integration, heart rate, and exit GPS, to exercise the
/// parser's conditional payload emission for those fields.
Uint8List _aiFitBytes() {
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
  builder.add(_genericTank(323, {0: sensor, 1: 22125, 2: 8811, 3: 199350}));

  const depths = [2.0, 20.0, 5.0];
  const pressuresRaw = [22000, 15000, 9000];
  for (var i = 0; i < depths.length; i++) {
    final t = start.add(Duration(seconds: i * 60));
    final record = RecordMessage()
      ..timestamp = t.millisecondsSinceEpoch
      ..depth = depths[i]
      ..temperature = 26
      ..heartRate = 70 + i;
    if (i == depths.length - 1) {
      record
        ..positionLat = 19.691
        ..positionLong = -156.041;
    }
    builder.add(record);
    final fitSec = t.millisecondsSinceEpoch ~/ 1000 - 631065600;
    builder.add(
      _genericTank(319, {253: fitSec, 0: sensor, 1: pressuresRaw[i]}),
    );
  }

  builder.add(
    DiveGasMessage()
      ..messageIndex = 0
      ..oxygenContent = 32
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
  test('returns an error payload for non-FIT bytes', () async {
    final payload = await const FitImportParser().parse(
      Uint8List.fromList([0, 1, 2, 3]),
    );
    expect(payload.entities, isEmpty);
    expect(payload.warnings, isNotEmpty);
  });

  test(
    'emits a UDDF-shaped payload with tanks, deco, gps, sourceUuid',
    () async {
      final payload = await const FitImportParser().parse(_richFitBytes());
      final dives = payload.entities[ImportEntityType.dives]!;
      expect(dives, hasLength(1));
      final d = dives.single;

      expect(d['diveNumber'], 73);
      expect(d['waterType'], 'salt');
      expect(d['gradientFactorLow'], 50);
      expect(d['decoAlgorithm'], 'zhl_16c');
      expect(d['cnsEnd'], 12);
      expect(d['otu'], 25);
      expect(d['surfaceInterval'], const Duration(seconds: 4612));
      expect(d['duration'], const Duration(seconds: 3263)); // bottom time
      expect(d['runtime'], const Duration(seconds: 3600)); // total elapsed
      expect(d['sourceUuid'], d['sourceId']);
      expect(d['latitude'], closeTo(35.815, 1e-3));
      expect(d['diveComputerModel'], 'Descent Mk3i');

      final tanks = d['tanks'] as List<Map<String, dynamic>>;
      expect(tanks, hasLength(1));
      expect(tanks.single['gasMix'], isA<GasMix>());
      expect((tanks.single['gasMix'] as GasMix).o2, 28);

      final profile = d['profile'] as List<Map<String, dynamic>>;
      expect(profile.any((p) => p['ceiling'] == 6.0), isTrue);
      expect(profile.any((p) => p['tts'] == 480), isTrue);
    },
  );

  test(
    'emits tank pressure, allTankPressures, exit GPS, and heart rate',
    () async {
      final payload = await const FitImportParser().parse(_aiFitBytes());
      final d = payload.entities[ImportEntityType.dives]!.single;

      final tanks = d['tanks'] as List<Map<String, dynamic>>;
      expect(tanks.single['startPressure'], closeTo(221.25, 1e-6));
      expect(tanks.single['endPressure'], closeTo(88.11, 1e-6));
      // Cylinder volume derived from volume_used: 1993.5 / 133.14 -> 15.0 L.
      expect(tanks.single['volume'], closeTo(15.0, 1e-9));
      expect(d['avgHeartRate'], isNotNull);
      expect(d['exitLatitude'], closeTo(19.691, 1e-3));

      final profile = d['profile'] as List<Map<String, dynamic>>;
      final withPressure = profile.where((p) => p['allTankPressures'] != null);
      expect(withPressure, isNotEmpty);
      final reading =
          (withPressure.first['allTankPressures'] as List).first as Map;
      expect(reading['tankIndex'], 0);
      expect(reading['pressure'], closeTo(220.0, 1e-6));
    },
  );
}
