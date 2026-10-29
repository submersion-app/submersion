import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_importer.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddies;
  late CertificationRepository certs;
  late BuddyCardImporter importer;
  final now = DateTime(2026, 10, 28, 14, 30);

  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    buddies = BuddyRepository();
    certs = CertificationRepository();
    importer = BuddyCardImporter(
      buddies: buddies,
      certifications: certs,
      clock: () => now,
    );
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  final card = BuddyCard(
    id: 'diver-sam',
    name: 'Sam Rivera',
    phone: '+1 555 0134',
    email: 'sam@example.com',
    social: '@samdives',
    certs: [
      BuddyCardCert(
        agency: 'PADI',
        name: 'Rescue Diver',
        level: 'Rescue Diver',
        cardNumber: 'R-1',
        issueDate: DateTime(2020),
      ),
      const BuddyCardCert(
        agency: 'PADI',
        name: 'Open Water Diver',
        level: 'Open Water',
      ),
    ],
    dives: 118,
    since: 2016,
    last: DateTime(2026, 10, 3),
    photo: Uint8List.fromList([1, 2, 3]),
  );

  test('addNew writes fields, cardId, cardReceivedAt and card certs', () async {
    final added = await importer.addNew(card, diverId: 'me');
    final read = (await buddies.getBuddyById(added.id))!;
    expect(read.diverId, 'me');
    expect(read.name, 'Sam Rivera');
    expect(read.phone, '+1 555 0134');
    expect(read.email, 'sam@example.com');
    expect(read.socialHandle, '@samdives');
    expect(read.photo, Uint8List.fromList([1, 2, 3]));
    expect(read.cardId, 'diver-sam');
    expect(read.cardDiveCount, 118);
    expect(read.cardDivingSince, DateTime(2016));
    expect(read.cardLastDive, DateTime(2026, 10, 3));
    expect(read.cardReceivedAt, now);
    final saved = await certs.getCertificationsByBuddy(added.id);
    expect(saved, hasLength(2));
    expect(saved.every((c) => c.cardId == 'diver-sam'), isTrue);
    final rescue = saved.firstWhere((c) => c.name == 'Rescue Diver');
    expect(rescue.agency, CertificationAgency.padi.name);
    expect(rescue.level, CertificationLevel.rescue.name);
    expect(rescue.cardNumber, 'R-1');
  });

  test('demo mode refuses to save a card', () async {
    DemoModeGate.instance.debugActive = true;
    addTearDown(applyGlobalTestDefaults);
    await expectLater(
      importer.addNew(card, diverId: 'me'),
      throwsA(isA<DemoModeSealedException>()),
    );
    expect(await buddies.getAllBuddies(), isEmpty);
  });

  test('headline certification is the card highest', () async {
    final added = await importer.addNew(card, diverId: 'me');
    final read = (await buddies.getBuddyById(added.id))!;
    expect(read.certificationLevel, CertificationLevel.rescue.name);
  });

  Future<Buddy> seedExisting() async {
    final b = await buddies.createBuddy(
      Buddy(
        id: '',
        diverId: 'me',
        name: 'Sam',
        phone: '+1 999',
        notes: 'Great on air',
        isFavorite: true,
        cardDiveCount: 50,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
    );
    await certs.createCertification(
      Certification(
        id: '',
        buddyId: b.id,
        name: 'Hand added deep',
        agency: CertificationAgency.ssi.name,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
    );
    return b;
  }

  test('update keeps notes, favourite and hand-added certs', () async {
    final existing = await seedExisting();
    await importer.update(existing, card);
    final read = (await buddies.getBuddyById(existing.id))!;
    expect(read.notes, 'Great on air');
    expect(read.isFavorite, isTrue);
    expect(read.name, 'Sam Rivera');
    expect(read.phone, '+1 555 0134');
    expect(read.cardDiveCount, 118);
    final saved = await certs.getCertificationsByBuddy(existing.id);
    expect(saved.map((c) => c.name), contains('Hand added deep'));
    expect(saved, hasLength(3));
  });

  test('update refreshes a card cert with the same agency and name', () async {
    final existing = await seedExisting();
    await importer.update(existing, card);
    final refreshed = card.copyWith(
      certs: [
        BuddyCardCert(
          agency: 'PADI',
          name: 'Rescue Diver',
          level: 'Rescue Diver',
          cardNumber: 'R-2',
          issueDate: DateTime(2021),
        ),
      ],
    );
    final again = (await buddies.getBuddyById(existing.id))!;
    await importer.update(again, refreshed);
    final saved = await certs.getCertificationsByBuddy(existing.id);
    final rescues = saved.where((c) => c.name == 'Rescue Diver').toList();
    expect(rescues, hasLength(1));
    expect(rescues.single.cardNumber, 'R-2');
  });

  test('update keeps a card cert missing from the new card', () async {
    final existing = await seedExisting();
    await importer.update(existing, card);
    final again = (await buddies.getBuddyById(existing.id))!;
    await importer.update(again, card.copyWith(certs: const []));
    final saved = await certs.getCertificationsByBuddy(existing.id);
    expect(saved.map((c) => c.name), contains('Open Water Diver'));
  });

  test('a field the card omits is left as it was', () async {
    final existing = await seedExisting();
    await importer.update(
      existing,
      const BuddyCard(id: 'diver-sam', name: 'Sam Rivera'),
    );
    final read = (await buddies.getBuddyById(existing.id))!;
    expect(read.phone, '+1 999');
    expect(read.cardDiveCount, 50);
    expect(read.cardId, 'diver-sam');
  });

  test('an unknown agency is stored as Other with the full title', () async {
    final added = await importer.addNew(
      const BuddyCard(
        id: 'x',
        name: 'Alex',
        certs: [
          BuddyCardCert(agency: 'Blue Lagoon Divers', name: 'Reef Explorer'),
        ],
      ),
      diverId: 'me',
    );
    final saved = await certs.getCertificationsByBuddy(added.id);
    expect(saved.single.agency, CertificationAgency.other.name);
    expect(saved.single.name, 'Blue Lagoon Divers Reef Explorer');
    expect(await CustomCertificationRepository().getAllAgencies(), isEmpty);
  });

  test('a card cert matching one entered by hand is not added twice', () async {
    final existing = await seedExisting();
    await certs.createCertification(
      Certification(
        id: '',
        buddyId: existing.id,
        name: 'Rescue Diver',
        agency: CertificationAgency.padi.name,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
    );
    await importer.update(existing, card);
    final saved = await certs.getCertificationsByBuddy(existing.id);
    expect(saved.where((c) => c.name == 'Rescue Diver'), hasLength(1));
    expect(saved.firstWhere((c) => c.name == 'Rescue Diver').cardId, isNull);
  });

  test('a failed certification write leaves no half-saved buddy', () async {
    final failing = BuddyCardImporter(
      buddies: buddies,
      certifications: _FailingCertifications(),
      clock: () => now,
    );
    await expectLater(
      failing.addNew(card, diverId: 'me'),
      throwsA(isA<StateError>()),
    );
    expect(await buddies.getAllBuddies(), isEmpty);
  });
  test('one card naming a certification twice adds it once', () async {
    final twice = card.copyWith(
      certs: const [
        BuddyCardCert(agency: 'PADI', name: 'Open Water Diver'),
        BuddyCardCert(agency: 'PADI', name: 'Open Water Diver'),
      ],
    );
    final added = await importer.addNew(twice, diverId: 'me');
    expect(await certs.getCertificationsByBuddy(added.id), hasLength(1));
  });

  test('certsToWrite lists only certifications a save would change', () async {
    final added = await importer.addNew(card, diverId: 'me');
    final stored = await certs.getCertificationsByBuddy(added.id);
    // The same card again changes no certification.
    expect(BuddyCardImporter.certsToWrite(card, stored), isEmpty);

    final changed = card.copyWith(
      certs: [
        BuddyCardCert(
          agency: 'PADI',
          name: 'Rescue Diver',
          level: 'Rescue Diver',
          cardNumber: 'R-2',
          issueDate: DateTime(2020),
        ),
        // Without its details (a trimmed QR card): nothing to change.
        card.certs.last.withoutCardDetails(),
        const BuddyCardCert(agency: 'SSI', name: 'Nitrox'),
      ],
    );
    expect(BuddyCardImporter.certsToWrite(changed, stored).map((c) => c.name), [
      'Rescue Diver',
      'Nitrox',
    ]);
  });

  test('a certification found by search still knows its card', () async {
    await importer.addNew(card, diverId: 'me');
    final found = await certs.searchCertifications('Rescue');
    expect(found.single.cardId, 'diver-sam');
  });

  test('a later card without card details keeps the stored number', () async {
    final added = await importer.addNew(card, diverId: 'me');
    final trimmed = card.copyWith(
      certs: [for (final c in card.certs) c.withoutCardDetails()],
    );
    await importer.update(added, trimmed);
    final rescue = (await certs.getCertificationsByBuddy(
      added.id,
    )).singleWhere((c) => c.name == 'Rescue Diver');
    expect(rescue.cardNumber, 'R-1');
    expect(rescue.issueDate, DateTime(2020));
  });

  test('certsToWrite leaves out a twin of a hand-entered one', () async {
    final added = await importer.addNew(
      card.copyWith(certs: const []),
      diverId: 'me',
    );
    await certs.createCertification(
      Certification(
        id: '',
        buddyId: added.id,
        name: 'Open Water Diver',
        agency: CertificationAgency.padi.name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final stored = await certs.getCertificationsByBuddy(added.id);
    expect(BuddyCardImporter.certsToWrite(card, stored).map((c) => c.name), [
      'Rescue Diver',
    ]);
  });

  test(
    'update re-reads the buddy, so changes made meanwhile survive',
    () async {
      final added = await importer.addNew(card, diverId: 'me');
      // The preview opened with this copy; the diver then edited the buddy.
      final shown = (await buddies.getBuddyById(added.id))!;
      await buddies.updateBuddy(
        shown.copyWith(notes: 'Met on the Red Sea trip'),
      );

      await importer.update(shown, card.copyWith(dives: 130));

      final read = (await buddies.getBuddyById(added.id))!;
      expect(read.notes, 'Met on the Red Sea trip');
      expect(read.cardDiveCount, 130);
    },
  );

  test('update of a buddy deleted meanwhile fails instead of resurrecting '
      'it', () async {
    final added = await importer.addNew(card, diverId: 'me');
    await buddies.deleteBuddy(added.id);
    await expectLater(importer.update(added, card), throwsStateError);
    expect(await buddies.getBuddyById(added.id), isNull);
  });
}

class _FailingCertifications extends CertificationRepository {
  @override
  Future<Certification> createCertification(
    Certification cert, {
    bool notify = true,
  }) async => throw StateError('disk full');
}
