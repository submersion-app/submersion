import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

void main() {
  Certification base() => Certification(
    id: 'c1',
    name: 'Nitrox',
    agency: CertificationAgency.padi,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  test('buddyId defaults to null and round-trips through copyWith', () {
    expect(base().buddyId, isNull);
    final owned = base().copyWith(buddyId: 'b1');
    expect(owned.buddyId, 'b1');
    // buddyId participates in equality
    expect(owned == base(), isFalse);
    expect(owned == base().copyWith(buddyId: 'b1'), isTrue);
  });

  test('clearPhotos preserves buddyId', () {
    final owned = base().copyWith(buddyId: 'b1');
    expect(owned.clearPhotos(clearFront: true).buddyId, 'b1');
  });
}
