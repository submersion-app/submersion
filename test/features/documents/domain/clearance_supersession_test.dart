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
  DocumentOwner owner = const DocumentOwner.personal(),
}) => Document(
  id: id,
  diverId: diverId,
  owner: owner,
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

    test('a clearance with neither date neither supersedes nor is '
        'superseded', () {
      expect(
        supersededClearanceIds([
          doc('dated', expiry: DateTime(2024)),
          doc('undated'),
        ]),
        isEmpty,
      );
    });

    test('an undated renewal issued after the last expiry supersedes it, '
        'one issued before is superseded', () {
      expect(
        supersededClearanceIds([
          doc('expired', expiry: DateTime(2025, 6)),
          doc('renewal', issued: DateTime(2026, 1)),
        ]),
        {'expired'},
      );
      expect(
        supersededClearanceIds([
          doc('current', expiry: DateTime(2027, 6)),
          doc('older', issued: DateTime(2025, 1)),
        ]),
        {'older'},
      );
    });

    test('a buddy\'s clearances supersede only one another', () {
      const b1 = DocumentOwner(DocumentOwnerKind.buddy, 'b1');
      const b2 = DocumentOwner(DocumentOwnerKind.buddy, 'b2');
      expect(
        supersededClearanceIds([
          doc('own', expiry: DateTime(2026, 2)),
          doc('b1-old', expiry: DateTime(2027), owner: b1),
          doc('b1-new', expiry: DateTime(2028), owner: b1),
          doc('b2-only', expiry: DateTime(2025), owner: b2),
        ]),
        {'b1-old'},
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

  test('currentClearances names each holder\'s current one', () {
    const buddy = DocumentOwner(DocumentOwnerKind.buddy, 'b1');
    final current = currentClearances([
      doc('own-old', expiry: DateTime(2024)),
      doc('own-new', expiry: DateTime(2027)),
      doc('buddy', expiry: DateTime(2023), owner: buddy),
      doc('permit', type: DocumentType.permit, expiry: DateTime(2030)),
    ]);
    expect(
      {for (final e in current.entries) e.key: e.value.id},
      {
        (diverId: 'd1', buddyId: null): 'own-new',
        (diverId: 'd1', buddyId: 'b1'): 'buddy',
      },
    );
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
