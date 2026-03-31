import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/transformed_rows.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

void main() {
  group('TransformedRows', () {
    test('constructs with required rows', () {
      const rows = TransformedRows(rows: []);

      expect(rows.rows, isEmpty);
      expect(rows.warnings, isEmpty);
      expect(rows.fileRole, 'primary');
    });

    test('constructs with all parameters', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'Test warning',
      );
      const rows = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
        warnings: [warning],
        fileRole: 'dive_profile',
      );

      expect(rows.rows, hasLength(1));
      expect(rows.warnings, hasLength(1));
      expect(rows.fileRole, 'dive_profile');
    });

    test('isEmpty returns true for no rows', () {
      const rows = TransformedRows(rows: []);

      expect(rows.isEmpty, isTrue);
      expect(rows.isNotEmpty, isFalse);
    });

    test('isEmpty returns false when rows exist', () {
      const rows = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
      );

      expect(rows.isEmpty, isFalse);
      expect(rows.isNotEmpty, isTrue);
    });

    test('rowCount reflects number of rows', () {
      const rows = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
          {'maxDepth': 18.0},
          {'maxDepth': 30.0},
        ],
      );

      expect(rows.rowCount, 3);
    });

    test('rowCount is 0 for empty rows', () {
      const rows = TransformedRows(rows: []);

      expect(rows.rowCount, 0);
    });

    test('default fileRole is primary', () {
      const rows = TransformedRows(rows: []);

      expect(rows.fileRole, 'primary');
    });

    test('supports Equatable equality', () {
      const a = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
        fileRole: 'primary',
      );
      const b = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
        fileRole: 'primary',
      );
      const c = TransformedRows(
        rows: [
          {'maxDepth': 30.0},
        ],
        fileRole: 'primary',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('equality considers fileRole', () {
      const a = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
        fileRole: 'primary',
      );
      const b = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
        fileRole: 'dive_profile',
      );

      expect(a, isNot(equals(b)));
    });

    test('equality considers warnings', () {
      const a = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
        warnings: [
          ImportWarning(severity: ImportWarningSeverity.info, message: 'msg A'),
        ],
      );
      const b = TransformedRows(
        rows: [
          {'maxDepth': 25.0},
        ],
        warnings: [
          ImportWarning(severity: ImportWarningSeverity.info, message: 'msg B'),
        ],
      );

      expect(a, isNot(equals(b)));
    });

    test('props includes all fields', () {
      const warning = ImportWarning(
        severity: ImportWarningSeverity.info,
        message: 'test',
      );
      const rows = TransformedRows(
        rows: [
          {'key': 'value'},
        ],
        warnings: [warning],
        fileRole: 'profile',
      );

      expect(rows.props, hasLength(3));
      expect(rows.props[0], rows.rows);
      expect(rows.props[1], rows.warnings);
      expect(rows.props[2], rows.fileRole);
    });
  });
}
