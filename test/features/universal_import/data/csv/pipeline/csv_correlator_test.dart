import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/transformed_rows.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_correlator.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  const correlator = CsvCorrelator();

  /// Helper: build a minimal [ImportConfiguration] with default entity types.
  ImportConfiguration makeConfig({
    Set<ImportEntityType> entityTypes = const {
      ImportEntityType.dives,
      ImportEntityType.sites,
    },
    SourceApp? sourceApp,
  }) {
    return ImportConfiguration(
      mappings: {'primary': const FieldMapping(name: 'Test', columns: [])},
      entityTypesToImport: entityTypes,
      sourceApp: sourceApp,
    );
  }

  /// Helper: build a [TransformedRows] with one row per entry.
  TransformedRows makeRows(List<Map<String, dynamic>> rows) {
    return TransformedRows(rows: rows);
  }

  group('CsvCorrelator', () {
    test('extracts dives with generated IDs', () {
      final rows = makeRows([
        {
          'dateTime': DateTime(2024, 6, 15, 9, 0),
          'maxDepth': 25.0,
          'duration': const Duration(minutes: 45),
        },
        {
          'dateTime': DateTime(2024, 6, 16, 10, 0),
          'maxDepth': 30.0,
          'duration': const Duration(minutes: 50),
        },
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(2));

      final id0 = dives[0]['id'] as String?;
      final id1 = dives[1]['id'] as String?;
      expect(id0, isNotNull);
      expect(id1, isNotNull);
      expect(id0, isNot(equals(id1)));
    });

    test('extracts and links tanks to dives', () {
      final rows = makeRows([
        {
          'dateTime': DateTime(2024, 6, 15, 9, 0),
          'maxDepth': 25.0,
          'tankVolume_1': 12.0,
          'startPressure_1': 200.0,
          'endPressure_1': 50.0,
          'o2Percent_1': 32.0,
          'hePercent_1': 0.0,
        },
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(1));

      final dive = dives[0];
      final tanks = dive['tanks'] as List?;
      expect(tanks, isNotNull);
      expect(tanks, hasLength(1));

      final tank = (tanks as List)[0] as Map<String, dynamic>;
      expect(tank['diveId'], equals(dive['id']));
      expect(tank['volume'], equals(12.0));
      expect(tank['o2Percent'], equals(32.0));
    });

    test('extracts and deduplicates sites', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'siteName': 'Blue Hole'},
        {'dateTime': DateTime(2024, 6, 16, 10, 0), 'siteName': 'Blue Hole'},
        {'dateTime': DateTime(2024, 6, 17, 8, 0), 'siteName': 'The Wall'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(2));

      final names = sites.map((s) => s['name']).toList();
      expect(names, containsAll(['Blue Hole', 'The Wall']));
    });

    test('normalizes site alias so "site" field is treated as siteName', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'site': 'Blue Hole'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(),
      );

      final sites = result.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      expect(sites[0]['name'], equals('Blue Hole'));
    });

    test('links dives to sites via siteId', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'siteName': 'Blue Hole'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      final sites = result.entitiesOf(ImportEntityType.sites);

      expect(dives, hasLength(1));
      expect(sites, hasLength(1));

      final diveId = dives[0]['siteId'] as String?;
      final siteId = sites[0]['id'] as String?;
      expect(diveId, isNotNull);
      expect(diveId, equals(siteId));
    });

    test('extracts buddies when in entityTypesToImport', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'buddy': 'Alice, Bob'},
        {'dateTime': DateTime(2024, 6, 16, 10, 0), 'buddy': 'Alice'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(
          entityTypes: {
            ImportEntityType.dives,
            ImportEntityType.sites,
            ImportEntityType.buddies,
          },
        ),
      );

      final buddies = result.entitiesOf(ImportEntityType.buddies);
      expect(buddies, hasLength(2));
      final names = buddies.map((b) => b['name']).toList();
      expect(names, containsAll(['Alice', 'Bob']));
    });

    test('skips buddies when not in entityTypesToImport', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'buddy': 'Alice'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(
          entityTypes: {ImportEntityType.dives, ImportEntityType.sites},
        ),
      );

      final buddies = result.entitiesOf(ImportEntityType.buddies);
      expect(buddies, isEmpty);
    });

    test('attaches profile data to matching dives', () {
      // Profile rows must match the dive key: "diveNumber|date|time"
      // Profile rows have sampleTime for ProfileExtractor to pick them up.
      final diveRows = makeRows([
        {
          'diveNumber': 1,
          'dateTime': DateTime(2024, 6, 15, 9, 0),
          'maxDepth': 25.0,
        },
      ]);

      // Profile rows use ProfileExtractor key: diveNumber|date|time
      // They need 'sampleTime', 'date', 'time', and 'diveNumber'.
      const profileRows = TransformedRows(
        rows: [
          {
            'diveNumber': 1,
            'date': '2024-06-15',
            'time': '09:00',
            'sampleTime': '0:30',
            'sampleDepth': 5.0,
          },
          {
            'diveNumber': 1,
            'date': '2024-06-15',
            'time': '09:00',
            'sampleTime': '1:00',
            'sampleDepth': 10.0,
          },
        ],
        fileRole: 'dive_profile',
      );

      final result = correlator.correlate(
        diveListRows: diveRows,
        profileRows: profileRows,
        config: makeConfig(),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(1));

      // The dive key from the correlator is built from diveNumber + dateTime.
      // For the test dive with dateTime 2024-06-15 09:00, the key is
      // "1|2024-06-15|09:00" which should match profile rows using
      // "1|2024-06-15|09:00".
      final profile = dives[0]['profile'] as List?;
      expect(profile, isNotNull);
      expect(profile, hasLength(2));
    });

    test('builds metadata with sourceApp and row counts', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'maxDepth': 20.0},
        {'dateTime': DateTime(2024, 6, 16, 10, 0), 'maxDepth': 25.0},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(sourceApp: SourceApp.subsurface),
      );

      expect(result.metadata['sourceApp'], equals('subsurface'));
      expect(result.metadata['totalRows'], equals(2));
      expect(result.metadata['parsedDives'], equals(2));
    });

    test('normalizes divemaster alias to diveMaster', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'divemaster': 'John'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(),
      );

      final dives = result.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(1));
      // The divemaster alias should be normalized to diveMaster.
      expect(dives[0].containsKey('diveMaster'), isTrue);
      expect(dives[0]['diveMaster'], equals('John'));
    });

    test('extracts tags when in entityTypesToImport', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'tags': 'reef, training'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(
          entityTypes: {ImportEntityType.dives, ImportEntityType.tags},
        ),
      );

      final tags = result.entitiesOf(ImportEntityType.tags);
      expect(tags, isNotEmpty);
    });

    test('extracts gear when in entityTypesToImport', () {
      final rows = makeRows([
        {'dateTime': DateTime(2024, 6, 15, 9, 0), 'suit': '7mm Wetsuit'},
      ]);

      final result = correlator.correlate(
        diveListRows: rows,
        config: makeConfig(
          entityTypes: {ImportEntityType.dives, ImportEntityType.equipment},
        ),
      );

      final gear = result.entitiesOf(ImportEntityType.equipment);
      expect(gear, isNotEmpty);
      expect(gear[0]['name'], equals('7mm Wetsuit'));
    });

    group('_attachBuddyRefs', () {
      test('converts buddy field to buddyRefs with IDs', () {
        final rows = makeRows([
          {'dateTime': DateTime(2024, 6, 15, 9, 0), 'buddy': 'Alice, Bob'},
        ]);

        final result = correlator.correlate(
          diveListRows: rows,
          config: makeConfig(
            entityTypes: {
              ImportEntityType.dives,
              ImportEntityType.sites,
              ImportEntityType.buddies,
            },
          ),
        );

        final dives = result.entitiesOf(ImportEntityType.dives);
        final buddies = result.entitiesOf(ImportEntityType.buddies);
        expect(dives, hasLength(1));
        expect(buddies, hasLength(2));

        // Dive should have buddyRefs (list of IDs) instead of raw buddy string.
        final dive = dives[0];
        expect(dive.containsKey('buddyRefs'), isTrue);
        expect(dive.containsKey('buddy'), isFalse);

        final refs = dive['buddyRefs'] as List;
        expect(refs, hasLength(2));

        // Each ref should match a buddy entity ID.
        final buddyIds = buddies.map((b) => b['id']).toSet();
        for (final ref in refs) {
          expect(buddyIds, contains(ref));
        }
      });

      test('converts diveMaster field to unmatchedDiveGuideNames', () {
        final rows = makeRows([
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'diveMaster': 'Captain Jack',
          },
        ]);

        final result = correlator.correlate(
          diveListRows: rows,
          config: makeConfig(
            entityTypes: {
              ImportEntityType.dives,
              ImportEntityType.sites,
              ImportEntityType.buddies,
            },
          ),
        );

        final dives = result.entitiesOf(ImportEntityType.dives);
        expect(dives, hasLength(1));

        final dive = dives[0];
        expect(dive.containsKey('unmatchedDiveGuideNames'), isTrue);
        expect(dive.containsKey('diveMaster'), isFalse);

        final names = dive['unmatchedDiveGuideNames'] as List;
        expect(names, hasLength(1));
        expect(names[0], 'Captain Jack');
      });

      test('handles dive with both buddy and diveMaster', () {
        final rows = makeRows([
          {
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'buddy': 'Alice',
            'diveMaster': 'Bob',
          },
        ]);

        final result = correlator.correlate(
          diveListRows: rows,
          config: makeConfig(
            entityTypes: {
              ImportEntityType.dives,
              ImportEntityType.sites,
              ImportEntityType.buddies,
            },
          ),
        );

        final dives = result.entitiesOf(ImportEntityType.dives);
        expect(dives, hasLength(1));

        final dive = dives[0];
        expect(dive.containsKey('buddyRefs'), isTrue);
        expect(dive.containsKey('unmatchedDiveGuideNames'), isTrue);

        final refs = dive['buddyRefs'] as List;
        expect(refs, hasLength(1));

        final dmNames = dive['unmatchedDiveGuideNames'] as List;
        expect(dmNames, hasLength(1));
        expect(dmNames[0], 'Bob');
      });

      test('does not attach buddyRefs when buddies not in entityTypes', () {
        final rows = makeRows([
          {'dateTime': DateTime(2024, 6, 15, 9, 0), 'buddy': 'Alice'},
        ]);

        final result = correlator.correlate(
          diveListRows: rows,
          config: makeConfig(
            entityTypes: {ImportEntityType.dives, ImportEntityType.sites},
          ),
        );

        final dives = result.entitiesOf(ImportEntityType.dives);
        expect(dives, hasLength(1));

        // Without buddies in entityTypes, raw buddy string should remain.
        final dive = dives[0];
        expect(dive.containsKey('buddyRefs'), isFalse);
        expect(dive['buddy'], equals('Alice'));
      });

      test('handles comma-separated diveMaster names', () {
        final rows = makeRows([
          {'dateTime': DateTime(2024, 6, 15, 9, 0), 'diveMaster': 'Jack, Jill'},
        ]);

        final result = correlator.correlate(
          diveListRows: rows,
          config: makeConfig(
            entityTypes: {
              ImportEntityType.dives,
              ImportEntityType.sites,
              ImportEntityType.buddies,
            },
          ),
        );

        final dives = result.entitiesOf(ImportEntityType.dives);
        final dive = dives[0];
        final names = dive['unmatchedDiveGuideNames'] as List;
        expect(names, hasLength(2));
        expect(names, containsAll(['Jack', 'Jill']));
      });
    });

    group('_diveKey seconds normalization', () {
      test('profile matches dive with DateTime including seconds', () {
        // Dive with DateTime that has seconds (09:00:37).
        final diveRows = makeRows([
          {
            'diveNumber': 1,
            'dateTime': DateTime(2024, 6, 15, 9, 0, 37),
            'maxDepth': 25.0,
          },
        ]);

        // Profile rows whose time key must include seconds to match.
        const profileRows = TransformedRows(
          rows: [
            {
              'diveNumber': 1,
              'date': '2024-06-15',
              'time': '09:00:37',
              'sampleTime': '0:30',
              'sampleDepth': 5.0,
            },
          ],
          fileRole: 'dive_profile',
        );

        final result = correlator.correlate(
          diveListRows: diveRows,
          profileRows: profileRows,
          config: makeConfig(),
        );

        final dives = result.entitiesOf(ImportEntityType.dives);
        expect(dives, hasLength(1));
        final profile = dives[0]['profile'] as List?;
        expect(profile, isNotNull);
        expect(profile, hasLength(1));
      });

      test(
        '_diveKey normalizes HH:MM to HH:MM:00 for profile string times',
        () {
          // Dive has a DateTime (which generates HH:MM:SS with :00 seconds).
          final diveRows = makeRows([
            {
              'diveNumber': 1,
              'dateTime': DateTime(2024, 6, 15, 9, 0),
              'maxDepth': 25.0,
            },
          ]);

          // Profile rows use "09:00" (HH:MM) - should be normalized to
          // "09:00:00" to match the DateTime-based dive key.
          const profileRows = TransformedRows(
            rows: [
              {
                'diveNumber': 1,
                'date': '2024-06-15',
                'time': '09:00',
                'sampleTime': '1:00',
                'sampleDepth': 10.0,
              },
            ],
            fileRole: 'dive_profile',
          );

          final result = correlator.correlate(
            diveListRows: diveRows,
            profileRows: profileRows,
            config: makeConfig(),
          );

          final dives = result.entitiesOf(ImportEntityType.dives);
          expect(dives, hasLength(1));
          final profile = dives[0]['profile'] as List?;
          expect(profile, isNotNull);
          expect(profile, hasLength(1));
        },
      );

      test('profile does not match when dive key differs', () {
        final diveRows = makeRows([
          {
            'diveNumber': 1,
            'dateTime': DateTime(2024, 6, 15, 9, 0),
            'maxDepth': 25.0,
          },
        ]);

        // Profile row with different date should not match.
        const profileRows = TransformedRows(
          rows: [
            {
              'diveNumber': 1,
              'date': '2024-06-16',
              'time': '09:00',
              'sampleTime': '1:00',
              'sampleDepth': 10.0,
            },
          ],
          fileRole: 'dive_profile',
        );

        final result = correlator.correlate(
          diveListRows: diveRows,
          profileRows: profileRows,
          config: makeConfig(),
        );

        final dives = result.entitiesOf(ImportEntityType.dives);
        expect(dives, hasLength(1));
        final profile = dives[0]['profile'];
        expect(profile, isNull);
      });
    });
  });
}
