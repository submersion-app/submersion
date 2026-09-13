import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

void main() {
  Dive make(List<String> ids) =>
      Dive(id: 'd', dateTime: DateTime(2026, 1, 1), diveTypeIds: ids);

  test('diveTypeId getter returns the first type', () {
    expect(make(['shore', 'wreck']).diveTypeId, 'shore');
  });

  test('defaults to a single recreational type', () {
    expect(Dive(id: 'd', dateTime: DateTime(2026, 1, 1)).diveTypeIds, [
      'recreational',
    ]);
  });

  test('diveTypeNames capitalizes each slug', () {
    expect(make(['night', 'deep_wreck']).diveTypeNames, [
      'Night',
      'Deep wreck',
    ]);
  });

  test('copyWith replaces the set', () {
    expect(make(['shore']).copyWith(diveTypeIds: ['cave']).diveTypeIds, [
      'cave',
    ]);
  });

  test('diveTypeName uses the representative (first) slug', () {
    expect(make(['cave', 'deep']).diveTypeName, 'Cave');
  });

  group('diveTypeNamesFrom (#1834)', () {
    DiveTypeEntity type(String id, String name) => DiveTypeEntity(
      id: id,
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('uses the name the diver gave a custom type', () {
      final typesById = {
        'search_recovery': type('search_recovery', 'Search & Recovery'),
        'search_recovery_1a2b3c4d': type(
          'search_recovery_1a2b3c4d',
          'Search Recovery',
        ),
      };
      expect(
        make([
          'search_recovery',
          'search_recovery_1a2b3c4d',
        ]).diveTypeNamesFrom(typesById),
        ['Search & Recovery', 'Search Recovery'],
      );
    });

    test('rebuilds the name from the id when no row is loaded', () {
      expect(make(['night', 'deep_wreck']).diveTypeNamesFrom(const {}), [
        'Night',
        'Deep wreck',
      ]);
    });

    test('falls back to the dive\'s own loaded type for the first id', () {
      final dive = make([
        'search_recovery',
        'night',
      ]).copyWith(diveType: type('search_recovery', 'Search & Recovery'));
      expect(dive.diveTypeNamesFrom(const {}), ['Search & Recovery', 'Night']);
    });

    test('rebuilds the name from the id when the row name is blank', () {
      expect(
        make(['wreck']).diveTypeNamesFrom({'wreck': type('wreck', '  ')}),
        ['Wreck'],
      );
    });
  });
}
