import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  group('ValueTransform', () {
    test('has nine values', () {
      expect(ValueTransform.values, hasLength(9));
    });

    group('displayName', () {
      test('feetToMeters', () {
        expect(ValueTransform.feetToMeters.displayName, 'ft -> m');
      });

      test('fahrenheitToCelsius', () {
        expect(ValueTransform.fahrenheitToCelsius.displayName, 'F -> C');
      });

      test('psiToBar', () {
        expect(ValueTransform.psiToBar.displayName, 'psi -> bar');
      });

      test('cubicFeetToLiters', () {
        expect(ValueTransform.cubicFeetToLiters.displayName, 'cuft -> L');
      });

      test('minutesToSeconds', () {
        expect(ValueTransform.minutesToSeconds.displayName, 'min -> sec');
      });

      test('hmsToSeconds', () {
        expect(ValueTransform.hmsToSeconds.displayName, 'H:M:S -> sec');
      });

      test('visibilityScale', () {
        expect(ValueTransform.visibilityScale.displayName, 'Visibility');
      });

      test('diveTypeMap', () {
        expect(ValueTransform.diveTypeMap.displayName, 'Dive Type');
      });

      test('ratingScale', () {
        expect(ValueTransform.ratingScale.displayName, 'Rating');
      });
    });
  });

  group('ColumnMapping', () {
    test('constructs with required fields', () {
      const mapping = ColumnMapping(
        sourceColumn: 'Depth',
        targetField: 'maxDepth',
      );

      expect(mapping.sourceColumn, 'Depth');
      expect(mapping.targetField, 'maxDepth');
      expect(mapping.transform, isNull);
      expect(mapping.defaultValue, isNull);
    });

    test('constructs with all fields', () {
      const mapping = ColumnMapping(
        sourceColumn: 'Max Depth (ft)',
        targetField: 'maxDepth',
        transform: ValueTransform.feetToMeters,
        defaultValue: '0',
      );

      expect(mapping.sourceColumn, 'Max Depth (ft)');
      expect(mapping.targetField, 'maxDepth');
      expect(mapping.transform, ValueTransform.feetToMeters);
      expect(mapping.defaultValue, '0');
    });

    group('Equatable', () {
      test('equal objects are equal', () {
        const a = ColumnMapping(
          sourceColumn: 'Depth',
          targetField: 'maxDepth',
          transform: ValueTransform.feetToMeters,
          defaultValue: '0',
        );
        const b = ColumnMapping(
          sourceColumn: 'Depth',
          targetField: 'maxDepth',
          transform: ValueTransform.feetToMeters,
          defaultValue: '0',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different sourceColumn produces inequality', () {
        const a = ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth');
        const b = ColumnMapping(
          sourceColumn: 'Max Depth',
          targetField: 'maxDepth',
        );

        expect(a, isNot(equals(b)));
      });

      test('different targetField produces inequality', () {
        const a = ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth');
        const b = ColumnMapping(sourceColumn: 'Depth', targetField: 'avgDepth');

        expect(a, isNot(equals(b)));
      });

      test('different transform produces inequality', () {
        const a = ColumnMapping(
          sourceColumn: 'Depth',
          targetField: 'maxDepth',
          transform: ValueTransform.feetToMeters,
        );
        const b = ColumnMapping(
          sourceColumn: 'Depth',
          targetField: 'maxDepth',
          transform: ValueTransform.psiToBar,
        );

        expect(a, isNot(equals(b)));
      });

      test('different defaultValue produces inequality', () {
        const a = ColumnMapping(
          sourceColumn: 'Depth',
          targetField: 'maxDepth',
          defaultValue: '0',
        );
        const b = ColumnMapping(
          sourceColumn: 'Depth',
          targetField: 'maxDepth',
          defaultValue: '10',
        );

        expect(a, isNot(equals(b)));
      });

      test('props includes all fields', () {
        const mapping = ColumnMapping(
          sourceColumn: 'Depth',
          targetField: 'maxDepth',
          transform: ValueTransform.feetToMeters,
          defaultValue: '0',
        );

        expect(mapping.props, hasLength(4));
      });
    });
  });

  group('FieldMapping', () {
    const columns = [
      ColumnMapping(sourceColumn: 'Date', targetField: 'diveDateTime'),
      ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
      ColumnMapping(
        sourceColumn: 'Water Temp',
        targetField: 'waterTemp',
        transform: ValueTransform.fahrenheitToCelsius,
      ),
    ];

    test('constructs with required fields', () {
      const mapping = FieldMapping(name: 'Test Mapping', columns: columns);

      expect(mapping.name, 'Test Mapping');
      expect(mapping.sourceApp, isNull);
      expect(mapping.columns, columns);
    });

    test('constructs with all fields', () {
      const mapping = FieldMapping(
        name: 'MacDive Default',
        sourceApp: SourceApp.macdive,
        columns: columns,
      );

      expect(mapping.name, 'MacDive Default');
      expect(mapping.sourceApp, SourceApp.macdive);
      expect(mapping.columns, columns);
    });

    group('mappingForColumn', () {
      const mapping = FieldMapping(
        name: 'Test',
        columns: [
          ColumnMapping(sourceColumn: 'Date', targetField: 'diveDateTime'),
          ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
          ColumnMapping(sourceColumn: 'Water Temp', targetField: 'waterTemp'),
        ],
      );

      test('returns mapping for exact match', () {
        final result = mapping.mappingForColumn('Date');

        expect(result, isNotNull);
        expect(result!.targetField, 'diveDateTime');
      });

      test('returns mapping for case-insensitive match', () {
        final result = mapping.mappingForColumn('max depth');

        expect(result, isNotNull);
        expect(result!.targetField, 'maxDepth');
      });

      test('returns mapping for uppercase match', () {
        final result = mapping.mappingForColumn('WATER TEMP');

        expect(result, isNotNull);
        expect(result!.targetField, 'waterTemp');
      });

      test(
        'returns mapping when source column has leading/trailing spaces',
        () {
          final result = mapping.mappingForColumn('  Date  ');

          expect(result, isNotNull);
          expect(result!.targetField, 'diveDateTime');
        },
      );

      test('handles column definition with whitespace in source', () {
        const mappingWithSpaces = FieldMapping(
          name: 'Spaces',
          columns: [
            ColumnMapping(sourceColumn: '  Depth  ', targetField: 'maxDepth'),
          ],
        );

        final result = mappingWithSpaces.mappingForColumn('Depth');

        expect(result, isNotNull);
        expect(result!.targetField, 'maxDepth');
      });

      test('returns null when no match found', () {
        final result = mapping.mappingForColumn('Nonexistent Column');

        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = mapping.mappingForColumn('');

        expect(result, isNull);
      });

      test('returns null for whitespace-only string', () {
        final result = mapping.mappingForColumn('   ');

        expect(result, isNull);
      });
    });

    group('Equatable', () {
      test('equal objects are equal', () {
        const a = FieldMapping(
          name: 'Test',
          sourceApp: SourceApp.subsurface,
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'diveDateTime'),
          ],
        );
        const b = FieldMapping(
          name: 'Test',
          sourceApp: SourceApp.subsurface,
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'diveDateTime'),
          ],
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different name produces inequality', () {
        const a = FieldMapping(name: 'Mapping A', columns: []);
        const b = FieldMapping(name: 'Mapping B', columns: []);

        expect(a, isNot(equals(b)));
      });

      test('different sourceApp produces inequality', () {
        const a = FieldMapping(
          name: 'Test',
          sourceApp: SourceApp.subsurface,
          columns: [],
        );
        const b = FieldMapping(
          name: 'Test',
          sourceApp: SourceApp.macdive,
          columns: [],
        );

        expect(a, isNot(equals(b)));
      });

      test('different columns produces inequality', () {
        const a = FieldMapping(
          name: 'Test',
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'diveDateTime'),
          ],
        );
        const b = FieldMapping(
          name: 'Test',
          columns: [
            ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
          ],
        );

        expect(a, isNot(equals(b)));
      });

      test('null vs non-null sourceApp produces inequality', () {
        const a = FieldMapping(name: 'Test', columns: []);
        const b = FieldMapping(
          name: 'Test',
          sourceApp: SourceApp.generic,
          columns: [],
        );

        expect(a, isNot(equals(b)));
      });

      test('props includes all fields', () {
        const mapping = FieldMapping(
          name: 'Test',
          sourceApp: SourceApp.subsurface,
          columns: [
            ColumnMapping(sourceColumn: 'Date', targetField: 'diveDateTime'),
          ],
        );

        expect(mapping.props, hasLength(3));
      });
    });
  });
}
