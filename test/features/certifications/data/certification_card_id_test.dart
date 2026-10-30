import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

import '../../../helpers/test_database.dart';

/// A certification remembers the buddy card that made it (issue #3728).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => DatabaseService.instance.resetForTesting());

  test('cardId survives create, update and read', () async {
    await BuddyRepository().createBuddy(
      Buddy(
        id: 'b1',
        name: 'Sam',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final repo = CertificationRepository();
    final created = await repo.createCertification(
      Certification(
        id: '',
        buddyId: 'b1',
        name: 'Rescue Diver',
        agency: CertificationAgency.padi.name,
        cardId: 'diver-sam',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    expect((await repo.getCertificationById(created.id))!.cardId, 'diver-sam');

    await repo.updateCertification(created.copyWith(name: 'Rescue'));
    final read = await repo.getCertificationById(created.id);
    expect(read!.cardId, 'diver-sam');
    expect(read.name, 'Rescue');
  });

  test('a hand-entered certification has no cardId', () async {
    final repo = CertificationRepository();
    final created = await repo.createCertification(
      Certification(
        id: '',
        name: 'Open Water',
        agency: CertificationAgency.padi.name,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    expect((await repo.getCertificationById(created.id))!.cardId, isNull);
  });
}
