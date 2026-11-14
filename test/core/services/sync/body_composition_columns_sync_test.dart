import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;

/// The sync serializer sends diver and weight-entry rows as their Drift
/// `toJson` and applies them with `fromJson`, so the v364 body composition
/// columns (issue #4525) travel with no serializer change. These pin that,
/// and that a row from an older peer without the keys still applies.
void main() {
  Map<String, dynamic> diverJson() => {
    'id': 'd1',
    'name': 'Jordan',
    'medicalNotes': '',
    'notes': '',
    'isDefault': false,
    'createdAt': 1,
    'updatedAt': 1,
  };

  test('a diver row round-trips sex and birth year through JSON', () {
    final row = db.Diver.fromJson({
      ...diverJson(),
      'sex': 'female',
      'birthYear': 1984,
    });
    expect(row.sex, 'female');
    expect(row.birthYear, 1984);
    expect(db.Diver.fromJson(row.toJson()), row);
  });

  test('an older peer diver row without the keys applies with nulls', () {
    final row = db.Diver.fromJson(diverJson());
    expect(row.sex, isNull);
    expect(row.birthYear, isNull);
  });

  test('a weight entry round-trips its body fat through JSON', () {
    const row = db.DiverWeightEntryRow(
      id: 'w1',
      diverId: 'd1',
      measuredAt: 1,
      weightKg: 80,
      heightCm: 175,
      bodyFatPercent: 18.5,
      createdAt: 1,
      updatedAt: 1,
    );
    expect(db.DiverWeightEntryRow.fromJson(row.toJson()), row);
  });

  test('an older peer weight entry without the key applies with null', () {
    final json = const db.DiverWeightEntryRow(
      id: 'w1',
      diverId: 'd1',
      measuredAt: 1,
      weightKg: 80,
      createdAt: 1,
      updatedAt: 1,
    ).toJson()..remove('bodyFatPercent');
    expect(db.DiverWeightEntryRow.fromJson(json).bodyFatPercent, isNull);
  });
}
