import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

void main() {
  DiveTypeEntity entityWith({String? shortName}) => DiveTypeEntity(
    id: 'cenote',
    name: 'Cenote',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    shortName: shortName,
  );

  group('DiveTypeEntity.copyWith shortName', () {
    test('omitting the parameter keeps the current shortName', () {
      final original = entityWith(shortName: 'Cen');

      final copy = original.copyWith(name: 'Cenote System');

      expect(copy.shortName, 'Cen');
    });

    test('passing a new value replaces the current shortName', () {
      final original = entityWith(shortName: 'Cen');

      final copy = original.copyWith(shortName: 'CEN');

      expect(copy.shortName, 'CEN');
    });

    test('passing null explicitly clears an existing shortName '
        '(regression: the edit dialog could not remove a short name)', () {
      final original = entityWith(shortName: 'Cen');

      final copy = original.copyWith(shortName: null);

      expect(copy.shortName, isNull);
    });
  });
}
