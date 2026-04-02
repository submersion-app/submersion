import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  group('DiveDuplicateResolution', () {
    test('has three values', () {
      expect(DiveDuplicateResolution.values, hasLength(3));
    });

    test('skip displayName', () {
      expect(DiveDuplicateResolution.skip.displayName, 'Skip');
    });

    test('importAsNew displayName', () {
      expect(DiveDuplicateResolution.importAsNew.displayName, 'Import as New');
    });

    test('consolidate displayName', () {
      expect(
        DiveDuplicateResolution.consolidate.displayName,
        'Consolidate as additional computer',
      );
    });
  });

  group('ImportFormat', () {
    test('has all expected values', () {
      expect(ImportFormat.values, hasLength(12));
    });

    test('displayName for each format', () {
      expect(ImportFormat.csv.displayName, 'CSV');
      expect(ImportFormat.uddf.displayName, 'UDDF');
      expect(ImportFormat.subsurfaceXml.displayName, 'Subsurface XML');
      expect(ImportFormat.divingLogXml.displayName, 'Diving Log XML');
      expect(ImportFormat.suuntoSml.displayName, 'Suunto SML');
      expect(ImportFormat.suuntoDm5.displayName, 'Suunto DM5');
      expect(ImportFormat.fit.displayName, 'Garmin FIT');
      expect(ImportFormat.shearwaterDb.displayName, 'Shearwater Cloud');
      expect(ImportFormat.scubapro.displayName, 'Scubapro');
      expect(ImportFormat.danDl7.displayName, 'DAN DL7');
      expect(ImportFormat.sqlite.displayName, 'SQLite Database');
      expect(ImportFormat.unknown.displayName, 'Unknown');
    });

    test(
      'isSupported returns true for csv, uddf, subsurfaceXml, fit, shearwaterDb',
      () {
        expect(ImportFormat.csv.isSupported, isTrue);
        expect(ImportFormat.uddf.isSupported, isTrue);
        expect(ImportFormat.subsurfaceXml.isSupported, isTrue);
        expect(ImportFormat.fit.isSupported, isTrue);
        expect(ImportFormat.shearwaterDb.isSupported, isTrue);
      },
    );

    test('isSupported returns false for unsupported formats', () {
      expect(ImportFormat.divingLogXml.isSupported, isFalse);
      expect(ImportFormat.suuntoSml.isSupported, isFalse);
      expect(ImportFormat.suuntoDm5.isSupported, isFalse);
      expect(ImportFormat.scubapro.isSupported, isFalse);
      expect(ImportFormat.danDl7.isSupported, isFalse);
      expect(ImportFormat.sqlite.isSupported, isFalse);
      expect(ImportFormat.unknown.isSupported, isFalse);
    });
  });

  group('SourceApp', () {
    test('has all expected values', () {
      expect(SourceApp.values, hasLength(12));
    });

    test('displayName for each source app', () {
      expect(SourceApp.submersion.displayName, 'Submersion');
      expect(SourceApp.subsurface.displayName, 'Subsurface');
      expect(SourceApp.macdive.displayName, 'MacDive');
      expect(SourceApp.divingLog.displayName, 'Diving Log');
      expect(SourceApp.diveMate.displayName, 'DiveMate');
      expect(SourceApp.shearwater.displayName, 'Shearwater');
      expect(SourceApp.suunto.displayName, 'Suunto');
      expect(SourceApp.garminConnect.displayName, 'Garmin Connect');
      expect(SourceApp.scubapro.displayName, 'Scubapro');
      expect(SourceApp.ssiMyDiveGuide.displayName, 'SSI MyDiveGuide');
      expect(SourceApp.dan.displayName, 'DAN');
      expect(SourceApp.generic.displayName, 'Unknown App');
    });

    test('exportInstructions is non-null for known apps', () {
      expect(SourceApp.suunto.exportInstructions, isNotNull);
      expect(SourceApp.scubapro.exportInstructions, isNotNull);
      expect(SourceApp.ssiMyDiveGuide.exportInstructions, isNotNull);
      expect(SourceApp.dan.exportInstructions, isNotNull);
    });

    test('exportInstructions contains expected guidance text', () {
      expect(SourceApp.suunto.exportInstructions, contains('UDDF'));
      expect(SourceApp.scubapro.exportInstructions, contains('UDDF'));
      expect(SourceApp.ssiMyDiveGuide.exportInstructions, contains('CSV'));
      expect(SourceApp.dan.exportInstructions, contains('DL7'));
    });

    test('exportInstructions is null for apps without instructions', () {
      // shearwater now uses native .db import, so no export instructions needed
      expect(SourceApp.shearwater.exportInstructions, isNull);
      expect(SourceApp.submersion.exportInstructions, isNull);
      expect(SourceApp.subsurface.exportInstructions, isNull);
      expect(SourceApp.macdive.exportInstructions, isNull);
      expect(SourceApp.divingLog.exportInstructions, isNull);
      expect(SourceApp.diveMate.exportInstructions, isNull);
      expect(SourceApp.garminConnect.exportInstructions, isNull);
      expect(SourceApp.generic.exportInstructions, isNull);
    });
  });

  group('ImportEntityType', () {
    test('has all expected values', () {
      expect(ImportEntityType.values, hasLength(11));
    });

    test('displayName for each entity type', () {
      expect(ImportEntityType.dives.displayName, 'Dives');
      expect(ImportEntityType.sites.displayName, 'Sites');
      expect(ImportEntityType.trips.displayName, 'Trips');
      expect(ImportEntityType.equipment.displayName, 'Equipment');
      expect(ImportEntityType.equipmentSets.displayName, 'Equipment Sets');
      expect(ImportEntityType.buddies.displayName, 'Buddies');
      expect(ImportEntityType.diveCenters.displayName, 'Dive Centers');
      expect(ImportEntityType.certifications.displayName, 'Certifications');
      expect(ImportEntityType.courses.displayName, 'Courses');
      expect(ImportEntityType.tags.displayName, 'Tags');
      expect(ImportEntityType.diveTypes.displayName, 'Dive Types');
    });

    test('shortName for each entity type', () {
      expect(ImportEntityType.dives.shortName, 'Dives');
      expect(ImportEntityType.sites.shortName, 'Sites');
      expect(ImportEntityType.trips.shortName, 'Trips');
      expect(ImportEntityType.equipment.shortName, 'Equipment');
      expect(ImportEntityType.equipmentSets.shortName, 'Sets');
      expect(ImportEntityType.buddies.shortName, 'Buddies');
      expect(ImportEntityType.diveCenters.shortName, 'Centers');
      expect(ImportEntityType.certifications.shortName, 'Certs');
      expect(ImportEntityType.courses.shortName, 'Courses');
      expect(ImportEntityType.tags.shortName, 'Tags');
      expect(ImportEntityType.diveTypes.shortName, 'Types');
    });
  });

  group('SourceOverrideOption', () {
    group('supported list', () {
      test('contains expected number of entries', () {
        expect(SourceOverrideOption.supported.length, 14);
      });

      test('contains Submersion CSV entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.submersion &&
              o.format == ImportFormat.csv,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Submersion (CSV)');
      });

      test('contains Submersion UDDF entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.submersion &&
              o.format == ImportFormat.uddf,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Submersion (UDDF)');
      });

      test('contains Subsurface CSV entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.subsurface &&
              o.format == ImportFormat.csv,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Subsurface (CSV)');
      });

      test('contains Subsurface XML entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.subsurface &&
              o.format == ImportFormat.subsurfaceXml,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Subsurface (XML)');
      });

      test('contains Shearwater CSV and Cloud DB entries', () {
        final shearwaterEntries = SourceOverrideOption.supported.where(
          (o) => o.sourceApp == SourceApp.shearwater,
        );
        expect(shearwaterEntries, hasLength(2));

        final csvEntry = shearwaterEntries.where(
          (o) => o.format == ImportFormat.csv,
        );
        expect(csvEntry, hasLength(1));
        expect(csvEntry.first.displayName, 'Shearwater (CSV)');

        final dbEntry = shearwaterEntries.where(
          (o) => o.format == ImportFormat.shearwaterDb,
        );
        expect(dbEntry, hasLength(1));
        expect(dbEntry.first.displayName, 'Shearwater (Cloud DB)');
      });

      test('contains Garmin Connect CSV and FIT entries', () {
        final garminEntries = SourceOverrideOption.supported.where(
          (o) => o.sourceApp == SourceApp.garminConnect,
        );
        expect(garminEntries, hasLength(2));

        final csvEntry = garminEntries.where(
          (o) => o.format == ImportFormat.csv,
        );
        expect(csvEntry, hasLength(1));
        expect(csvEntry.first.displayName, 'Garmin Connect (CSV)');

        final fitEntry = garminEntries.where(
          (o) => o.format == ImportFormat.fit,
        );
        expect(fitEntry, hasLength(1));
        expect(fitEntry.first.displayName, 'Garmin Connect (FIT)');
      });

      test('contains MacDive CSV entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.macdive && o.format == ImportFormat.csv,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'MacDive (CSV)');
      });

      test('contains Diving Log CSV entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.divingLog &&
              o.format == ImportFormat.csv,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Diving Log (CSV)');
      });

      test('contains DiveMate CSV entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.diveMate && o.format == ImportFormat.csv,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'DiveMate (CSV)');
      });

      test('contains Suunto UDDF entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.suunto && o.format == ImportFormat.uddf,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Suunto (UDDF)');
      });

      test('contains SSI MyDiveGuide CSV entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.ssiMyDiveGuide &&
              o.format == ImportFormat.csv,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'SSI MyDiveGuide (CSV)');
      });

      test('contains Scubapro UDDF entry', () {
        final match = SourceOverrideOption.supported.where(
          (o) =>
              o.sourceApp == SourceApp.scubapro &&
              o.format == ImportFormat.uddf,
        );
        expect(match, hasLength(1));
        expect(match.first.displayName, 'Scubapro (UDDF)');
      });
    });

    test('every supported entry has a non-empty displayName', () {
      for (final option in SourceOverrideOption.supported) {
        expect(
          option.displayName.isNotEmpty,
          isTrue,
          reason:
              '${option.sourceApp} + ${option.format} should have a displayName',
        );
      }
    });

    test('all supported displayNames contain expected format strings', () {
      // Verify each entry's displayName includes its format abbreviation.
      for (final option in SourceOverrideOption.supported) {
        final name = option.displayName;
        // Every displayName should contain the source app name.
        expect(
          name.isNotEmpty,
          isTrue,
          reason: 'displayName for ${option.sourceApp} should be non-empty',
        );
      }
    });

    group('findMatch', () {
      test('returns null when sourceApp is null', () {
        final result = SourceOverrideOption.findMatch(null, ImportFormat.csv);
        expect(result, isNull);
      });

      test('returns matching option for exact sourceApp and format pair', () {
        final result = SourceOverrideOption.findMatch(
          SourceApp.subsurface,
          ImportFormat.csv,
        );
        expect(result, isNotNull);
        expect(result!.sourceApp, SourceApp.subsurface);
        expect(result.format, ImportFormat.csv);
        expect(result.displayName, 'Subsurface (CSV)');
      });

      test('returns matching option for Subsurface XML', () {
        final result = SourceOverrideOption.findMatch(
          SourceApp.subsurface,
          ImportFormat.subsurfaceXml,
        );
        expect(result, isNotNull);
        expect(result!.format, ImportFormat.subsurfaceXml);
      });

      test('returns null for valid sourceApp with unsupported format', () {
        // Subsurface + FIT is not in the supported list.
        final result = SourceOverrideOption.findMatch(
          SourceApp.subsurface,
          ImportFormat.fit,
        );
        expect(result, isNull);
      });

      test('returns null for sourceApp not in any supported option', () {
        // The "dan" sourceApp has no entries in the supported list.
        final result = SourceOverrideOption.findMatch(
          SourceApp.dan,
          ImportFormat.csv,
        );
        expect(result, isNull);
      });

      test(
        'returns first matching option by sourceApp when format is null (fallback)',
        () {
          final result = SourceOverrideOption.findMatch(
            SourceApp.submersion,
            null,
          );
          expect(result, isNotNull);
          expect(result!.sourceApp, SourceApp.submersion);
          // Should return the first submersion entry, which is CSV.
          expect(result.format, ImportFormat.csv);
          expect(result.displayName, 'Submersion (CSV)');
        },
      );

      test('fallback returns first Shearwater entry when format is null', () {
        final result = SourceOverrideOption.findMatch(
          SourceApp.shearwater,
          null,
        );
        expect(result, isNotNull);
        expect(result!.sourceApp, SourceApp.shearwater);
        // First shearwater entry is CSV.
        expect(result.format, ImportFormat.csv);
      });

      test(
        'returns null when sourceApp has no supported entries and format is null',
        () {
          // "dan" has no entries in the supported list.
          final result = SourceOverrideOption.findMatch(SourceApp.dan, null);
          expect(result, isNull);
        },
      );

      test('returns null when both sourceApp and format are null', () {
        final result = SourceOverrideOption.findMatch(null, null);
        expect(result, isNull);
      });

      test('finds each distinct (app, format) combo in supported list', () {
        for (final option in SourceOverrideOption.supported) {
          final result = SourceOverrideOption.findMatch(
            option.sourceApp,
            option.format,
          );
          expect(
            result,
            isNotNull,
            reason:
                'findMatch should return a result for ${option.sourceApp} + ${option.format}',
          );
          expect(result!.sourceApp, option.sourceApp);
          expect(result.format, option.format);
        }
      });
    });

    group('equality', () {
      test('two options with same sourceApp and format are equal', () {
        const option1 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV)',
        );
        const option2 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV) - different label',
        );

        expect(option1, equals(option2));
      });

      test('two options with different sourceApp are not equal', () {
        const option1 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV)',
        );
        const option2 = SourceOverrideOption(
          sourceApp: SourceApp.macdive,
          format: ImportFormat.csv,
          displayName: 'MacDive (CSV)',
        );

        expect(option1, isNot(equals(option2)));
      });

      test('two options with different format are not equal', () {
        const option1 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV)',
        );
        const option2 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.subsurfaceXml,
          displayName: 'Subsurface (XML)',
        );

        expect(option1, isNot(equals(option2)));
      });

      test('option is not equal to a non-SourceOverrideOption object', () {
        const option = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV)',
        );

        // ignore: unrelated_type_equality_checks
        expect(option == 'not an option', isFalse);
      });

      test('identical instance is equal to itself', () {
        const option = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV)',
        );

        expect(option, equals(option));
      });
    });

    group('hashCode', () {
      test('equal options have the same hashCode', () {
        const option1 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV)',
        );
        const option2 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Different display name',
        );

        expect(option1.hashCode, equals(option2.hashCode));
      });

      test('different options generally have different hashCodes', () {
        const option1 = SourceOverrideOption(
          sourceApp: SourceApp.subsurface,
          format: ImportFormat.csv,
          displayName: 'Subsurface (CSV)',
        );
        const option2 = SourceOverrideOption(
          sourceApp: SourceApp.macdive,
          format: ImportFormat.csv,
          displayName: 'MacDive (CSV)',
        );

        // Not guaranteed by contract but highly likely for distinct inputs.
        expect(option1.hashCode, isNot(equals(option2.hashCode)));
      });

      test('hashCode uses Object.hash of sourceApp and format', () {
        const option = SourceOverrideOption(
          sourceApp: SourceApp.garminConnect,
          format: ImportFormat.fit,
          displayName: 'Garmin Connect (FIT)',
        );

        expect(
          option.hashCode,
          Object.hash(SourceApp.garminConnect, ImportFormat.fit),
        );
      });
    });
  });
}
