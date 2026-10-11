import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// Every dive table column says how its menus filter it (#2984).
void main() {
  test('every column is mapped or explicitly unfilterable, never both', () {
    for (final f in DiveField.values) {
      final mapped = kDiveColumnFilters.containsKey(f);
      final excluded = kUnfilterableDiveColumns.contains(f);
      expect(mapped != excluded, isTrue, reason: '$f');
    }
  });

  test('every mapped key resolves to a field or relation of its kind', () {
    kDiveColumnFilters.forEach((column, spec) {
      final res = resolvePath(appQueryRegistry, diveQueryEntity, spec.path);
      expect(res.error, isNull, reason: '$column -> ${spec.key}');
      switch (spec.kind) {
        case DiveColumnFilterKind.relation:
        case DiveColumnFilterKind.multiRelation:
          expect(res.terminalRelation, isNotNull, reason: '$column');
        case DiveColumnFilterKind.number:
        case DiveColumnFilterKind.integer:
        case DiveColumnFilterKind.duration:
          expect(res.field?.type, FieldType.number, reason: '$column');
        case DiveColumnFilterKind.date:
          expect(res.field?.type, FieldType.date, reason: '$column');
        case DiveColumnFilterKind.text:
          expect(res.field?.type, FieldType.text, reason: '$column');
        case DiveColumnFilterKind.enumValue:
          expect(res.field?.type, FieldType.enumName, reason: '$column');
        case DiveColumnFilterKind.boolean:
          expect(res.field?.type, FieldType.bool, reason: '$column');
        case DiveColumnFilterKind.headerOnly:
          expect(
            res.field != null || res.terminalRelation != null,
            isTrue,
            reason: '$column',
          );
      }
    });
  });

  test('durations are whole minutes, matching how the cell rounds', () {
    for (final e in kDiveColumnFilters.entries.where(
      (e) => e.value.kind == DiveColumnFilterKind.duration,
    )) {
      final res = resolvePath(appQueryRegistry, diveQueryEntity, e.value.path);
      expect(res.field!.dimension, FieldDimension.minutes, reason: '${e.key}');
    }
  });
}
