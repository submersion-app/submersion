import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;

/// The sync serializer sends buddy, certification and diver rows as their
/// Drift `toJson` and applies them with `fromJson`, so the v324 card columns
/// (issue #3728) travel with no serializer change. These pin that, and that a
/// row from an older peer without the keys still applies.
void main() {
  test('a buddy row round-trips its card columns through JSON', () {
    const row = db.Buddy(
      id: 'b1',
      name: 'Sam',
      notes: '',
      isFavorite: false,
      createdAt: 1,
      updatedAt: 1,
      cardId: 'diver-sam',
      socialHandle: '@samdives',
      cardDiveCount: 118,
      cardDivingSince: 2016,
      cardLastDive: 1790000000000,
      cardReceivedAt: 1793000000000,
    );
    expect(db.Buddy.fromJson(row.toJson()), row);
  });

  test('an older peer buddy row without card keys applies with nulls', () {
    final json =
        const db.Buddy(
          id: 'b1',
          name: 'Sam',
          notes: '',
          isFavorite: false,
          createdAt: 1,
          updatedAt: 1,
        ).toJson()..removeWhere(
          (key, _) => key.startsWith('card') || key == 'socialHandle',
        );
    final row = db.Buddy.fromJson(json);
    expect(row.cardId, isNull);
    expect(row.cardDiveCount, isNull);
    expect(row.socialHandle, isNull);
  });

  test('certification and diver rows carry their new columns', () {
    const cert = db.Certification(
      id: 'c1',
      name: 'Rescue',
      agency: 'padi',
      notes: '',
      createdAt: 1,
      updatedAt: 1,
      cardId: 'diver-sam',
    );
    expect(db.Certification.fromJson(cert.toJson()).cardId, 'diver-sam');

    final diverJson = db.Diver.fromJson({
      'id': 'd1',
      'name': 'Jordan',
      'medicalNotes': '',
      'notes': '',
      'isDefault': false,
      'createdAt': 1,
      'updatedAt': 1,
      'socialHandle': '@jordan',
      'buddyCardShare': '{}',
    });
    expect(diverJson.socialHandle, '@jordan');
    expect(diverJson.buddyCardShare, '{}');
  });
}
