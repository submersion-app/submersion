import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

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

  test(
    'getBuddiesForDivesWithCertifications derives primary per person, per dive',
    () async {
      await makeBuddy('b1');
      await makeBuddy('bNoCerts');
      await certRepo.createCertification(cmasCert('b1', 'cmas2StarDiver'));
      final dives = DiveRepository();
      await dives.createDive(Dive(id: 'd1', dateTime: DateTime(2026, 3, 1)));
      await dives.createDive(Dive(id: 'd2', dateTime: DateTime(2026, 3, 2)));
      await buddyRepo.addBuddyToDive('d1', 'b1', DiveRole.diveGuideId);
      await buddyRepo.addBuddyToDive('d1', 'bNoCerts', DiveRole.buddyId);
      await buddyRepo.addBuddyToDive('d2', 'b1', DiveRole.buddyId);

      final byDive = await buddyRepo.getBuddiesForDivesWithCertifications([
        'd1',
        'd2',
      ]);

      Buddy on(String diveId, String buddyId) =>
          byDive[diveId]!.singleWhere((w) => w.buddy.id == buddyId).buddy;
      expect(
        on('d1', 'b1').certificationLevel,
        CertificationLevel.cmas2StarDiver,
      );
      expect(on('d1', 'b1').certificationAgency, CertificationAgency.cmas);
      expect(
        on('d2', 'b1').certificationLevel,
        CertificationLevel.cmas2StarDiver,
      );
      expect(on('d1', 'bNoCerts').certificationLevel, isNull);
      expect(
        byDive['d1']!.singleWhere((w) => w.buddy.id == 'b1').role.id,
        DiveRole.diveGuideId,
        reason: 'roles are kept as the lean load returns them',
      );
    },
  );
}
