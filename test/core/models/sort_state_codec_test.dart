import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/models/sort_state_codec.dart';

void main() {
  group('encodeSortState / decodeSortState', () {
    test('round-trips every DiveSortField in both directions', () {
      for (final field in DiveSortField.values) {
        for (final direction in SortDirection.values) {
          final sort = SortState(field: field, direction: direction);
          final raw = encodeSortState(sort);
          expect(raw, '${field.name}:${direction.name}');
          expect(decodeSortState(raw, DiveSortField.values), sort);
        }
      }
    });

    test('decodes malformed or unknown values to null', () {
      for (final raw in [
        null,
        '',
        'name',
        'name:sideways',
        'bogus:ascending',
        'name:ascending:extra',
      ]) {
        expect(
          decodeSortState(raw, DivePlanSortField.values),
          isNull,
          reason: 'raw: $raw',
        );
      }
    });
  });

  group('decodeEnumName', () {
    test('returns the matching value', () {
      expect(
        decodeEnumName('depth', DivePlanSortField.values),
        DivePlanSortField.depth,
      );
    });

    test('returns null for an unknown or missing name', () {
      expect(decodeEnumName('bogus', DivePlanSortField.values), isNull);
      expect(decodeEnumName(null, DivePlanSortField.values), isNull);
    });
  });
}
