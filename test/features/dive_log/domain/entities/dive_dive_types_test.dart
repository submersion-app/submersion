import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

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
}
