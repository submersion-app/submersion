import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddyRepo;
  late CertificationRepository certRepo;

  setUp(() async {
    await setUpTestDatabase();
    buddyRepo = BuddyRepository();
    certRepo = CertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> makeBuddy(String id) async {
    final now = DateTime.now();
    await buddyRepo.createBuddy(
      Buddy(id: id, name: 'Buddy $id', createdAt: now, updatedAt: now),
    );
  }

  Certification cmasCert(String buddyId, String levelName) => Certification(
    id: '',
    buddyId: buddyId,
    name: levelName,
    agency: CertificationAgency.cmas,
    level: CertificationLevel.values.byName(levelName),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  test(
    'getBuddyById derives primary cert (highest by ladder) from certs',
    () async {
      await makeBuddy('b1');
      await certRepo.createCertification(cmasCert('b1', 'cmas1StarDiver'));
      await certRepo.createCertification(cmasCert('b1', 'cmas3StarDiver'));
      final buddy = await buddyRepo.getBuddyById('b1');
      expect(buddy!.certificationAgency, CertificationAgency.cmas);
      expect(buddy.certificationLevel, CertificationLevel.cmas3StarDiver);
    },
  );

  test(
    'getAllBuddies batch-derives primary; buddy with no certs -> null',
    () async {
      await makeBuddy('b1');
      await makeBuddy('bNoCerts');
      await certRepo.createCertification(cmasCert('b1', 'cmas2StarDiver'));
      final buddies = await buddyRepo.getAllBuddies();
      expect(
        buddies.firstWhere((b) => b.id == 'b1').certificationLevel,
        CertificationLevel.cmas2StarDiver,
      );
      expect(
        buddies.firstWhere((b) => b.id == 'bNoCerts').certificationLevel,
        isNull,
      );
    },
  );
}
