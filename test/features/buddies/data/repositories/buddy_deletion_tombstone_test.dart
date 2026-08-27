import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
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

  Certification buddyCert(String buddyId) => Certification(
    id: '',
    buddyId: buddyId,
    name: 'Nitrox',
    agency: CertificationAgency.padi,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<int> certTombstoneCount(String recordId) async {
    final db = DatabaseService.instance.database;
    final rows = await db
        .customSelect(
          "SELECT * FROM deletion_log WHERE entity_type = 'certifications' "
          'AND record_id = ?',
          variables: [Variable.withString(recordId)],
        )
        .get();
    return rows.length;
  }

  test('deleteBuddy tombstones the buddy\'s certifications', () async {
    await makeBuddy('b1');
    final c = await certRepo.createCertification(buddyCert('b1'));
    await buddyRepo.deleteBuddy('b1');
    expect(await certRepo.getCertificationById(c.id), isNull);
    expect(await certTombstoneCount(c.id), 1);
  });

  test('bulkDeleteBuddies tombstones each buddy\'s certifications', () async {
    await makeBuddy('b1');
    await makeBuddy('b2');
    final c1 = await certRepo.createCertification(buddyCert('b1'));
    final c2 = await certRepo.createCertification(buddyCert('b2'));
    await buddyRepo.bulkDeleteBuddies(['b1', 'b2']);
    expect(await certTombstoneCount(c1.id), 1);
    expect(await certTombstoneCount(c2.id), 1);
  });
}
