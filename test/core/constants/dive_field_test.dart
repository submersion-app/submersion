import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';

void main() {
  group('DiveFieldCategory', () {
    test('every DiveField has a category', () {
      for (final field in DiveField.values) {
        expect(
          field.category,
          isA<DiveFieldCategory>(),
          reason: '${field.name} should have a category',
        );
      }
    });
  });

  group('DiveField metadata', () {
    test('every field has a non-empty shortLabel', () {
      for (final field in DiveField.values) {
        expect(
          field.shortLabel.isNotEmpty,
          isTrue,
          reason: '${field.name} should have a shortLabel',
        );
      }
    });

    test('every field has a positive defaultWidth', () {
      for (final field in DiveField.values) {
        expect(
          field.defaultWidth,
          greaterThan(0),
          reason: '${field.name} should have a positive defaultWidth',
        );
      }
    });

    test('every field has minWidth <= defaultWidth', () {
      for (final field in DiveField.values) {
        expect(
          field.minWidth,
          lessThanOrEqualTo(field.defaultWidth),
          reason: '${field.name} minWidth should be <= defaultWidth',
        );
      }
    });

    test('core fields are sortable', () {
      expect(DiveField.diveNumber.sortable, isTrue);
      expect(DiveField.dateTime.sortable, isTrue);
      expect(DiveField.maxDepth.sortable, isTrue);
      expect(DiveField.bottomTime.sortable, isTrue);
    });

    test('notes field is not sortable', () {
      expect(DiveField.notes.sortable, isFalse);
    });

    test('fields with icons return non-null IconData', () {
      expect(DiveField.maxDepth.icon, equals(Icons.arrow_downward));
      expect(DiveField.bottomTime.icon, equals(Icons.timer));
      expect(DiveField.waterTemp.icon, equals(Icons.thermostat));
    });

    test('fields without icons return null', () {
      expect(DiveField.sacRate.icon, isNull);
      expect(DiveField.gradientFactorLow.icon, isNull);
    });

    test('fieldsForCategory returns correct fields', () {
      final coreFields = DiveField.fieldsForCategory(DiveFieldCategory.core);
      expect(coreFields, contains(DiveField.diveNumber));
      expect(coreFields, contains(DiveField.dateTime));
      expect(coreFields, contains(DiveField.maxDepth));
      expect(coreFields, isNot(contains(DiveField.waterTemp)));
    });

    test('summaryFields returns only fields available on DiveSummary', () {
      final summaryFields = DiveField.summaryFields;
      expect(summaryFields, contains(DiveField.diveNumber));
      expect(summaryFields, contains(DiveField.maxDepth));
      expect(summaryFields, isNot(contains(DiveField.buddy)));
      expect(summaryFields, isNot(contains(DiveField.sacRate)));
    });
  });
}
