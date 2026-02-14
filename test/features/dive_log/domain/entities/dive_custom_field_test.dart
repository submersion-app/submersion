import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';

void main() {
  group('DiveCustomField', () {
    test('constructs with required fields', () {
      const field = DiveCustomField(
        id: 'cf-1',
        key: 'camera_settings',
        value: 'f/8 ISO400',
      );

      expect(field.id, 'cf-1');
      expect(field.key, 'camera_settings');
      expect(field.value, 'f/8 ISO400');
      expect(field.sortOrder, 0);
    });

    test('defaults value to empty string', () {
      const field = DiveCustomField(id: 'cf-1', key: 'mood');
      expect(field.value, '');
    });

    test('copyWith creates new instance with updated fields', () {
      const original = DiveCustomField(
        id: 'cf-1',
        key: 'camera_settings',
        value: 'f/8 ISO400',
        sortOrder: 0,
      );

      final updated = original.copyWith(value: 'f/11 ISO200', sortOrder: 1);

      expect(updated.id, 'cf-1');
      expect(updated.key, 'camera_settings');
      expect(updated.value, 'f/11 ISO200');
      expect(updated.sortOrder, 1);
      expect(original.value, 'f/8 ISO400'); // original unchanged
    });

    test('equality based on all props', () {
      const a = DiveCustomField(id: 'cf-1', key: 'k', value: 'v');
      const b = DiveCustomField(id: 'cf-1', key: 'k', value: 'v');
      const c = DiveCustomField(id: 'cf-2', key: 'k', value: 'v');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
