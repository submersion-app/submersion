import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

Document doc({
  DocumentType type = DocumentType.insurance,
  DateTime? expiry,
  int? lead,
}) => Document(
  id: 'd1',
  diverId: 'diver',
  owner: const DocumentOwner.personal(),
  type: type,
  expiryDate: expiry,
  reminderLeadDays: lead,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final now = DateTime(2026, 10, 10, 15, 30);

  test('no expiry date is none', () {
    expect(documentExpiryStatus(doc(), now).kind, DocumentExpiryKind.none);
  });

  test('certification card never has a status', () {
    final d = doc(
      type: DocumentType.certificationCard,
      expiry: DateTime(2026, 10, 1),
    );
    expect(documentExpiryStatus(d, now).kind, DocumentExpiryKind.none);
  });

  test('expiry yesterday is expired by one day', () {
    final s = documentExpiryStatus(doc(expiry: DateTime(2026, 10, 9)), now);
    expect(s.kind, DocumentExpiryKind.expired);
    expect(s.daysLeft, -1);
  });

  test('expiry today is due soon with zero days left, not expired', () {
    final s = documentExpiryStatus(doc(expiry: DateTime(2026, 10, 10)), now);
    expect(s.kind, DocumentExpiryKind.dueSoon);
    expect(s.daysLeft, 0);
  });

  test('default lead is 30 days: day 30 is due soon, day 31 is ok', () {
    expect(
      documentExpiryStatus(doc(expiry: DateTime(2026, 11, 9)), now).kind,
      DocumentExpiryKind.dueSoon,
    );
    expect(
      documentExpiryStatus(doc(expiry: DateTime(2026, 11, 10)), now).kind,
      DocumentExpiryKind.ok,
    );
  });

  test('lead 0 is due only on the expiry day itself', () {
    // The expiry-day notification still fires at lead 0, so the badge and
    // the home chip must say "Expires today" that day too.
    final today = documentExpiryStatus(
      doc(expiry: DateTime(2026, 10, 10), lead: 0),
      now,
    );
    expect(today.kind, DocumentExpiryKind.dueSoon);
    expect(today.daysLeft, 0);
  });

  test('lead 0 is ok before the expiry day and expired after it', () {
    expect(
      documentExpiryStatus(
        doc(expiry: DateTime(2026, 10, 11), lead: 0),
        now,
      ).kind,
      DocumentExpiryKind.ok,
    );
    expect(
      documentExpiryStatus(
        doc(expiry: DateTime(2026, 10, 1), lead: 0),
        now,
      ).kind,
      DocumentExpiryKind.expired,
    );
  });

  test('day counting is calendar based across a DST change', () {
    // Europe and the US both change clocks between these dates.
    final march = DateTime(2026, 3, 1, 23, 0);
    final s = documentExpiryStatus(
      doc(expiry: DateTime(2026, 4, 15), lead: 60),
      march,
    );
    expect(s.daysLeft, 45);
  });

  test('day counting across a month end', () {
    final s = documentExpiryStatus(
      doc(expiry: DateTime(2026, 3, 1)),
      DateTime(2026, 2, 27, 8),
    );
    expect(s.daysLeft, 2);
  });
}
