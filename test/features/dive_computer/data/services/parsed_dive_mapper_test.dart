import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';

void main() {
  group('parsedDiveToDownloaded', () {
    pigeon.ParsedDive makeParsedDive({
      String fingerprint = 'abc123',
      int year = 2024,
      int month = 6,
      int day = 15,
      int hour = 8,
      int minute = 42,
      int second = 0,
      int? timezoneOffset,
      double maxDepthMeters = 20.0,
      double avgDepthMeters = 12.0,
      int durationSeconds = 3600,
      double? minTemperatureCelsius,
      double? maxTemperatureCelsius,
      List<pigeon.ProfileSample>? samples,
      List<pigeon.TankInfo>? tanks,
      List<pigeon.GasMix>? gasMixes,
      List<pigeon.DiveEvent>? events,
      String? decoAlgorithm,
      int? gfLow,
      int? gfHigh,
      int? decoConservatism,
      double? entryLatitude,
      double? entryLongitude,
      double? exitLatitude,
      double? exitLongitude,
    }) {
      return pigeon.ParsedDive(
        fingerprint: fingerprint,
        dateTimeYear: year,
        dateTimeMonth: month,
        dateTimeDay: day,
        dateTimeHour: hour,
        dateTimeMinute: minute,
        dateTimeSecond: second,
        dateTimeTimezoneOffset: timezoneOffset,
        maxDepthMeters: maxDepthMeters,
        avgDepthMeters: avgDepthMeters,
        durationSeconds: durationSeconds,
        minTemperatureCelsius: minTemperatureCelsius,
        maxTemperatureCelsius: maxTemperatureCelsius,
        samples: samples ?? [],
        tanks: tanks ?? [],
        gasMixes: gasMixes ?? [],
        events: events ?? [],
        decoAlgorithm: decoAlgorithm,
        gfLow: gfLow,
        gfHigh: gfHigh,
        decoConservatism: decoConservatism,
        entryLatitude: entryLatitude,
        entryLongitude: entryLongitude,
        exitLatitude: exitLatitude,
        exitLongitude: exitLongitude,
      );
    }

    // --- DateTime construction ---

    test('constructs wall-clock-as-UTC DateTime from components', () {
      final parsed = makeParsedDive(
        year: 2024,
        month: 6,
        day: 15,
        hour: 8,
        minute: 42,
        second: 30,
      );
      final result = parsedDiveToDownloaded(parsed);

      expect(result.startTime.isUtc, isTrue);
      expect(result.startTime.year, 2024);
      expect(result.startTime.month, 6);
      expect(result.startTime.day, 15);
      expect(result.startTime.hour, 8);
      expect(result.startTime.minute, 42);
      expect(result.startTime.second, 30);
    });

    test('ignores timezone offset (components treated as wall-clock)', () {
      final parsed = makeParsedDive(
        year: 2024,
        month: 6,
        day: 15,
        hour: 14,
        minute: 42,
        second: 0,
        timezoneOffset: 3600, // UTC+1
      );
      final result = parsedDiveToDownloaded(parsed);

      // Components are used as-is regardless of timezone
      expect(result.startTime.isUtc, isTrue);
      expect(result.startTime.hour, 14);
      expect(result.startTime.minute, 42);
    });

    test('handles null timezone offset', () {
      final parsed = makeParsedDive(timezoneOffset: null);
      final result = parsedDiveToDownloaded(parsed);

      expect(result.startTime.isUtc, isTrue);
      expect(result.startTime.hour, 8);
    });

    // --- Basic field mapping ---

    test('converts basic ParsedDive to DownloadedDive', () {
      final parsed = makeParsedDive(
        fingerprint: 'abc123',
        year: 2023,
        month: 11,
        day: 14,
        hour: 22,
        minute: 13,
        second: 20,
        maxDepthMeters: 30.0,
        avgDepthMeters: 15.5,
        durationSeconds: 3600,
        minTemperatureCelsius: 18.0,
        maxTemperatureCelsius: 22.0,
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.fingerprint, 'abc123');
      expect(downloaded.maxDepth, 30.0);
      expect(downloaded.avgDepth, 15.5);
      expect(downloaded.durationSeconds, 3600);
      expect(downloaded.minTemperature, 18.0);
      expect(downloaded.maxTemperature, 22.0);
      expect(downloaded.startTime, DateTime.utc(2023, 11, 14, 22, 13, 20));
    });

    // --- Profile samples ---

    test('maps profile samples correctly', () {
      final parsed = makeParsedDive(
        fingerprint: 'def456',
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 10.0,
            temperatureCelsius: 20.0,
            pressureBar: 195.0,
            tankIndex: 0,
          ),
          pigeon.ProfileSample(
            timeSeconds: 120,
            depthMeters: 25.0,
            temperatureCelsius: 18.5,
            heartRate: 85,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.profile, hasLength(3));

      expect(downloaded.profile[0].timeSeconds, 0);
      expect(downloaded.profile[0].depth, 0.0);
      expect(downloaded.profile[0].temperature, isNull);

      expect(downloaded.profile[1].timeSeconds, 60);
      expect(downloaded.profile[1].depth, 10.0);
      expect(downloaded.profile[1].temperature, 20.0);
      expect(downloaded.profile[1].pressure, 195.0);
      expect(downloaded.profile[1].tankIndex, 0);

      expect(downloaded.profile[2].heartRate, 85);
    });

    test('maps per-cell O2 sensor ppO2 (absent cells stay null)', () {
      final parsed = makeParsedDive(
        fingerprint: 'cells1',
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 0,
            depthMeters: 0.0,
            ppo2: 0.7,
            o2Sensor1: 0.68,
            o2Sensor2: 0.70,
            o2Sensor3: 0.72,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final p = downloaded.profile.single;

      expect(p.ppo2, 0.7);
      expect(p.o2Sensor1, 0.68);
      expect(p.o2Sensor2, 0.70);
      expect(p.o2Sensor3, 0.72);
      expect(p.o2Sensor4, isNull);
      expect(p.o2Sensor5, isNull);
      expect(p.o2Sensor6, isNull);
    });

    // --- Tanks and gas mixes ---

    test('maps tanks with gas mixes correctly', () {
      final parsed = makeParsedDive(
        fingerprint: 'ghi789',
        maxDepthMeters: 40.0,
        avgDepthMeters: 20.0,
        durationSeconds: 3000,
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 200.0,
            endPressureBar: 50.0,
            volumeLiters: 12.0,
          ),
          pigeon.TankInfo(
            index: 1,
            gasMixIndex: 1,
            startPressureBar: 200.0,
            endPressureBar: 120.0,
          ),
        ],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks, hasLength(2));

      expect(downloaded.tanks[0].index, 0);
      expect(downloaded.tanks[0].o2Percent, 32.0);
      expect(downloaded.tanks[0].hePercent, 0.0);
      expect(downloaded.tanks[0].startPressure, 200.0);
      expect(downloaded.tanks[0].endPressure, 50.0);
      expect(downloaded.tanks[0].volumeLiters, 12.0);
      expect(downloaded.tanks[0].isNitrox, isTrue);

      expect(downloaded.tanks[1].index, 1);
      expect(downloaded.tanks[1].o2Percent, 50.0);
      expect(downloaded.tanks[1].gasName, 'EAN50');
    });

    test('unmatched gasMixIndex with no samples uses the primary mix and keeps '
        'the other gas as a pressureless cylinder', () {
      // Tank gas-mix link unknown (DC_GASMIX_UNKNOWN, e.g. Shearwater) and no
      // per-sample gas to disambiguate: the transmitter tank resolves to the
      // dive's primary mix (not a hardcoded air default that would mislabel an
      // EAN dive), and the second reported gas is still kept as a cylinder
      // instead of being dropped.
      final parsed = makeParsedDive(
        fingerprint: 'fallback-primary',
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 99)],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 21.0, hePercent: 0.0),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks, hasLength(2));
      // Transmitter tank keeps its index and the primary mix.
      expect(downloaded.tanks[0].index, 0);
      expect(downloaded.tanks[0].o2Percent, 32.0);
      expect(downloaded.tanks[0].hePercent, 0.0);
      // The second gas survives as a pressureless cylinder at a fresh index.
      final other = downloaded.tanks.firstWhere((t) => t.o2Percent == 21.0);
      expect(other.index, isNot(0));
      expect(other.startPressure, isNull);
    });

    test('falls back to air when there are no gas mixes at all', () {
      final parsed = makeParsedDive(
        fingerprint: 'fallback-air',
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 99)],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks, hasLength(1));
      expect(downloaded.tanks[0].o2Percent, 21.0);
      expect(downloaded.tanks[0].hePercent, 0.0);
      expect(downloaded.tanks[0].isAir, isTrue);
    });

    test('synthesizes one tank per gas mix when the computer reports no tanks '
        '(transmitter-less dives; e.g. Aqualung i330R)', () {
      // Tank records only exist when an air-integration transmitter
      // supplied pressure; whole families (Oceanic/Aqualung incl. the
      // i330R) never report DC_FIELD_TANK at all. The real mix lives in
      // gasMixes. A purely tank-driven mapping dropped it, so every
      // transmitter-less EAN dive fell back to the 21% air default.
      final parsed = makeParsedDive(
        fingerprint: 'i330r-nitrox',
        tanks: const [], // no transmitter: no tank records
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks, hasLength(2));
      // Tank index stays aligned with the gas-mix index so gas-switch
      // events (which reference gas indices) keep pointing at the right
      // tank.
      expect(downloaded.tanks[0].index, 0);
      expect(downloaded.tanks[0].o2Percent, 32.0);
      expect(downloaded.tanks[0].isNitrox, isTrue);
      expect(downloaded.tanks[1].index, 1);
      expect(downloaded.tanks[1].o2Percent, 50.0);
      expect(downloaded.tanks[1].gasName, 'EAN50');
      // No pressures/volume: the computer reported gases, not cylinders.
      expect(downloaded.tanks[0].startPressure, isNull);
      expect(downloaded.tanks[0].endPressure, isNull);
      expect(downloaded.tanks[0].volumeLiters, isNull);
    });

    test('synthesizes nothing when there are neither tanks nor gas mixes', () {
      // Gauge / freedive: no gas information at all -> no synthesized tank.
      final parsed = makeParsedDive(
        fingerprint: 'gauge-no-gas',
        tanks: const [],
        gasMixes: const [],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks, isEmpty);
    });

    test('handles trimix gas', () {
      final parsed = makeParsedDive(
        fingerprint: 'trimix',
        maxDepthMeters: 60.0,
        avgDepthMeters: 35.0,
        durationSeconds: 4800,
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 0)],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 18.0, hePercent: 45.0)],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.tanks[0].o2Percent, 18.0);
      expect(downloaded.tanks[0].hePercent, 45.0);
      expect(downloaded.tanks[0].isTrimix, isTrue);
      expect(downloaded.tanks[0].gasName, 'TMX 18/45');
    });

    // --- Optional fields ---

    test('handles null optional fields', () {
      final parsed = makeParsedDive(fingerprint: 'minimal');

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.minTemperature, isNull);
      expect(downloaded.maxTemperature, isNull);
      expect(downloaded.profile, isEmpty);
      expect(downloaded.tanks, isEmpty);
    });

    // --- Temperature derivation from samples ---

    test(
      'derives minTemperature from samples when top-level value is null',
      () {
        final parsed = makeParsedDive(
          fingerprint: 'temp-derive-min',
          minTemperatureCelsius: null,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 0,
              depthMeters: 0.0,
              temperatureCelsius: 22.0,
            ),
            pigeon.ProfileSample(
              timeSeconds: 60,
              depthMeters: 10.0,
              temperatureCelsius: 18.0,
            ),
            pigeon.ProfileSample(
              timeSeconds: 120,
              depthMeters: 5.0,
              temperatureCelsius: 20.0,
            ),
          ],
        );

        final downloaded = parsedDiveToDownloaded(parsed);

        expect(downloaded.minTemperature, 18.0);
      },
    );

    test(
      'derives maxTemperature from samples when top-level value is null',
      () {
        final parsed = makeParsedDive(
          fingerprint: 'temp-derive-max',
          maxTemperatureCelsius: null,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 0,
              depthMeters: 0.0,
              temperatureCelsius: 22.0,
            ),
            pigeon.ProfileSample(
              timeSeconds: 60,
              depthMeters: 10.0,
              temperatureCelsius: 18.0,
            ),
            pigeon.ProfileSample(
              timeSeconds: 120,
              depthMeters: 5.0,
              temperatureCelsius: 20.0,
            ),
          ],
        );

        final downloaded = parsedDiveToDownloaded(parsed);

        expect(downloaded.maxTemperature, 22.0);
      },
    );

    test('uses top-level temperature when provided, ignoring samples', () {
      final parsed = makeParsedDive(
        fingerprint: 'temp-top-level',
        minTemperatureCelsius: 15.0,
        maxTemperatureCelsius: 25.0,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 10.0,
            temperatureCelsius: 18.0,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.minTemperature, 15.0);
      expect(downloaded.maxTemperature, 25.0);
    });

    test(
      'returns null temperature when both top-level and samples lack temps',
      () {
        final parsed = makeParsedDive(
          fingerprint: 'temp-none',
          minTemperatureCelsius: null,
          maxTemperatureCelsius: null,
          samples: [pigeon.ProfileSample(timeSeconds: 60, depthMeters: 10.0)],
        );

        final downloaded = parsedDiveToDownloaded(parsed);

        expect(downloaded.minTemperature, isNull);
        expect(downloaded.maxTemperature, isNull);
      },
    );

    test('derives temperature from samples with mixed null/non-null temps', () {
      final parsed = makeParsedDive(
        fingerprint: 'temp-mixed',
        minTemperatureCelsius: null,
        maxTemperatureCelsius: null,
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 10.0,
            temperatureCelsius: 19.0,
          ),
          pigeon.ProfileSample(timeSeconds: 120, depthMeters: 15.0),
          pigeon.ProfileSample(
            timeSeconds: 180,
            depthMeters: 5.0,
            temperatureCelsius: 21.0,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      // Only non-null samples considered: 19.0 and 21.0
      expect(downloaded.minTemperature, 19.0);
      expect(downloaded.maxTemperature, 21.0);
    });

    test('maps all new sample fields when populated', () {
      final parsed = makeParsedDive(
        fingerprint: 'all-fields',
        maxDepthMeters: 40.0,
        avgDepthMeters: 25.0,
        durationSeconds: 3600,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 300,
            depthMeters: 35.0,
            temperatureCelsius: 16.0,
            pressureBar: 180.0,
            tankIndex: 0,
            heartRate: 92,
            setpoint: 1.3,
            ppo2: 1.28,
            cns: 15.5,
            rbt: 45,
            decoType: 2,
            decoTime: 180,
            decoDepth: 6.0,
            tts: 420,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.timeSeconds, 300);
      expect(sample.depth, 35.0);
      expect(sample.temperature, 16.0);
      expect(sample.pressure, 180.0);
      expect(sample.tankIndex, 0);
      expect(sample.heartRate, 92);
      expect(sample.setpoint, 1.3);
      expect(sample.ppo2, 1.28);
      expect(sample.cns, 15.5);
      expect(sample.rbt, 45);
      expect(sample.decoType, 2);
      expect(sample.decoTime, 180);
      expect(sample.decoDepth, 6.0);
      expect(sample.tts, 420);
    });

    test('maps null/missing new sample fields correctly', () {
      final parsed = makeParsedDive(
        fingerprint: 'null-fields',
        samples: [pigeon.ProfileSample(timeSeconds: 60, depthMeters: 15.0)],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.setpoint, isNull);
      expect(sample.ppo2, isNull);
      expect(sample.cns, isNull);
      expect(sample.rbt, isNull);
      expect(sample.decoType, isNull);
      expect(sample.decoTime, isNull);
      expect(sample.decoDepth, isNull);
      expect(sample.tts, isNull);
      expect(sample.ndl, isNull);
      expect(sample.ceiling, isNull);
    });

    // --- NDL / ceiling derivation ---

    test('derives NDL from decoTime when decoType is 0 (NDL mode)', () {
      final parsed = makeParsedDive(
        fingerprint: 'ndl-derive',
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 18.0,
            decoType: 0,
            decoTime: 720,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ndl, 720);
      expect(sample.ceiling, isNull);
    });

    test('derives ceiling from decoDepth when decoType is deco mode', () {
      final parsed = makeParsedDive(
        fingerprint: 'ceiling-derive',
        maxDepthMeters: 45.0,
        avgDepthMeters: 30.0,
        durationSeconds: 3600,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 300,
            depthMeters: 40.0,
            decoType: 2,
            decoTime: 180,
            decoDepth: 6.0,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ceiling, 6.0);
      expect(sample.ndl, isNull);
    });

    test('derives ceiling from decoDepth when decoType is safety stop (1)', () {
      final parsed = makeParsedDive(
        fingerprint: 'ceiling-safety',
        maxDepthMeters: 30.0,
        avgDepthMeters: 20.0,
        durationSeconds: 2400,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 300,
            depthMeters: 5.0,
            decoType: 1,
            decoTime: 180,
            decoDepth: 5.0,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ceiling, 5.0);
      expect(sample.ndl, isNull);
    });

    test('derives ceiling from decoDepth when decoType is deep stop (3)', () {
      final parsed = makeParsedDive(
        fingerprint: 'ceiling-deep',
        maxDepthMeters: 50.0,
        avgDepthMeters: 35.0,
        durationSeconds: 3600,
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 600,
            depthMeters: 30.0,
            decoType: 3,
            decoTime: 120,
            decoDepth: 18.0,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ceiling, 18.0);
      expect(sample.ndl, isNull);
    });

    test('does not derive ceiling for NDL mode (decoType 0)', () {
      final parsed = makeParsedDive(
        fingerprint: 'no-ceiling-ndl',
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 15.0,
            decoType: 0,
            decoTime: 900,
            decoDepth: 0.0,
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);
      final sample = downloaded.profile[0];

      expect(sample.ndl, 900);
      expect(sample.ceiling, isNull);
    });

    // --- Average depth fallback for unsupported computers ---

    test('maps avgDepthMeters of 0.0 to null avgDepth', () {
      // Computers like Cressi Leonardo don't report average depth;
      // libdivecomputer returns 0.0 from zero-initialized struct.
      final parsed = makeParsedDive(
        fingerprint: 'cressi-leonardo',
        maxDepthMeters: 18.0,
        avgDepthMeters: 0.0,
        durationSeconds: 2400,
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 600, depthMeters: 18.0),
          pigeon.ProfileSample(timeSeconds: 1200, depthMeters: 15.0),
          pigeon.ProfileSample(timeSeconds: 2400, depthMeters: 0.0),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      // 0.0 should be treated as "not reported", not a real value
      expect(downloaded.avgDepth, isNull);
    });

    test('preserves non-zero avgDepthMeters as-is', () {
      final parsed = makeParsedDive(
        fingerprint: 'shearwater-teric',
        maxDepthMeters: 30.0,
        avgDepthMeters: 18.5,
        durationSeconds: 3600,
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.avgDepth, 18.5);
    });

    // --- Deco model fields ---

    test('maps deco model fields correctly', () {
      final parsed = makeParsedDive(
        fingerprint: 'deco-model',
        maxDepthMeters: 50.0,
        avgDepthMeters: 30.0,
        durationSeconds: 3600,
        decoAlgorithm: 'buhlmann',
        gfLow: 30,
        gfHigh: 70,
        decoConservatism: 2,
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.decoAlgorithm, 'buhlmann');
      expect(downloaded.gfLow, 30);
      expect(downloaded.gfHigh, 70);
      expect(downloaded.decoConservatism, 2);
    });

    test('maps null deco model fields correctly', () {
      final parsed = makeParsedDive(fingerprint: 'no-deco-model');

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.decoAlgorithm, isNull);
      expect(downloaded.gfLow, isNull);
      expect(downloaded.gfHigh, isNull);
      expect(downloaded.decoConservatism, isNull);
    });

    // --- Events ---

    test('maps events with flags and value from data map', () {
      final parsed = makeParsedDive(
        fingerprint: 'events-test',
        maxDepthMeters: 30.0,
        avgDepthMeters: 20.0,
        durationSeconds: 2400,
        events: [
          pigeon.DiveEvent(
            timeSeconds: 120,
            type: 'gaschange',
            data: {'flags': '1', 'value': '32'},
          ),
          pigeon.DiveEvent(
            timeSeconds: 600,
            type: 'deco',
            data: {'flags': '0', 'value': '180'},
          ),
        ],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.events, hasLength(2));

      expect(downloaded.events[0].timeSeconds, 120);
      expect(downloaded.events[0].type, 'gaschange');
      expect(downloaded.events[0].flags, 1);
      expect(downloaded.events[0].value, 32);

      expect(downloaded.events[1].timeSeconds, 600);
      expect(downloaded.events[1].type, 'deco');
      expect(downloaded.events[1].flags, 0);
      expect(downloaded.events[1].value, 180);
    });

    test('maps events with null data map', () {
      final parsed = makeParsedDive(
        fingerprint: 'events-null-data',
        maxDepthMeters: 30.0,
        avgDepthMeters: 20.0,
        durationSeconds: 2400,
        events: [pigeon.DiveEvent(timeSeconds: 300, type: 'heading')],
      );

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.events, hasLength(1));
      expect(downloaded.events[0].timeSeconds, 300);
      expect(downloaded.events[0].type, 'heading');
      expect(downloaded.events[0].flags, isNull);
      expect(downloaded.events[0].value, isNull);
    });

    test('maps empty events list to empty DownloadedEvent list', () {
      final parsed = makeParsedDive(fingerprint: 'no-events');

      final downloaded = parsedDiveToDownloaded(parsed);

      expect(downloaded.events, isEmpty);
    });

    // --- GPS entry/exit (Shearwater Swift) ---

    test('copies entry and exit coordinates', () {
      final d = parsedDiveToDownloaded(
        makeParsedDive(
          entryLatitude: 12.34567,
          entryLongitude: 98.76543,
          exitLatitude: 12.34612,
          exitLongitude: 98.76489,
        ),
      );
      expect(d.entryLatitude, 12.34567);
      expect(d.entryLongitude, 98.76543);
      expect(d.exitLatitude, 12.34612);
      expect(d.exitLongitude, 98.76489);
    });

    test('GPS null when absent', () {
      final d = parsedDiveToDownloaded(makeParsedDive());
      expect(d.entryLatitude, isNull);
      expect(d.exitLatitude, isNull);
    });

    test('rejects sentinel (0,0) and (-1,-1) GPS coordinates', () {
      final zero = parsedDiveToDownloaded(
        makeParsedDive(entryLatitude: 0.0, entryLongitude: 0.0),
      );
      expect(zero.entryLatitude, isNull);
      expect(zero.entryLongitude, isNull);
      final neg = parsedDiveToDownloaded(
        makeParsedDive(exitLatitude: -1.0, exitLongitude: -1.0),
      );
      expect(neg.exitLatitude, isNull);
      expect(neg.exitLongitude, isNull);
    });
  });
}
