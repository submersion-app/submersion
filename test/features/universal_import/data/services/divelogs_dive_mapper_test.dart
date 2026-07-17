import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_dive_mapper.dart';

void main() {
  const mapper = DivelogsDiveMapper();

  DivelogsDive dive({
    String? id = '4711',
    String? siteName = 'Shinenead',
    double? lat = 24.6,
    double? lng = 35.1,
  }) => DivelogsDive(
    id: id,
    dateTime: DateTime.utc(2022, 9, 3, 14, 42),
    durationSeconds: 2808,
    maxDepth: 12,
    meanDepth: 7.9,
    sampleRateSeconds: 10,
    samples: const [
      DivelogsSample(depth: 1, temperature: 13),
      DivelogsSample(depth: 10),
    ],
    tanks: const [
      DivelogsTank(
        o2: 28,
        he: 0,
        startPressure: 214.56,
        endPressure: 103,
        volume: 12,
        workingPressure: 200,
      ),
    ],
    buddy: 'Buddy',
    siteName: siteName,
    location: 'Aegypten, Rotes Meer',
    notes: 'nice dive',
    weather: 'sunny',
    visibility: 'good',
    dcModel: 'Suunto D6',
    latitude: lat,
    longitude: lng,
    airTemp: 28,
    depthTemp: 21,
    surfaceTemp: 26,
    weightsKg: 4,
    surfaceIntervalSeconds: 3600,
  );

  test('maps core fields with importer-compatible keys', () {
    final map = mapper.mapDive(dive());
    expect(map['dateTime'], DateTime.utc(2022, 9, 3, 14, 42));
    expect(map['runtime'], const Duration(seconds: 2808));
    expect(map['maxDepth'], 12.0);
    expect(map['avgDepth'], 7.9);
    expect(map['waterTemp'], 21.0); // depthtemp wins over surfacetemp
    expect(map['airTemp'], 28.0);
    expect(map['buddy'], 'Buddy');
    expect(map['buddyRefs'], ['Buddy']);
    expect(map['weightUsed'], 4.0);
    expect(map['latitude'], 24.6);
    expect(map['longitude'], 35.1);
    expect(map['diveComputerModel'], 'Suunto D6');
    expect(map['surfaceInterval'], const Duration(seconds: 3600));
    expect(map['sourceUuid'], 'divelogs:4711');
  });

  test('appends weather, visibility, and location to notes', () {
    final notes = mapper.mapDive(dive())['notes'] as String;
    expect(notes, contains('nice dive'));
    expect(notes, contains('Weather: sunny'));
    expect(notes, contains('Visibility: good'));
    expect(notes, contains('Location: Aegypten, Rotes Meer'));
  });

  test('builds profile from samples using samplerate', () {
    final profile = mapper.mapDive(dive())['profile'] as List;
    expect(profile, hasLength(2));
    expect(profile[0], {'timestamp': 0, 'depth': 1.0, 'temperature': 13.0});
    expect((profile[1] as Map)['timestamp'], 10);
    expect((profile[1] as Map).containsKey('temperature'), isFalse);
  });

  test('builds tank maps with GasMix and double volume', () {
    final tanks = mapper.mapDive(dive())['tanks'] as List;
    final tank = tanks.single as Map<String, dynamic>;
    expect((tank['gasMix'] as GasMix).o2, 28.0);
    expect(tank['startPressure'], 214.56);
    expect(tank['endPressure'], 103.0);
    expect(tank['volume'], isA<double>());
    expect(tank['workingPressure'], 200.0);
  });

  test('links dive to site entity via uddfId and mapSite emits site map', () {
    final d = dive();
    final map = mapper.mapDive(d);
    final site = mapper.mapSite(d)!;
    expect((map['site'] as Map)['uddfId'], site['uddfId']);
    expect(site['name'], 'Shinenead');
    expect(site['latitude'], 24.6);
    expect(site['longitude'], 35.1);
  });

  test('no sourceUuid key when remote id missing', () {
    expect(mapper.mapDive(dive(id: null)).containsKey('sourceUuid'), isFalse);
  });

  test('no site when name missing', () {
    final d = dive(siteName: null);
    expect(mapper.mapSite(d), isNull);
    expect(mapper.mapDive(d).containsKey('site'), isFalse);
  });

  test('maps gearitems to equipmentRefs with the divelogs gear keys', () {
    final d = DivelogsDive(
      dateTime: DateTime.utc(2022),
      durationSeconds: 60,
      maxDepth: 5,
      gearItemIds: const ['45', '62'],
    );
    expect(mapper.mapDive(d)['equipmentRefs'], [
      'divelogs-gear-45',
      'divelogs-gear-62',
    ]);
  });

  test('no equipmentRefs key without gearitems', () {
    final d = DivelogsDive(
      dateTime: DateTime.utc(2022),
      durationSeconds: 60,
      maxDepth: 5,
    );
    expect(mapper.mapDive(d).containsKey('equipmentRefs'), isFalse);
  });

  test('zero weights and temps are treated as unset', () {
    final d = DivelogsDive(
      dateTime: DateTime.utc(2022),
      durationSeconds: 60,
      maxDepth: 5,
      weightsKg: 0,
      airTemp: 0,
    );
    final map = mapper.mapDive(d);
    expect(map.containsKey('weightUsed'), isFalse);
    expect(map.containsKey('airTemp'), isFalse);
  });
}
