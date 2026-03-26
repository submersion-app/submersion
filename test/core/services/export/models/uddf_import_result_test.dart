import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';

void main() {
  group('UddfImportResult', () {
    test('default constructor has all empty collections', () {
      const result = UddfImportResult();

      expect(result.dives, isEmpty);
      expect(result.sites, isEmpty);
      expect(result.equipment, isEmpty);
      expect(result.buddies, isEmpty);
      expect(result.certifications, isEmpty);
      expect(result.diveCenters, isEmpty);
      expect(result.species, isEmpty);
      expect(result.sightings, isEmpty);
      expect(result.serviceRecords, isEmpty);
      expect(result.settings, isEmpty);
      expect(result.owner, isNull);
      expect(result.trips, isEmpty);
      expect(result.tags, isEmpty);
      expect(result.customDiveTypes, isEmpty);
      expect(result.diveComputers, isEmpty);
      expect(result.equipmentSets, isEmpty);
      expect(result.courses, isEmpty);
      expect(result.sourceFileName, isNull);
    });

    group('sourceFileName', () {
      test('can be set via constructor', () {
        const result = UddfImportResult(sourceFileName: 'my_dives.uddf');

        expect(result.sourceFileName, 'my_dives.uddf');
      });

      test('defaults to null', () {
        const result = UddfImportResult();

        expect(result.sourceFileName, isNull);
      });
    });

    group('isEmpty', () {
      test('returns true for default empty result', () {
        const result = UddfImportResult();

        expect(result.isEmpty, isTrue);
      });

      test('returns false when dives are present', () {
        const result = UddfImportResult(
          dives: [
            {'id': '1'},
          ],
        );

        expect(result.isEmpty, isFalse);
      });

      test('returns false when only courses are present', () {
        const result = UddfImportResult(
          courses: [
            {'id': 'c1'},
          ],
        );

        expect(result.isEmpty, isFalse);
      });

      test('returns false when only owner is present', () {
        const result = UddfImportResult(owner: {'name': 'Test'});

        expect(result.isEmpty, isFalse);
      });

      test('sourceFileName does not affect isEmpty', () {
        const result = UddfImportResult(sourceFileName: 'export.uddf');

        expect(result.isEmpty, isTrue);
      });
    });

    group('totalItems', () {
      test('returns 0 for empty result', () {
        const result = UddfImportResult();

        expect(result.totalItems, 0);
      });

      test('counts items across all collections', () {
        const result = UddfImportResult(
          dives: [
            {'id': '1'},
            {'id': '2'},
          ],
          sites: [
            {'id': 's1'},
          ],
          buddies: [
            {'id': 'b1'},
          ],
          courses: [
            {'id': 'c1'},
          ],
        );

        expect(result.totalItems, 5);
      });

      test('counts owner as 1 when present', () {
        const result = UddfImportResult(owner: {'name': 'Test'});

        expect(result.totalItems, 1);
      });

      test('counts settings entries', () {
        const result = UddfImportResult(
          settings: {'unitSystem': 'metric', 'lang': 'en'},
        );

        expect(result.totalItems, 2);
      });
    });

    group('summary', () {
      test('returns "No data" for empty result', () {
        const result = UddfImportResult();

        expect(result.summary, 'No data');
      });

      test('includes dive count', () {
        const result = UddfImportResult(
          dives: [
            {'id': '1'},
            {'id': '2'},
          ],
        );

        expect(result.summary, contains('2 dives'));
      });

      test('includes owner when present', () {
        const result = UddfImportResult(owner: {'name': 'Test'});

        expect(result.summary, contains('1 diver profile'));
      });

      test('includes multiple entity types', () {
        const result = UddfImportResult(
          dives: [
            {'id': '1'},
          ],
          sites: [
            {'id': 's1'},
          ],
          buddies: [
            {'id': 'b1'},
          ],
          courses: [
            {'id': 'c1'},
          ],
        );

        final summary = result.summary;
        expect(summary, contains('1 dives'));
        expect(summary, contains('1 sites'));
        expect(summary, contains('1 buddies'));
        expect(summary, contains('1 courses'));
      });

      test('includes equipment sets', () {
        const result = UddfImportResult(
          equipmentSets: [
            {'id': 'es1'},
            {'id': 'es2'},
          ],
        );

        expect(result.summary, contains('2 equipment sets'));
      });

      test('includes dive computers', () {
        const result = UddfImportResult(
          diveComputers: [
            {'id': 'dc1'},
          ],
        );

        expect(result.summary, contains('1 dive computers'));
      });

      test('includes custom dive types', () {
        const result = UddfImportResult(
          customDiveTypes: [
            {'id': 'dt1'},
          ],
        );

        expect(result.summary, contains('1 custom dive types'));
      });

      test('includes settings count', () {
        const result = UddfImportResult(
          settings: {'unitSystem': 'metric', 'lang': 'en'},
        );

        expect(result.summary, contains('2 settings'));
      });
    });

    group('copyWithSourceFileName', () {
      test('sets sourceFileName on copy', () {
        const original = UddfImportResult(
          dives: [
            {'id': '1'},
          ],
          sites: [
            {'id': 's1'},
          ],
        );

        final copy = original.copyWithSourceFileName('export.uddf');

        expect(copy.sourceFileName, 'export.uddf');
      });

      test('preserves all other fields', () {
        const original = UddfImportResult(
          dives: [
            {'id': '1'},
          ],
          sites: [
            {'id': 's1'},
          ],
          equipment: [
            {'id': 'e1'},
          ],
          buddies: [
            {'id': 'b1'},
          ],
          certifications: [
            {'id': 'cert1'},
          ],
          diveCenters: [
            {'id': 'dc1'},
          ],
          species: [
            {'id': 'sp1'},
          ],
          sightings: [
            {'id': 'sight1'},
          ],
          serviceRecords: [
            {'id': 'sr1'},
          ],
          settings: {'key': 'value'},
          owner: {'name': 'Test'},
          trips: [
            {'id': 't1'},
          ],
          tags: [
            {'id': 'tag1'},
          ],
          customDiveTypes: [
            {'id': 'dt1'},
          ],
          diveComputers: [
            {'id': 'comp1'},
          ],
          equipmentSets: [
            {'id': 'es1'},
          ],
          courses: [
            {'id': 'c1'},
          ],
        );

        final copy = original.copyWithSourceFileName('my_file.uddf');

        expect(copy.sourceFileName, 'my_file.uddf');
        expect(copy.dives, hasLength(1));
        expect(copy.sites, hasLength(1));
        expect(copy.equipment, hasLength(1));
        expect(copy.buddies, hasLength(1));
        expect(copy.certifications, hasLength(1));
        expect(copy.diveCenters, hasLength(1));
        expect(copy.species, hasLength(1));
        expect(copy.sightings, hasLength(1));
        expect(copy.serviceRecords, hasLength(1));
        expect(copy.settings, hasLength(1));
        expect(copy.owner, isNotNull);
        expect(copy.trips, hasLength(1));
        expect(copy.tags, hasLength(1));
        expect(copy.customDiveTypes, hasLength(1));
        expect(copy.diveComputers, hasLength(1));
        expect(copy.equipmentSets, hasLength(1));
        expect(copy.courses, hasLength(1));
      });

      test('can set sourceFileName to null', () {
        const original = UddfImportResult(sourceFileName: 'old.uddf');

        final copy = original.copyWithSourceFileName(null);

        expect(copy.sourceFileName, isNull);
      });

      test('can replace existing sourceFileName', () {
        const original = UddfImportResult(sourceFileName: 'old.uddf');

        final copy = original.copyWithSourceFileName('new.uddf');

        expect(copy.sourceFileName, 'new.uddf');
      });
    });
  });
}
