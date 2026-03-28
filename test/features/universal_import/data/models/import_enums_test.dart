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
}
