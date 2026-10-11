import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// DiveField runs on the shared EntityTableView (#2984).
void main() {
  test('every DiveField is an EntityField with its existing metadata', () {
    for (final f in DiveField.values) {
      final EntityField e = f;
      expect(e.categoryName, f.category.name, reason: '$f');
      expect(e.minWidth, lessThanOrEqualTo(e.defaultWidth), reason: '$f');
    }
  });

  test('numeric columns align right, text columns left', () {
    expect(DiveField.maxDepth.isRightAligned, isTrue);
    expect(DiveField.surfaceInterval.isRightAligned, isTrue);
    expect(DiveField.siteName.isRightAligned, isFalse);
    expect(DiveField.notes.isRightAligned, isFalse);
  });
}
