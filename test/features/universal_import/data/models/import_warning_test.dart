import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

void main() {
  group('ImportWarningSeverity', () {
    test('has three values', () {
      expect(ImportWarningSeverity.values, hasLength(3));
    });

    test('values are info, warning, error', () {
      expect(ImportWarningSeverity.values, [
        ImportWarningSeverity.info,
        ImportWarningSeverity.warning,
        ImportWarningSeverity.error,
      ]);
    });
  });

  group('ImportWarning', () {
    test('constructs with required parameters only', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Missing optional field',
      );

      expect(warning.severity, ImportWarningSeverity.info);
      expect(warning.message, 'Missing optional field');
      expect(warning.entityType, isNull);
      expect(warning.itemIndex, isNull);
      expect(warning.field, isNull);
    });

    test('constructs with all parameters', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Invalid depth value',
        entityType: ImportEntityType.dives,
        itemIndex: 3,
        field: 'maxDepth',
      );

      expect(warning.severity, ImportWarningSeverity.error);
      expect(warning.message, 'Invalid depth value');
      expect(warning.entityType, ImportEntityType.dives);
      expect(warning.itemIndex, 3);
      expect(warning.field, 'maxDepth');
    });

    test('supports Equatable equality with matching fields', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Duplicate detected',
        entityType: ImportEntityType.dives,
        itemIndex: 0,
        field: 'dateTime',
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Duplicate detected',
        entityType: ImportEntityType.dives,
        itemIndex: 0,
        field: 'dateTime',
      );

      expect(a, equals(b));
    });

    test('is not equal when severity differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same message',
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same message',
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when message differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Message A',
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Message B',
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when entityType differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        entityType: ImportEntityType.dives,
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        entityType: ImportEntityType.sites,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when itemIndex differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        itemIndex: 0,
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        itemIndex: 1,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when field differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        field: 'maxDepth',
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        field: 'waterTemp',
      );

      expect(a, isNot(equals(b)));
    });

    test('props includes all fields', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'test',
        entityType: ImportEntityType.sites,
        itemIndex: 5,
        field: 'name',
      );

      expect(warning.props, hasLength(5));
      expect(warning.props[0], ImportWarningSeverity.warning);
      expect(warning.props[1], 'test');
      expect(warning.props[2], ImportEntityType.sites);
      expect(warning.props[3], 5);
      expect(warning.props[4], 'name');
    });

    test('props with null optional fields', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'basic',
      );

      expect(warning.props, hasLength(5));
      expect(warning.props[2], isNull);
      expect(warning.props[3], isNull);
      expect(warning.props[4], isNull);
    });
  });
}
