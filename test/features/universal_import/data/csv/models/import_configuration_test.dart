import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  group('TimeInterpretation', () {
    test('has three values', () {
      expect(TimeInterpretation.values, hasLength(3));
    });

    test('contains localWallClock, utc, and specificOffset', () {
      expect(
        TimeInterpretation.values,
        containsAll([
          TimeInterpretation.localWallClock,
          TimeInterpretation.utc,
          TimeInterpretation.specificOffset,
        ]),
      );
    });
  });

  group('ImportConfiguration', () {
    const diveListMapping = FieldMapping(
      name: 'Dive List',
      columns: [
        ColumnMapping(sourceColumn: 'date', targetField: 'diveDateTime'),
        ColumnMapping(sourceColumn: 'depth', targetField: 'maxDepth'),
      ],
    );

    const profileMapping = FieldMapping(
      name: 'Profile',
      columns: [
        ColumnMapping(sourceColumn: 'time', targetField: 'elapsedSeconds'),
        ColumnMapping(sourceColumn: 'depth', targetField: 'depthMeters'),
      ],
    );

    group('constructor', () {
      test('constructs with all parameters', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          timeInterpretation: TimeInterpretation.utc,
          specificUtcOffset: Duration(hours: -5),
          entityTypesToImport: {ImportEntityType.dives},
          sourceApp: SourceApp.subsurface,
        );

        expect(config.mappings, {'primary': diveListMapping});
        expect(config.timeInterpretation, TimeInterpretation.utc);
        expect(config.specificUtcOffset, const Duration(hours: -5));
        expect(config.entityTypesToImport, {ImportEntityType.dives});
        expect(config.sourceApp, SourceApp.subsurface);
      });

      test('requires mappings parameter', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
        );

        expect(config.mappings, isNotEmpty);
      });
    });

    group('default values', () {
      test('timeInterpretation defaults to localWallClock', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
        );

        expect(config.timeInterpretation, TimeInterpretation.localWallClock);
      });

      test('specificUtcOffset defaults to null', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
        );

        expect(config.specificUtcOffset, isNull);
      });

      test('entityTypesToImport defaults to dives and sites', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
        );

        expect(config.entityTypesToImport, {
          ImportEntityType.dives,
          ImportEntityType.sites,
        });
      });

      test('preset defaults to null', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
        );

        expect(config.preset, isNull);
      });

      test('sourceApp defaults to null', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
        );

        expect(config.sourceApp, isNull);
      });
    });

    group('primaryMapping', () {
      test('returns mapping with key "primary"', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping, 'profile': profileMapping},
        );

        expect(config.primaryMapping, diveListMapping);
      });

      test('returns first mapping when no "primary" key exists', () {
        const config = ImportConfiguration(
          mappings: {'dive_list': diveListMapping, 'profile': profileMapping},
        );

        expect(config.primaryMapping, diveListMapping);
      });

      test('returns null when mappings is empty', () {
        const config = ImportConfiguration(mappings: {});

        expect(config.primaryMapping, isNull);
      });

      test('prefers "primary" key over first entry', () {
        const config = ImportConfiguration(
          mappings: {'dive_list': diveListMapping, 'primary': profileMapping},
        );

        expect(config.primaryMapping, profileMapping);
      });
    });

    group('Equatable', () {
      test('equal objects are equal', () {
        const a = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          timeInterpretation: TimeInterpretation.utc,
          entityTypesToImport: {ImportEntityType.dives},
          sourceApp: SourceApp.macdive,
        );
        const b = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          timeInterpretation: TimeInterpretation.utc,
          entityTypesToImport: {ImportEntityType.dives},
          sourceApp: SourceApp.macdive,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different mappings produces inequality', () {
        const a = ImportConfiguration(mappings: {'primary': diveListMapping});
        const b = ImportConfiguration(mappings: {'primary': profileMapping});

        expect(a, isNot(equals(b)));
      });

      test('different timeInterpretation produces inequality', () {
        const a = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          timeInterpretation: TimeInterpretation.utc,
        );
        const b = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          timeInterpretation: TimeInterpretation.localWallClock,
        );

        expect(a, isNot(equals(b)));
      });

      test('different entityTypesToImport produces inequality', () {
        const a = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          entityTypesToImport: {ImportEntityType.dives},
        );
        const b = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          entityTypesToImport: {ImportEntityType.sites},
        );

        expect(a, isNot(equals(b)));
      });

      test('different sourceApp produces inequality', () {
        const a = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          sourceApp: SourceApp.macdive,
        );
        const b = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          sourceApp: SourceApp.subsurface,
        );

        expect(a, isNot(equals(b)));
      });

      test('different specificUtcOffset produces inequality', () {
        const a = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          timeInterpretation: TimeInterpretation.specificOffset,
          specificUtcOffset: Duration(hours: -5),
        );
        const b = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          timeInterpretation: TimeInterpretation.specificOffset,
          specificUtcOffset: Duration(hours: 3),
        );

        expect(a, isNot(equals(b)));
      });

      test('props includes all fields', () {
        const config = ImportConfiguration(
          mappings: {'primary': diveListMapping},
          sourceApp: SourceApp.macdive,
        );

        expect(config.props, hasLength(6));
      });
    });
  });
}
