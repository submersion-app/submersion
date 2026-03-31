import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_pipeline.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Build an [ImportConfiguration] from a detected preset, mirroring what the
/// Configure stage would produce.
ImportConfiguration _configFromPreset(CsvPreset preset) {
  return ImportConfiguration(
    mappings: preset.mappings,
    entityTypesToImport: preset.supportedEntities,
    sourceApp: preset.sourceApp,
    preset: preset,
  );
}

void main() {
  late CsvPipeline pipeline;

  setUp(() {
    pipeline = CsvPipeline();
  });

  group('Subsurface CSV integration', () {
    late File diveListFile;
    late File profileFile;

    setUpAll(() {
      diveListFile = File('test/fixtures/subsurface-dive_list.csv');
      profileFile = File(
        'test/fixtures/subsurface-dive_computer_dive_profile.csv',
      );
      expect(diveListFile.existsSync(), isTrue);
      expect(profileFile.existsSync(), isTrue);
    });

    test('detects Subsurface from real dive list CSV', () {
      final bytes = diveListFile.readAsBytesSync();
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);

      expect(detected.isDetected, isTrue);
      expect(detected.sourceApp, equals(SourceApp.subsurface));
      expect(detected.confidence, greaterThan(0.5));
    });

    test('parses all dives from dive list (at least 20 valid)', () {
      final bytes = diveListFile.readAsBytesSync();
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);

      expect(detected.matchedPreset, isNotNull);

      final config = _configFromPreset(detected.matchedPreset!);
      final payload = pipeline.execute(primaryCsv: parsed, config: config);

      final dives = payload.entitiesOf(ImportEntityType.dives);
      // The real file has 24 data rows including dives without numbers.
      expect(dives.length, greaterThanOrEqualTo(20));

      // Every dive should have a non-null unique ID.
      final ids = dives.map((d) => d['id'] as String?).toList();
      expect(ids, everyElement(isNotNull));
      expect(ids.toSet().length, equals(ids.length));
    });

    test('extracts multi-tank data (some dives should have 2 tanks)', () {
      final bytes = diveListFile.readAsBytesSync();
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);
      final config = _configFromPreset(detected.matchedPreset!);
      final payload = pipeline.execute(primaryCsv: parsed, config: config);

      final dives = payload.entitiesOf(ImportEntityType.dives);

      // Rows 20-23 in the CSV (2025-12-26 second dive and 2025-12-27 dives)
      // have cylinder size (2) populated, so at least one dive should carry
      // two tanks.
      final multiTankDives = dives.where((d) {
        final tanks = d['tanks'] as List<dynamic>?;
        return tanks != null && tanks.length >= 2;
      }).toList();

      expect(
        multiTankDives,
        isNotEmpty,
        reason: 'At least some dives should have 2 tanks',
      );
    });

    test('extracts unique sites with GPS coordinates', () {
      final bytes = diveListFile.readAsBytesSync();
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);
      final config = _configFromPreset(detected.matchedPreset!);
      final payload = pipeline.execute(primaryCsv: parsed, config: config);

      final sites = payload.entitiesOf(ImportEntityType.sites);
      // Known named sites: Maclearie Park, The Atlantic Club Pool,
      // Escambron Marine Park, Mosquito Pier.
      expect(sites.length, greaterThanOrEqualTo(4));

      // Maclearie Park has GPS coordinates.
      final maclearie = sites.firstWhere(
        (s) => (s['name'] as String?)?.contains('Maclearie') ?? false,
        orElse: () => {},
      );
      expect(maclearie, isNotEmpty);
      expect(maclearie['latitude'], isNotNull);
      expect(maclearie['longitude'], isNotNull);

      final lat = (maclearie['latitude'] as num).toDouble();
      final lon = (maclearie['longitude'] as num).toDouble();
      expect(lat, closeTo(40.179575, 0.001));
      expect(lon, closeTo(-74.037466, 0.001));
    });

    test('extracts buddies with leading-comma handling '
        '(Kiyan Griffin appears, no empty buddy entries)', () {
      final bytes = diveListFile.readAsBytesSync();
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);
      final config = _configFromPreset(detected.matchedPreset!);
      final payload = pipeline.execute(primaryCsv: parsed, config: config);

      final buddies = payload.entitiesOf(ImportEntityType.buddies);
      final names = buddies.map((b) => b['name'] as String?).toList();

      // No empty or whitespace-only buddy names.
      expect(names, everyElement(isNotNull));
      for (final name in names) {
        expect(name!.trim(), isNotEmpty);
      }

      // Subsurface exports buddy as ", Kiyan Griffin" — the extractor must
      // strip the leading comma so the name resolves cleanly.
      expect(names, contains('Kiyan Griffin'));

      // Only the 'buddy' column is extracted; 'divemaster' is a separate field.
      // In this fixture, Kiyan Griffin is the only person in the buddy column.
      expect(buddies, hasLength(1));
    });

    test('extracts tags (shore, student)', () {
      final bytes = diveListFile.readAsBytesSync();
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);
      final config = _configFromPreset(detected.matchedPreset!);
      final payload = pipeline.execute(primaryCsv: parsed, config: config);

      final tags = payload.entitiesOf(ImportEntityType.tags);
      final tagNames = tags.map((t) => t['name'] as String?).toList();

      expect(tagNames, contains('shore'));
      expect(tagNames, contains('student'));
    });

    test('all dive times are UTC wall-clock and not shifted '
        '(first numbered dive at 07:44 remains 07:44)', () {
      final bytes = diveListFile.readAsBytesSync();
      final parsed = pipeline.parse(bytes);
      final detected = pipeline.detect(parsed);
      final config = _configFromPreset(detected.matchedPreset!);
      final payload = pipeline.execute(primaryCsv: parsed, config: config);

      final dives = payload.entitiesOf(ImportEntityType.dives);

      // Dive #1 (2025-09-20 07:44:37) should be stored as-is — no timezone
      // conversion should shift the hour.
      final dive1 = dives.firstWhere(
        (d) => d['diveNumber'] != null && d['diveNumber'].toString() == '1',
        orElse: () => {},
      );
      expect(dive1, isNotEmpty, reason: 'Dive number 1 should be present');

      final dt = dive1['dateTime'] as DateTime?;
      expect(dt, isNotNull);
      expect(dt!.hour, equals(7));
      expect(dt.minute, equals(44));
    });

    test('full pipeline with profile CSV correlates profiles to dives', () {
      final diveListBytes = diveListFile.readAsBytesSync();
      final profileBytes = profileFile.readAsBytesSync();

      final parsedList = pipeline.parse(diveListBytes);
      final parsedProfile = pipeline.parse(profileBytes);

      final detected = pipeline.detect(parsedList);
      expect(detected.matchedPreset, isNotNull);

      final config = _configFromPreset(detected.matchedPreset!);

      final payload = pipeline.execute(
        primaryCsv: parsedList,
        profileCsv: parsedProfile,
        config: config,
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives.length, greaterThanOrEqualTo(20));

      // After the correlation fix, profile samples should actually be
      // attached to dives. At least some dives must have profile data.
      final divesWithProfiles = dives
          .where((d) => d['profile'] != null)
          .toList();
      expect(
        divesWithProfiles,
        isNotEmpty,
        reason:
            'At least some dives should have profile samples after correlation',
      );

      // Each matched dive's profile should be a non-empty list of
      // sample maps containing timestamp and depth.
      for (final dive in divesWithProfiles) {
        final samples = dive['profile'] as List;
        expect(samples, isNotEmpty);
        final first = samples.first as Map<String, dynamic>;
        expect(first.containsKey('timestamp'), isTrue);
        expect(first.containsKey('depth'), isTrue);
      }
    });
  });
}
