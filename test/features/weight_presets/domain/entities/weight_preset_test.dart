import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

WeightPresetEntry _entry(
  String id,
  double kg, {
  WeightType type = WeightType.belt,
}) => WeightPresetEntry(id: id, presetId: 'p1', weightType: type, amountKg: kg);

void main() {
  final now = DateTime(2026, 1, 1);
  final preset = WeightPreset(
    id: 'p1',
    diverId: 'd1',
    displayName: 'Drysuit',
    createdAt: now,
    updatedAt: now,
    entries: [
      _entry('e1', 4.0),
      _entry('e2', 1.5, type: WeightType.trimWeights),
    ],
  );

  test('totalKg sums the entries', () {
    expect(preset.totalKg, closeTo(5.5, 1e-9));
  });

  test('an empty preset totals zero', () {
    expect(
      WeightPreset(
        id: 'x',
        displayName: 'empty',
        createdAt: now,
        updatedAt: now,
      ).totalKg,
      0,
    );
  });

  test('toDiveWeights copies the entries with fresh ids for a dive', () {
    var n = 0;
    final rows = preset.toDiveWeights(
      diveId: 'dive-9',
      newId: () => 'new-${n++}',
    );

    expect(rows.map((r) => r.id), ['new-0', 'new-1']);
    expect(rows.every((r) => r.diveId == 'dive-9'), isTrue);
    expect(rows[0].amountKg, 4.0);
    expect(rows[0].weightType, WeightType.belt);
    expect(rows[1].weightType, WeightType.trimWeights);
    // none of the fresh ids collide with the preset entry ids
    expect(rows.map((r) => r.id).toSet().intersection({'e1', 'e2'}), isEmpty);
  });

  test('copyWith replaces only the named fields', () {
    final renamed = preset.copyWith(displayName: 'Drysuit + argon');
    expect(renamed.displayName, 'Drysuit + argon');
    expect(renamed.id, preset.id);
    expect(renamed.diverId, preset.diverId);
    expect(renamed.createdAt, preset.createdAt);
    expect(renamed.entries, preset.entries);

    final later = DateTime(2026, 6, 1);
    final touched = preset.copyWith(
      updatedAt: later,
      sortOrder: 3,
      notes: 'cold water',
      entries: [_entry('e3', 6.0)],
    );
    expect(touched.updatedAt, later);
    expect(touched.sortOrder, 3);
    expect(touched.notes, 'cold water');
    expect(touched.entries.single.id, 'e3');
  });

  test('equality is by value (Equatable props)', () {
    final same = WeightPreset(
      id: 'p1',
      diverId: 'd1',
      displayName: 'Drysuit',
      createdAt: now,
      updatedAt: now,
      entries: [
        _entry('e1', 4.0),
        _entry('e2', 1.5, type: WeightType.trimWeights),
      ],
    );
    expect(same, equals(preset));
    expect(same.copyWith(displayName: 'other'), isNot(equals(preset)));
  });

  test('WeightPresetEntry equality is by value', () {
    expect(_entry('e1', 4.0), equals(_entry('e1', 4.0)));
    expect(_entry('e1', 4.0), isNot(equals(_entry('e1', 4.5))));
  });
}
