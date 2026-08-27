import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late CertificationRepository repository;
  late BuddyRepository buddyRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CertificationRepository();
    buddyRepository = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> makeBuddy(String id) async {
    final now = DateTime.now();
    await buddyRepository.createBuddy(
      Buddy(id: id, name: 'Buddy $id', createdAt: now, updatedAt: now),
    );
  }

  Certification buddyCert(String buddyId, {String name = 'Nitrox'}) =>
      Certification(
        id: '',
        buddyId: buddyId,
        name: name,
        agency: CertificationAgency.padi,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  test('createCertification persists buddyId and hydrates it back', () async {
    await makeBuddy('b1');
    final saved = await repository.createCertification(buddyCert('b1'));
    final read = await repository.getCertificationById(saved.id);
    expect(read!.buddyId, 'b1');
    expect(read.diverId, isNull);
  });

  test(
    'createCertification rejects a cert owned by both a diver and a buddy',
    () async {
      await makeBuddy('b1');
      expect(
        () => repository.createCertification(
          buddyCert('b1').copyWith(diverId: 'd1'),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'an ownerless certification is still allowed (legacy / no diver)',
    () async {
      final saved = await repository.createCertification(
        Certification(
          id: '',
          name: 'Open Water',
          agency: CertificationAgency.padi,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final read = await repository.getCertificationById(saved.id);
      expect(read!.diverId, isNull);
      expect(read.buddyId, isNull);
    },
  );

  test('getCertificationsByBuddy returns only that buddy\'s certs', () async {
    await makeBuddy('b1');
    await makeBuddy('b2');
    await repository.createCertification(buddyCert('b1', name: 'Nitrox'));
    await repository.createCertification(buddyCert('b1', name: 'Deep'));
    await repository.createCertification(buddyCert('b2', name: 'Wreck'));
    final b1 = await repository.getCertificationsByBuddy('b1');
    expect(b1.map((c) => c.name), unorderedEquals(['Nitrox', 'Deep']));
  });

  test('replaceBuddyCertifications inserts, updates, and tombstones', () async {
    await makeBuddy('b1');
    final keep = await repository.createCertification(
      buddyCert('b1', name: 'Nitrox'),
    );
    final drop = await repository.createCertification(
      buddyCert('b1', name: 'Old'),
    );
    await repository.replaceBuddyCertifications('b1', [
      keep.copyWith(name: 'Nitrox (EANx)'), // update
      buddyCert('b1', name: 'New'), // insert (empty id)
      // 'drop' omitted -> delete + tombstone
    ]);
    final now = await repository.getCertificationsByBuddy('b1');
    expect(now.map((c) => c.name), unorderedEquals(['Nitrox (EANx)', 'New']));
    expect(now.any((c) => c.id == drop.id), isFalse);
  });

  test('getExpiringCertifications hydrates buddyId (shared query-row '
      'mapper)', () async {
    await makeBuddy('b1');
    await repository.createCertification(
      Certification(
        id: '',
        buddyId: 'b1',
        name: 'Nitrox',
        agency: CertificationAgency.padi,
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    // The raw customSelect paths (search/expiring/expired) used to drop
    // buddyId; they now go through _mapQueryRowToCertification (issue #553).
    final expiring = await repository.getExpiringCertifications(30);
    expect(expiring.length, 1);
    expect(expiring.single.buddyId, 'b1');
  });

  test(
    'replaceBuddyCertifications skips unchanged certs (no updatedAt churn)',
    () async {
      await makeBuddy('b1');
      await repository.createCertification(buddyCert('b1', name: 'Nitrox'));
      final loaded = (await repository.getCertificationsByBuddy('b1')).single;

      // Re-committing the same (unchanged) cert must not rewrite it -- saving a
      // buddy with unrelated edits shouldn't churn every cert's updatedAt.
      await repository.replaceBuddyCertifications('b1', [loaded]);

      final after = (await repository.getCertificationsByBuddy('b1')).single;
      expect(after.id, loaded.id);
      expect(after.updatedAt, loaded.updatedAt);
    },
  );
}
