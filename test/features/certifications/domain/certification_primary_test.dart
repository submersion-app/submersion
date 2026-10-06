import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/certification_primary.dart';

Certification cert(
  String id, {
  CertificationAgency agency = CertificationAgency.cmas,
  CertificationLevel? level,
  DateTime? issue,
  DateTime? updated,
}) => Certification(
  id: id,
  buddyId: 'b1',
  name: id,
  agency: agency.name,
  level: level?.name,
  issueDate: issue,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: updated ?? DateTime(2024, 1, 1),
);

void main() {
  test('empty list -> null', () {
    expect(primaryCertification(const []), isNull);
  });

  test('higher ladder position wins', () {
    final result = primaryCertification([
      cert('a', level: CertificationLevel.cmas1StarDiver),
      cert('b', level: CertificationLevel.cmas3StarDiver),
      cert('c', level: CertificationLevel.cmas2StarDiver),
    ]);
    expect(result!.id, 'b');
  });

  test('a specialty (off-ladder) ranks below any ladder cert', () {
    final result = primaryCertification([
      cert(
        'spec',
        agency: CertificationAgency.padi,
        level: CertificationLevel.nitrox,
      ),
      cert(
        'ladder',
        agency: CertificationAgency.padi,
        level: CertificationLevel.openWater,
      ),
    ]);
    expect(result!.id, 'ladder');
  });

  test('all specialties / no ladder level -> still returns one (not null)', () {
    final result = primaryCertification([
      cert(
        'n',
        agency: CertificationAgency.padi,
        level: CertificationLevel.nitrox,
        issue: DateTime(2020),
      ),
      cert(
        'w',
        agency: CertificationAgency.padi,
        level: CertificationLevel.wreck,
        issue: DateTime(2022),
      ),
    ]);
    // tie on rank (-1); newer issue date wins
    expect(result!.id, 'w');
  });

  test('rank tie broken by issueDate then updatedAt', () {
    final result = primaryCertification([
      cert(
        'old',
        level: CertificationLevel.cmas2StarDiver,
        issue: DateTime(2019),
      ),
      cert(
        'new',
        level: CertificationLevel.cmas2StarDiver,
        issue: DateTime(2023),
      ),
    ]);
    expect(result!.id, 'new');
  });

  test('a custom progression rung beats every built-in rung (issue #690)', () {
    final catalog = CertificationCatalog(
      levels: [
        CustomCertificationLevel(
          id: 'ice',
          diverId: 'a',
          agencyId: 'padi',
          name: 'Ice',
          isProgression: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    final ice = cert(
      'ice',
      agency: CertificationAgency.padi,
    ).copyWith(level: 'ice');
    final cd = cert(
      'cd',
      agency: CertificationAgency.padi,
      level: CertificationLevel.courseDirector,
    );
    expect(primaryCertification([cd, ice], catalog: catalog)!.id, 'ice');
    // Without the catalog the custom id is unknown and ranks last.
    expect(primaryCertification([cd, ice])!.id, 'cd');
  });
}
