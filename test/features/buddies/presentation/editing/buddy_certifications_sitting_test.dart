import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart'
    hide Buddy, Certification;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_certifications_sitting.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A buddy's certifications are held in its page's sitting and written at
/// Save (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  final certs = CertificationRepository();

  Future<Buddy> alex() async => (await BuddyRepository().getBuddyById('b1'))!;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('b1', 'me', 'Alex', 0, 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  test('an added certification is written with the buddy', () async {
    final session = EditSession(await alex());
    addTearDown(session.dispose);
    await buddyCertificationsList.load(session);
    final added = newBuddyCertification(
      session.stored,
    ).copyWith(name: 'Nitrox');

    buddyCertificationsList.set(session, [added]);
    expect(await certs.getCertificationsByBuddy('b1'), isEmpty);
    await session.runHeldWrites();

    final stored = await certs.getCertificationsByBuddy('b1');
    expect(stored.single.id, added.id);
    expect(stored.single.name, 'Nitrox');
    expect(stored.single.buddyId, 'b1');
  });

  test('a removed one is deleted', () async {
    await certs.createCertification(
      Certification(
        id: 'c1',
        buddyId: 'b1',
        name: 'Rescue',
        agency: 'padi',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    final session = EditSession(await alex());
    addTearDown(session.dispose);
    await buddyCertificationsList.load(session);

    buddyCertificationsList.set(session, const []);
    await session.runHeldWrites();

    expect(await certs.getCertificationsByBuddy('b1'), isEmpty);
  });

  test('one added underneath is left as it is', () async {
    final session = EditSession(await alex());
    addTearDown(session.dispose);
    await buddyCertificationsList.load(session);
    buddyCertificationsList.set(session, [
      newBuddyCertification(session.stored).copyWith(name: 'Nitrox'),
    ]);
    await certs.createCertification(
      Certification(
        id: 'c9',
        buddyId: 'b1',
        name: 'Synced',
        agency: 'padi',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );

    await session.runHeldWrites();

    final names = {
      for (final c in await certs.getCertificationsByBuddy('b1')) c.name,
    };
    expect(names, {'Nitrox', 'Synced'});
  });

  test('the held list is ordered as the stored one', () {
    Certification cert(String name, DateTime? issued) => Certification(
      id: name,
      name: name,
      agency: 'padi',
      issueDate: issued,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

    final ordered = buddyCertificationsInOrder([
      cert('Open Water', DateTime(2015)),
      cert('Undated', null),
      cert('Nitrox', DateTime(2024)),
    ]);

    expect(
      [for (final c in ordered) c.name],
      ['Nitrox', 'Open Water', 'Undated'],
    );
  });
}
