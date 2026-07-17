import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_export_mapper.dart';

void main() {
  const mapper = DivelogsExportMapper();

  Dive dive({
    Duration? runtime = const Duration(seconds: 2808),
    double? maxDepth = 18.5,
    List<DiveProfilePoint> profile = const [],
  }) => Dive(
    id: 'd1',
    dateTime: DateTime.utc(2022, 9, 3, 14, 42, 30),
    entryTime: DateTime.utc(2022, 9, 3, 14, 42, 30),
    runtime: runtime,
    maxDepth: maxDepth,
    avgDepth: 7.9,
    notes: 'nice dive',
    buddy: 'Buddy',
    airTemp: 28,
    waterTemp: 21,
    weightAmount: 4,
    surfaceInterval: const Duration(hours: 1),
    diveComputerModel: 'Suunto D6',
    profile: profile,
    site: const DiveSite(
      id: 's1',
      name: 'Shinenead',
      location: GeoPoint(24.6, 35.1),
      country: 'Egypt',
      region: 'Red Sea',
    ),
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 12,
        workingPressure: 200,
        startPressure: 214.5,
        endPressure: 103,
        gasMix: GasMix(o2: 28),
        name: 'Main',
      ),
    ],
  );

  test('maps mandatory and optional fields to API schema keys', () {
    final json = mapper.mapDive(dive())!;
    expect(json['date'], '2022-09-03');
    expect(json['time'], '14:42:30');
    expect(json['duration'], 2808);
    expect(json['maxdepth'], 18.5);
    expect(json['meandepth'], 7.9);
    expect(json['buddy'], 'Buddy');
    expect(json['divesite'], 'Shinenead');
    expect(json['lat'], 24.6);
    expect(json['lng'], 35.1);
    expect(json['location'], 'Egypt, Red Sea');
    expect(json['notes'], 'nice dive');
    expect(json['airtemp'], 28);
    expect(json['depthtemp'], 21);
    expect(json['weights'], 4);
    expect(json['surface_interval'], 3600);
    expect(json['dc_model'], 'Suunto D6');
    final tank = (json['tanks'] as List).single as Map<String, dynamic>;
    expect(tank['o2'], 28.0);
    expect(tank['he'], 0.0);
    expect(tank['start_pressure'], 214.5);
    expect(tank['end_pressure'], 103);
    expect(tank['vol'], 12);
    expect(tank['wp'], 200);
    expect(tank['tankname'], 'Main');
  });

  test('emits uniform profiles as sampledata with samplerate', () {
    final json = mapper.mapDive(
      dive(
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 1, temperature: 13),
          DiveProfilePoint(timestamp: 10, depth: 10),
          DiveProfilePoint(timestamp: 20, depth: 5),
        ],
      ),
    )!;
    expect(json['samplerate'], 10);
    final samples = json['sampledata'] as List;
    expect(samples[0], {'d': 1.0, 't': 13.0});
    expect(samples[1], 10.0);
    expect(samples[2], 5.0);
  });

  test('omits sampledata for non-uniform profiles', () {
    final json = mapper.mapDive(
      dive(
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 1),
          DiveProfilePoint(timestamp: 7, depth: 10),
          DiveProfilePoint(timestamp: 20, depth: 5),
        ],
      ),
    )!;
    expect(json.containsKey('sampledata'), isFalse);
    expect(json.containsKey('samplerate'), isFalse);
  });

  test('returns null when duration or maxdepth cannot be produced', () {
    expect(mapper.mapDive(dive(runtime: null)), isNull);
    expect(mapper.mapDive(dive(maxDepth: null)), isNull);
  });

  test('falls back to profile max depth when maxDepth is null', () {
    final json = mapper.mapDive(
      dive(
        maxDepth: null,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 3),
          DiveProfilePoint(timestamp: 10, depth: 9.5),
        ],
      ),
    );
    expect(json, isNotNull);
    expect(json!['maxdepth'], 9.5);
  });
}
