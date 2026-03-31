import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/correlated_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

void main() {
  group('CorrelatedPayload', () {
    test('constructs with required entities', () {
      const payload = CorrelatedPayload(entities: {});

      expect(payload.entities, isEmpty);
      expect(payload.warnings, isEmpty);
      expect(payload.metadata, isEmpty);
    });

    test('constructs with all parameters', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Test warning',
      );
      const payload = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '1', 'maxDepth': 25.0},
          ],
        },
        warnings: [warning],
        metadata: {'sourceApp': 'test'},
      );

      expect(payload.entities, hasLength(1));
      expect(payload.warnings, hasLength(1));
      expect(payload.metadata['sourceApp'], 'test');
    });

    test('entitiesOf returns entities for existing type', () {
      const payload = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '1'},
            {'id': '2'},
          ],
          ImportEntityType.sites: [
            {'name': 'Blue Hole'},
          ],
        },
      );

      expect(payload.entitiesOf(ImportEntityType.dives), hasLength(2));
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
    });

    test('entitiesOf returns empty list for missing type', () {
      const payload = CorrelatedPayload(entities: {});

      expect(payload.entitiesOf(ImportEntityType.dives), isEmpty);
      expect(payload.entitiesOf(ImportEntityType.equipment), isEmpty);
    });

    test('totalEntityCount sums across all types', () {
      const payload = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '1'},
            {'id': '2'},
            {'id': '3'},
          ],
          ImportEntityType.sites: [
            {'name': 'Site A'},
            {'name': 'Site B'},
          ],
        },
      );

      expect(payload.totalEntityCount, 5);
    });

    test('totalEntityCount is 0 for empty payload', () {
      const payload = CorrelatedPayload(entities: {});

      expect(payload.totalEntityCount, 0);
    });

    test('toImportPayload converts to ImportPayload', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Duplicate detected',
      );
      const payload = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '1', 'maxDepth': 25.0},
          ],
        },
        warnings: [warning],
        metadata: {'totalRows': 1},
      );

      final importPayload = payload.toImportPayload();

      expect(importPayload.entitiesOf(ImportEntityType.dives), hasLength(1));
      expect(importPayload.warnings, hasLength(1));
      expect(importPayload.metadata['totalRows'], 1);
    });

    test('supports Equatable equality', () {
      const a = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '1'},
          ],
        },
      );
      const b = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '1'},
          ],
        },
      );
      const c = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '2'},
          ],
        },
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('props includes all fields', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'test',
      );
      const payload = CorrelatedPayload(
        entities: {
          ImportEntityType.dives: [
            {'id': '1'},
          ],
        },
        warnings: [warning],
        metadata: {'key': 'value'},
      );

      expect(payload.props, hasLength(3));
      expect(payload.props[0], payload.entities);
      expect(payload.props[1], payload.warnings);
      expect(payload.props[2], payload.metadata);
    });
  });
}
