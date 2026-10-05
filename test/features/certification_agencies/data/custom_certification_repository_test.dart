import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CustomCertificationRepository repo;

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 0, updatedAt: 0),
      );

  Future<void> insertCert(
    String id, {
    String agency = 'padi',
    String? level,
    String? credentials,
  }) => db.customStatement(
    'INSERT INTO certifications (id, name, agency, level, '
    'additional_credentials, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, 0, 0)',
    [id, 'Card $id', agency, level, credentials],
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CustomCertificationRepository();
    await insertDiver('a');
    await insertDiver('b');
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> pending(String type) async =>
      (await db.select(db.syncRecords).get())
          .where((r) => r.entityType == type)
          .map((r) => r.recordId)
          .toList();

  Future<List<String>> tombstones(String type) async =>
      (await db.select(db.deletionLog).get())
          .where((r) => r.entityType == type)
          .map((r) => r.recordId)
          .toList();

  group('agencies', () {
    test('create trims, assigns a uuid and marks pending', () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: '  Club X ',
        isShared: false,
      );
      expect(a.name, 'Club X');
      expect(a.id, hasLength(36));
      expect(await pending(CustomCertificationRepository.agencyEntityType), [
        a.id,
      ]);
    });

    test('an empty name is rejected', () async {
      expect(
        () => repo.createAgency(diverId: 'a', name: '   ', isShared: false),
        throwsArgumentError,
      );
    });

    test('a built-in name is taken, case-insensitively', () async {
      expect(
        () => repo.createAgency(diverId: 'a', name: 'padi', isShared: false),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test('a name visible to the diver is taken; another diver may reuse a '
        'private one', () async {
      await repo.createAgency(diverId: 'a', name: 'Club X', isShared: false);
      expect(
        () => repo.createAgency(diverId: 'a', name: 'CLUB x', isShared: false),
        throwsA(isA<CertificationNameTakenException>()),
      );
      final other = await repo.createAgency(
        diverId: 'b',
        name: 'Club X',
        isShared: false,
      );
      expect(other.diverId, 'b');
    });

    test('a shared agency blocks the same name for every diver', () async {
      await repo.createAgency(diverId: 'a', name: 'Club X', isShared: true);
      expect(
        () => repo.createAgency(diverId: 'b', name: 'club x', isShared: false),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test(
      'the owner may rename and share; the change is marked pending',
      () async {
        final a = await repo.createAgency(
          diverId: 'a',
          name: 'Club X',
          isShared: false,
        );
        final updated = await repo.updateAgency(
          a.copyWith(name: 'Club Y', isShared: true, colorArgb: 0xFF22C55E),
          actingDiverId: 'a',
        );
        expect(updated.name, 'Club Y');
        expect(updated.isShared, isTrue);
        expect(updated.colorArgb, 0xFF22C55E);
      },
    );

    test('sharing is refused while another diver has a private agency of '
        'that name', () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club X',
        isShared: false,
      );
      await repo.createAgency(diverId: 'b', name: 'club x', isShared: false);
      expect(
        () => repo.updateAgency(a.copyWith(isShared: true), actingDiverId: 'a'),
        throwsA(isA<CertificationNameTakenException>()),
      );
      expect(
        () => repo.createAgency(diverId: 'a', name: 'CLUB X', isShared: true),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test(
      'a same-name pair that arrived by sync does not block other edits',
      () async {
        final a = await repo.createAgency(
          diverId: 'a',
          name: 'Club X',
          isShared: true,
        );
        // Another device created this before the two synced; no local check
        // ran against it.
        await db.customStatement(
          'INSERT INTO custom_certification_agencies (id, diver_id, name, '
          'color_argb, is_shared, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, 0, 0, 0)',
          ['b-club', 'b', 'Club X', 0xFF22C55E],
        );
        final updated = await repo.updateAgency(
          a.copyWith(colorArgb: 0xFF3B82F6),
          actingDiverId: 'a',
        );
        expect(updated.colorArgb, 0xFF3B82F6);
      },
    );

    test('agencyUsage counts the agency and every one of its levels', () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club X',
        isShared: false,
      );
      final l = await repo.createLevel(
        diverId: 'a',
        agencyId: a.id,
        name: 'Club Diver',
        isProgression: true,
        isShared: false,
      );
      await insertCert('c1', agency: a.id);
      await insertCert('c2', level: l.id);
      final used = await repo.agencyUsage(a.id);
      expect(used.certifications, 2);
      expect(used.courses, 0);
    });

    test('refuses writes from a non-owner', () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club X',
        isShared: true,
      );
      expect(
        () =>
            repo.updateAgency(a.copyWith(name: 'Hijacked'), actingDiverId: 'b'),
        throwsA(isA<CertificationNotOwnerException>()),
      );
      expect(
        () => repo.deleteAgency(a.id, actingDiverId: 'b'),
        throwsA(isA<CertificationNotOwnerException>()),
      );
      expect((await repo.getAllAgencies()).single.name, 'Club X');
    });

    test('delete is refused while a certification, credential or course uses '
        'it', () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club X',
        isShared: false,
      );
      await insertCert('c1', agency: a.id);
      await insertCert('c2', credentials: '[{"agency":"${a.id}"}]');
      await db.customStatement(
        'INSERT INTO courses (id, diver_id, name, agency, start_date, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, 0, 0, 0)',
        ['k1', 'a', 'Course', a.id],
      );
      final refused = await repo.deleteAgency(a.id, actingDiverId: 'a');
      expect(refused, isNotNull);
      expect(refused!.certifications, 2);
      expect(refused.courses, 1);
      expect(await repo.getAllAgencies(), hasLength(1));
      expect(
        await tombstones(CustomCertificationRepository.agencyEntityType),
        isEmpty,
      );
    });

    test('deleting an unused agency removes its unused levels and tombstones '
        'both', () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club X',
        isShared: false,
      );
      final l = await repo.createLevel(
        diverId: 'a',
        agencyId: a.id,
        name: 'Club Diver',
        isProgression: true,
        isShared: false,
      );
      expect(await repo.deleteAgency(a.id, actingDiverId: 'a'), isNull);
      expect(await repo.getAllAgencies(), isEmpty);
      expect(await repo.getAllLevels(), isEmpty);
      expect(await tombstones(CustomCertificationRepository.agencyEntityType), [
        a.id,
      ]);
      expect(await tombstones(CustomCertificationRepository.levelEntityType), [
        l.id,
      ]);
    });

    test('an agency whose level is in use cannot be deleted', () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club X',
        isShared: false,
      );
      final l = await repo.createLevel(
        diverId: 'a',
        agencyId: a.id,
        name: 'Club Diver',
        isProgression: true,
        isShared: false,
      );
      await insertCert('c1', level: l.id);
      expect(await repo.deleteAgency(a.id, actingDiverId: 'a'), isNotNull);
      expect(await repo.getAllLevels(), hasLength(1));
    });
  });

  group('levels', () {
    test(
      'progression levels append in sort order; reorder rewrites it',
      () async {
        final l1 = await repo.createLevel(
          diverId: 'a',
          agencyId: 'padi',
          name: 'Ice Diver',
          isProgression: true,
          isShared: false,
        );
        final l2 = await repo.createLevel(
          diverId: 'a',
          agencyId: 'padi',
          name: 'Ice Instructor',
          isProgression: true,
          isShared: false,
        );
        expect(l2.sortOrder, greaterThan(l1.sortOrder));
        await repo.reorderProgression('padi', [
          l2.id,
          l1.id,
        ], actingDiverId: 'a');
        final byId = {for (final l in await repo.getAllLevels()) l.id: l};
        expect(byId[l2.id]!.sortOrder, lessThan(byId[l1.id]!.sortOrder));
        expect(
          await pending(CustomCertificationRepository.levelEntityType),
          containsAll([l1.id, l2.id]),
        );
      },
    );

    test("reorder keeps another diver's shared rungs where they are", () async {
      final a1 = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: true,
        isShared: false,
      );
      final b1 = await repo.createLevel(
        diverId: 'b',
        agencyId: 'padi',
        name: 'Cave Guide',
        isProgression: true,
        isShared: true,
      );
      final a2 = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Instructor',
        isProgression: true,
        isShared: false,
      );
      await repo.reorderProgression('padi', [a2.id, a1.id], actingDiverId: 'a');
      final byId = {for (final l in await repo.getAllLevels()) l.id: l};
      // The diver's rungs swap the slots they held; the shared rung keeps
      // its slot and no two rungs share one.
      expect(byId[a2.id]!.sortOrder, a1.sortOrder);
      expect(byId[a1.id]!.sortOrder, a2.sortOrder);
      expect(byId[b1.id]!.sortOrder, b1.sortOrder);
    });

    test('sharing a level is refused while another diver has a private one '
        'of that name under the agency', () async {
      await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: true,
        isShared: false,
      );
      final b = await repo.createLevel(
        diverId: 'b',
        agencyId: 'padi',
        name: 'ice diver',
        isProgression: true,
        isShared: false,
      );
      expect(
        () => repo.updateLevel(b.copyWith(isShared: true), actingDiverId: 'b'),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test('reorder refuses another diver\'s level', () async {
      final l1 = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: true,
        isShared: true,
      );
      expect(
        () => repo.reorderProgression('padi', [l1.id], actingDiverId: 'b'),
        throwsA(isA<CertificationNotOwnerException>()),
      );
    });

    test("levels under another diver's custom agency are refused", () async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club A',
        isShared: true,
      );
      expect(
        () => repo.createLevel(
          diverId: 'b',
          agencyId: a.id,
          name: 'Borrowed Rung',
          isProgression: true,
          isShared: false,
        ),
        throwsA(isA<CertificationNotOwnerException>()),
      );
      // The owner may, and anyone may under a built-in agency.
      await repo.createLevel(
        diverId: 'a',
        agencyId: a.id,
        name: 'Club Diver',
        isProgression: true,
        isShared: false,
      );
      await repo.createLevel(
        diverId: 'b',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: true,
        isShared: false,
      );
      expect(await repo.getAllLevels(), hasLength(2));
    });

    test('a built-in level name under the same agency is taken', () async {
      expect(
        () => repo.createLevel(
          diverId: 'a',
          agencyId: 'padi',
          name: 'open water',
          isProgression: true,
          isShared: false,
        ),
        throwsA(isA<CertificationNameTakenException>()),
      );
    });

    test('the same name under a different agency is allowed', () async {
      await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: false,
        isShared: false,
      );
      final ssi = await repo.createLevel(
        diverId: 'a',
        agencyId: 'ssi',
        name: 'Ice Diver',
        isProgression: false,
        isShared: false,
      );
      expect(ssi.agencyId, 'ssi');
    });

    test('moving a specialty onto the ladder appends it', () async {
      final rung = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: true,
        isShared: false,
      );
      final spec = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Altitude',
        isProgression: false,
        isShared: false,
      );
      final moved = await repo.updateLevel(
        spec.copyWith(isProgression: true),
        actingDiverId: 'a',
      );
      expect(moved.isProgression, isTrue);
      expect(moved.sortOrder, greaterThan(rung.sortOrder));
    });

    test('delete is refused while a certification uses it', () async {
      final l = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: false,
        isShared: false,
      );
      await insertCert('c1', level: l.id);
      final refused = await repo.deleteLevel(l.id, actingDiverId: 'a');
      expect(refused?.certifications, 1);
      expect(await repo.getAllLevels(), hasLength(1));
    });

    test('an unused level deletes with a tombstone', () async {
      final l = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: false,
        isShared: false,
      );
      expect(await repo.deleteLevel(l.id, actingDiverId: 'a'), isNull);
      expect(await tombstones(CustomCertificationRepository.levelEntityType), [
        l.id,
      ]);
    });
  });
}
