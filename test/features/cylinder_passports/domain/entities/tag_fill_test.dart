import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/tag_fill.dart';

void main() {
  test('fromFill copies what a tag carries, in UTC', () {
    final at = DateTime(2026, 9, 28, 11, 30);
    final fill = CylinderFill(
      id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
      passportId: 'pp-1',
      filledAt: at,
      o2Percent: 21,
      hePercent: 35,
      pressureBar: 232,
      temperatureC: 30,
      stationName: 'Blue Hole',
      analyzer: 'Divesoft',
      createdAt: at,
      updatedAt: at,
    );
    final t = TagFill.fromFill(fill);
    expect(t.id, fill.id);
    expect(t.filledAt, at.toUtc());
    expect(t.filledAt.isUtc, isTrue);
    expect(
      (t.o2Percent, t.hePercent, t.pressureBar, t.temperatureC),
      (21.0, 35.0, 232.0, 30.0),
    );
    expect((t.filledBy, t.analyzer), ('Blue Hole', 'Divesoft'));
    expect(t.gasMix.he, 35);
  });

  test('names are cut to 40 characters by whole characters', () {
    final at = DateTime.utc(2026);
    final t = TagFill.fromFill(
      CylinderFill(
        id: 'x',
        passportId: 'p',
        filledAt: at,
        o2Percent: 21,
        stationName: '\u{1F420}' * 45,
        analyzer: '  ',
        createdAt: at,
        updatedAt: at,
      ),
    );
    expect(t.filledBy!.runes.length, 40);
    expect(t.analyzer, isNull);
  });
}
