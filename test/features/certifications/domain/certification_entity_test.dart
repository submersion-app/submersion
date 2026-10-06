import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

void main() {
  Certification base() => Certification(
    id: 'c1',
    name: 'Nitrox',
    agency: CertificationAgency.padi.name,
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

  group('dual credentials', () {
    test('a single-agency card has one credential and no extras', () {
      final c = base();
      expect(c.hasMultipleCredentials, isFalse);
      expect(c.credentials, const [
        CertificationCredential(agency: 'padi', level: null),
      ]);
    });

    test('credentials is the row pair followed by the extras, in order', () {
      final c = base().copyWith(
        agency: CertificationAgency.ffessm.name,
        level: CertificationLevel.ffessmN1.name,
        additionalCredentials: const [
          CertificationCredential(agency: 'cmas', level: 'cmas1StarDiver'),
        ],
      );
      expect(c.hasMultipleCredentials, isTrue);
      expect(c.credentials.map((x) => x.agency), [
        CertificationAgency.ffessm.name,
        CertificationAgency.cmas.name,
      ]);
      expect(c.credentials.map((x) => x.level), [
        CertificationLevel.ffessmN1.name,
        CertificationLevel.cmas1StarDiver.name,
      ]);
    });

    test('additionalCredentials round-trips through copyWith and equality', () {
      const extra = [CertificationCredential(agency: 'cmas')];
      final a = base().copyWith(additionalCredentials: extra);
      expect(a.additionalCredentials, extra);
      expect(a == base(), isFalse);
      expect(a == base().copyWith(additionalCredentials: extra), isTrue);
      expect(a.clearPhotos(clearBack: true).additionalCredentials, extra);
    });

    test('CertificationCredential JSON codec', () {
      const cred = CertificationCredential(
        agency: 'cmas',
        level: 'cmas1StarDiver',
      );
      expect(CertificationCredential.fromJson(cred.toJson()), cred);
      const bare = CertificationCredential(agency: 'ffessm');
      expect(bare.toJson().containsKey('level'), isFalse);
      expect(CertificationCredential.fromJson(bare.toJson()), bare);
    });
  });
}
