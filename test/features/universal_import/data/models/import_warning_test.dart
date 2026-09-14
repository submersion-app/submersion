import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// Builds a warning at runtime rather than as a constant, so the constructor's
/// assert runs as an [AssertionError] instead of a compile-time failure.
ImportWarning _build(
  ImportWarningSeverity severity, {
  ImportWarningCode? code,
}) => ImportWarning(severity: severity, message: 'runtime', code: code);

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
        severity: ImportWarningSeverity.error,
        message: 'Missing required field',
      );

      expect(warning.severity, ImportWarningSeverity.error);
      expect(warning.message, 'Missing required field');
      expect(warning.code, isNull);
      expect(warning.entityType, isNull);
      expect(warning.itemIndex, isNull);
      expect(warning.field, isNull);
      expect(warning.count, 1);
      expect(warning.names, isEmpty);
    });

    test('constructs with all parameters', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Two divers',
        code: ImportWarningCode.columnsNotImported,
        entityType: ImportEntityType.dives,
        itemIndex: 3,
        field: 'maxDepth',
        count: 4,
        names: ['Ann', 'Bo'],
      );

      expect(warning.severity, ImportWarningSeverity.warning);
      expect(warning.message, 'Two divers');
      expect(warning.code, ImportWarningCode.columnsNotImported);
      expect(warning.entityType, ImportEntityType.dives);
      expect(warning.itemIndex, 3);
      expect(warning.field, 'maxDepth');
      expect(warning.count, 4);
      expect(warning.names, ['Ann', 'Bo']);
    });

    group('every warning the summary could show carries a code', () {
      // An uncoded warning is dropped by the summary's grouper, so a parser
      // that forgets the code loses the message silently. The assert makes
      // that mistake fail loudly instead.
      test('an uncoded info warning is rejected', () {
        expect(
          () => _build(ImportWarningSeverity.info),
          throwsA(isA<AssertionError>()),
        );
      });

      test('an uncoded warning-severity warning is rejected', () {
        expect(
          () => _build(ImportWarningSeverity.warning),
          throwsA(isA<AssertionError>()),
        );
      });

      test('an uncoded error is allowed: errors fail their file', () {
        expect(_build(ImportWarningSeverity.error).code, isNull);
      });

      test('a coded info warning is allowed', () {
        expect(
          _build(
            ImportWarningSeverity.info,
            code: ImportWarningCode.diagnostic,
          ).code,
          ImportWarningCode.diagnostic,
        );
      });
    });

    test('supports Equatable equality with matching fields', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Duplicate detected',
        code: ImportWarningCode.diagnostic,
        entityType: ImportEntityType.dives,
        itemIndex: 0,
        field: 'dateTime',
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Duplicate detected',
        code: ImportWarningCode.diagnostic,
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
        code: ImportWarningCode.diagnostic,
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same message',
        code: ImportWarningCode.diagnostic,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when message differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Message A',
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Message B',
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when entityType differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same',
        entityType: ImportEntityType.dives,
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same',
        entityType: ImportEntityType.sites,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when itemIndex differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same',
        itemIndex: 0,
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same',
        itemIndex: 1,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when field differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same',
        field: 'maxDepth',
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'Same',
        field: 'waterTemp',
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when count differs', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.macdiveProfileUndecodable,
        count: 2,
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.macdiveProfileUndecodable,
        count: 3,
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when names differ', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.macdiveLogbooksNotImported,
        names: ['Reef'],
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.macdiveLogbooksNotImported,
        names: ['Wreck'],
      );

      expect(a, isNot(equals(b)));
    });

    test('props includes all fields', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'test',
        code: ImportWarningCode.diagnostic,
        entityType: ImportEntityType.sites,
        itemIndex: 5,
        field: 'name',
        count: 2,
        names: ['x'],
      );

      expect(warning.props, hasLength(9));
      expect(warning.props[0], ImportWarningSeverity.warning);
      expect(warning.props[1], 'test');
      expect(warning.props[2], ImportEntityType.sites);
      expect(warning.props[3], 5);
      expect(warning.props[4], 'name');
      expect(warning.props[5], ImportWarningCode.diagnostic);
      expect(warning.props[6], isNull);
      expect(warning.props[7], 2);
      expect(warning.props[8], ['x']);
    });

    test('props with null optional fields', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.error,
        message: 'basic',
      );

      expect(warning.props, hasLength(9));
      expect(warning.props[2], isNull);
      expect(warning.props[3], isNull);
      expect(warning.props[4], isNull);
      expect(warning.props[5], isNull);
      expect(warning.props[6], isNull);
      expect(warning.props[7], 1);
      expect(warning.props[8], isEmpty);
    });

    test('code participates in equality', () {
      const coded = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.noTankPressure,
      );
      const other = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.diagnostic,
      );

      expect(coded, isNot(equals(other)));
      expect(coded.props[5], ImportWarningCode.noTankPressure);
    });

    test('source row participates in equality', () {
      // Two unreadable rows share a message shape; their row is what tells
      // them apart.
      const row4 = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Same',
        code: ImportWarningCode.unreadableDate,
        sourceRow: 4,
      );
      const row9 = ImportWarning(
        severity: ImportWarningSeverity.warning,
        message: 'Same',
        code: ImportWarningCode.unreadableDate,
        sourceRow: 9,
      );

      expect(row4, isNot(equals(row9)));
      expect(row4.props[6], 4);
    });

    test('identical coded warnings compare equal, so they can be grouped', () {
      const a = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.noTankPressure,
      );
      const b = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Same',
        code: ImportWarningCode.noTankPressure,
      );

      expect(a, equals(b));
    });
  });
}
