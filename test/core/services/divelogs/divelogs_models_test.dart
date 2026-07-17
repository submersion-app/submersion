import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';

void main() {
  Map<String, dynamic> minimal() => {
    'id': 4711,
    'date': '2022-09-03',
    'time': '14:42:00',
    'duration': 2808,
    'maxdepth': 12,
  };

  test('parses mandatory fields', () {
    final dive = DivelogsDive.fromJson(minimal());
    expect(dive.id, '4711');
    expect(dive.dateTime, DateTime.utc(2022, 9, 3, 14, 42));
    expect(dive.durationSeconds, 2808);
    expect(dive.maxDepth, 12.0);
    expect(dive.samples, isEmpty);
    expect(dive.tanks, isEmpty);
  });

  test('throws FormatException when a mandatory field is missing', () {
    final json = minimal()..remove('maxdepth');
    expect(() => DivelogsDive.fromJson(json), throwsFormatException);
  });

  test('parses mixed sampledata (bare depths and {d,t} objects)', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'samplerate': 10,
      'sampledata': [
        {'d': 1, 't': 13},
        10,
        {'d': 17, 't': 12},
        0,
      ],
    });
    expect(dive.sampleRateSeconds, 10);
    expect(dive.samples, hasLength(4));
    expect(dive.samples[0].depth, 1.0);
    expect(dive.samples[0].temperature, 13.0);
    expect(dive.samples[1].depth, 10.0);
    expect(dive.samples[1].temperature, isNull);
  });

  test('parses tanks', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'tanks': [
        {
          'o2': 28,
          'he': 0,
          'start_pressure': 214.56,
          'end_pressure': 103,
          'vol': 12,
          'wp': 200,
          'dbltank': false,
          'tankname': 'Main',
        },
      ],
    });
    expect(dive.tanks, hasLength(1));
    final tank = dive.tanks.single;
    expect(tank.o2, 28.0);
    expect(tank.startPressure, 214.56);
    expect(tank.endPressure, 103.0);
    expect(tank.volume, 12.0);
    expect(tank.workingPressure, 200.0);
    expect(tank.name, 'Main');
  });

  test('parses optional metadata fields', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'meandepth': 7.9,
      'buddy': 'Buddy',
      'divesite': 'Shinenead',
      'location': 'Aegypten, Rotes Meer',
      'lat': 24.669683,
      'lng': 35.125225,
      'notes': 'nice dive',
      'weather': 'sunny',
      'visibility': 'good',
      'airtemp': 28,
      'depthtemp': 21,
      'surfacetemp': 26,
      'weights': 4,
      'surface_interval': 3600,
      'dc_model': 'Suunto D6',
    });
    expect(dive.meanDepth, 7.9);
    expect(dive.buddy, 'Buddy');
    expect(dive.siteName, 'Shinenead');
    expect(dive.latitude, closeTo(24.669683, 1e-9));
    expect(dive.depthTemp, 21.0);
    expect(dive.weightsKg, 4.0);
    expect(dive.surfaceIntervalSeconds, 3600);
    expect(dive.dcModel, 'Suunto D6');
  });

  group('DivelogsDivelistEntry', () {
    test('parses id, date/time (wall-clock UTC), duration, maxdepth', () {
      final entry = DivelogsDivelistEntry.fromJson({
        'id': 4711,
        'date': '2022-09-03',
        'time': '14:42:00',
        'duration': 2808,
        'maxdepth': 12,
      })!;
      expect(entry.id, '4711');
      expect(entry.dateTime, DateTime.utc(2022, 9, 3, 14, 42));
      expect(entry.durationSeconds, 2808);
      expect(entry.maxDepth, 12.0);
    });

    test('tolerates missing duration and maxdepth', () {
      final entry = DivelogsDivelistEntry.fromJson({
        'id': '9',
        'date': '2022-09-03',
        'time': '14:42:00',
      })!;
      expect(entry.durationSeconds, isNull);
      expect(entry.maxDepth, isNull);
    });

    test('accepts a combined datetime field as fallback', () {
      final entry = DivelogsDivelistEntry.fromJson({
        'id': 9,
        'datetime': '2022-09-03 14:42:00',
      })!;
      expect(entry.dateTime, DateTime.utc(2022, 9, 3, 14, 42));
    });

    test('returns null when id or date is unusable', () {
      expect(DivelogsDivelistEntry.fromJson({'date': '2022-09-03'}), isNull);
      expect(DivelogsDivelistEntry.fromJson({'id': 1}), isNull);
    });
  });
}
