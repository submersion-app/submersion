import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/clearance_supersession.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

Document doc(
  String id, {
  String diverId = 'd1',
  DocumentType type = DocumentType.medicalClearance,
  DateTime? expiry,
  DateTime? issued,
  DateTime? created,
}) => Document(
  id: id,
  diverId: diverId,
  owner: const DocumentOwner.personal(),
  type: type,
  expiryDate: expiry,
  issueDate: issued,
  createdAt: created ?? DateTime(2026),
  updatedAt: created ?? DateTime(2026),
);

void main() {
  group('supersededClearanceIds', () {
    test('every dated clearance but the one expiring last', () {
      expect(
        supersededClearanceIds([
          doc('old', expiry: DateTime(2024, 3)),
          doc('new', expiry: DateTime(2027, 3)),
          doc('older', expiry: DateTime(2023, 1)),
        ]),
        {'old', 'older'},
      );
    });

    test('a lone clearance is never superseded, however expired', () {
      expect(
        supersededClearanceIds([doc('a', expiry: DateTime(2020))]),
        isEmpty,
      );
    });

    test('an expired newer clearance still supersedes an older one', () {
      // Only the latest can warn: one warning, not one per archived copy.
      expect(
        supersededClearanceIds([
          doc('a', expiry: DateTime(2023)),
          doc('b', expiry: DateTime(2024)),
        ]),
        {'a'},
      );
    });

    test('undated clearances neither supersede nor are superseded', () {
      expect(
        supersededClearanceIds([
          doc('dated', expiry: DateTime(2024)),
          doc('undated'),
        ]),
        isEmpty,
      );
    });

    test('other document types are left alone', () {
      expect(
        supersededClearanceIds([
          doc('p1', type: DocumentType.permit, expiry: DateTime(2024)),
          doc('p2', type: DocumentType.permit, expiry: DateTime(2027)),
        ]),
        isEmpty,
      );
    });

    test('each diver keeps their own latest clearance', () {
      expect(
        supersededClearanceIds([
          doc('a-old', expiry: DateTime(2024)),
          doc('a-new', expiry: DateTime(2027)),
          doc('b-only', diverId: 'd2', expiry: DateTime(2023)),
        ]),
        {'a-old'},
      );
    });

    test('a tie on expiry keeps the later issued, then the later created, '
        'then the higher id', () {
      final expiry = DateTime(2027);
      expect(
        supersededClearanceIds([
          doc('a', expiry: expiry, issued: DateTime(2025, 6)),
          doc('b', expiry: expiry, issued: DateTime(2025, 1)),
        ]),
        {'b'},
      );
      expect(
        supersededClearanceIds([
          doc('a', expiry: expiry, created: DateTime(2026, 2)),
          doc('b', expiry: expiry, created: DateTime(2026, 1)),
        ]),
        {'b'},
      );
      expect(
        supersededClearanceIds([
          doc('a', expiry: expiry),
          doc('b', expiry: expiry),
        ]),
        {'a'},
      );
    });
  });

  test('withoutSupersededClearances drops them and keeps the order', () {
    final permit = doc('p', type: DocumentType.permit, expiry: DateTime(2024));
    final old = doc('old', expiry: DateTime(2024));
    final current = doc('new', expiry: DateTime(2027));
    expect(withoutSupersededClearances([permit, old, current]), [
      permit,
      current,
    ]);
  });
}
