import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddyRepo;
  late BuddyMergeRepository mergeRepo;
  late CertificationRepository certRepo;

  setUp(() async {
    await setUpTestDatabase();
    buddyRepo = BuddyRepository();
    mergeRepo = BuddyMergeRepository();
    certRepo = CertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Buddy> makeBuddy(String id) async {
    final now = DateTime.now();
    return buddyRepo.createBuddy(
      Buddy(id: id, name: 'Buddy $id', createdAt: now, updatedAt: now),
    );
  }

  Certification cert(String buddyId, String name) => Certification(
    id: '',
    buddyId: buddyId,
    name: name,
    agency: CertificationAgency.padi,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  test(
    'merge reassigns duplicate-owned certs to the survivor (union)',
    () async {
      final survivor = await makeBuddy('survivor');
      await makeBuddy('dup');
      await certRepo.createCertification(cert('survivor', 'OW'));
      final dupCert = await certRepo.createCertification(cert('dup', 'Nitrox'));

      await mergeRepo.mergeBuddies(
        mergedBuddy: survivor,
        buddyIds: ['survivor', 'dup'],
      );

      final survivorCerts = await certRepo.getCertificationsByBuddy('survivor');
      expect(
        survivorCerts.map((c) => c.name),
        unorderedEquals(['OW', 'Nitrox']),
      );
      // Reassigned, not cascade-deleted with the duplicate buddy.
      expect(
        (await certRepo.getCertificationById(dupCert.id))!.buddyId,
        'survivor',
      );
    },
  );

  test('undoMerge restores the duplicate cert owner', () async {
    final survivor = await makeBuddy('survivor');
    await makeBuddy('dup');
    final dupCert = await certRepo.createCertification(cert('dup', 'Nitrox'));

    final result = await mergeRepo.mergeBuddies(
      mergedBuddy: survivor,
      buddyIds: ['survivor', 'dup'],
    );
    await mergeRepo.undoMerge(result!.snapshot!);

    expect((await certRepo.getCertificationById(dupCert.id))!.buddyId, 'dup');
  });
}
