import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Issue #1806: custom dive roles and people are diver-scoped, so a backup
/// restored into a second profile on the same device must give that
/// profile its own copy of each, with the restored links pointing at the
/// copies, rather than dropping a role because the first profile already
/// holds its id, or borrowing (and taking over) the first profile's people.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  const secondDiverId = 'diver-second';

  Future<void> createSecondDiver() async {
    final now = DateTime.now();
    await DiverRepository().createDiver(
      Diver(id: secondDiverId, name: 'Second', createdAt: now, updatedAt: now),
    );
  }

  /// A full backup of one dive in a fresh profile: the diver is a
  /// Photographer (a custom role) and so is their buddy Pat Kim.
  Future<({String xml, DiveRole role})> backupWithCustomRole() async {
    final diverId = await createTestDiver();
    final role = await DiveRoleRepository().createDiveRole(
      name: 'Photographer',
      diverId: diverId,
    );
    final buddies = BuddyRepository();
    final now = DateTime.now();
    final pat = await buddies.createBuddy(
      Buddy(
        id: '',
        diverId: diverId,
        name: 'Pat Kim',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(
        id: 'd1',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 1, 9),
        diverRoleId: role.id,
      ),
    );
    await buddies.addBuddyToDive('d1', pat.id, role.id);

    final allDives = await dives.getAllDives();
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: allDives,
      buddies: await buddies.getAllBuddies(),
      diveBuddies: await buddies.getBuddiesForDives([
        for (final d in allDives) d.id,
      ]),
      customDiveRoles: [role],
    );
    return (xml: xml, role: role);
  }

  Future<void> restoreInto(String xml, String diverId) async {
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );
  }

  Future<List<DiveRole>> customRolesOf(String diverId) async => [
    for (final r in await DiveRoleRepository().getAllDiveRoles(
      diverId: diverId,
    ))
      if (!r.isBuiltIn) r,
  ];

  /// Each of [diverId]'s dives as (the diver's own role, Pat Kim's role).
  Future<List<(String?, String?)>> rolesOnDivesOf(String diverId) async {
    final buddies = BuddyRepository();
    return [
      for (final dive in await DiveRepository().getAllDives(diverId: diverId))
        (
          dive.diverRoleId,
          (await buddies.getBuddiesForDive(
            dive.id,
          )).where((b) => b.buddy.name == 'Pat Kim').singleOrNull?.role.id,
        ),
    ];
  }

  test('restoring into a second profile gives it its own copy', () async {
    final backup = await backupWithCustomRole();
    await createSecondDiver();

    await restoreInto(backup.xml, secondDiverId);

    final copies = await customRolesOf(secondDiverId);
    expect(copies.map((r) => r.name), ['Photographer']);
    final copy = copies.single;
    expect(copy.id, isNot(backup.role.id), reason: 'the first profile owns it');
    expect(await rolesOnDivesOf(secondDiverId), [(copy.id, copy.id)]);

    // The first profile keeps its own role and its own dive untouched.
    final original = await DiveRoleRepository().getDiveRoleById(backup.role.id);
    expect(original?.diverId, backup.role.diverId);
    expect(await rolesOnDivesOf(backup.role.diverId!), [
      (backup.role.id, backup.role.id),
    ]);
  });

  test('restoring into a second profile links only its own people', () async {
    final backup = await backupWithCustomRole();
    final firstDiverId = backup.role.diverId!;
    await createSecondDiver();

    await restoreInto(backup.xml, secondDiverId);

    final buddies = BuddyRepository();
    final ownPat = (await buddies.getAllBuddies(diverId: secondDiverId)).single;
    final dive = (await DiveRepository().getAllDives(
      diverId: secondDiverId,
    )).single;
    expect(
      [for (final b in await buddies.getBuddiesForDive(dive.id)) b.buddy.id],
      [ownPat.id],
      reason: 'the first profile\'s Pat Kim is not on this dive',
    );
    expect(
      (await buddies.getAllBuddies(diverId: firstDiverId)).map((b) => b.name),
      ['Pat Kim'],
      reason: 'the first profile keeps its Pat Kim',
    );
  });

  test('restoring into the second profile again reuses its copy', () async {
    final backup = await backupWithCustomRole();
    await createSecondDiver();

    await restoreInto(backup.xml, secondDiverId);
    await restoreInto(backup.xml, secondDiverId);

    final copy = (await customRolesOf(secondDiverId)).single;
    expect(await rolesOnDivesOf(secondDiverId), [
      (copy.id, copy.id),
      (copy.id, copy.id),
    ]);
  });

  test('a same-named role the profile already has is reused', () async {
    // The role's id is free on this device, but the diver already made a
    // role by that name, so the restore links to it instead of adding a
    // second "Photographer" to the diver's list.
    final backup = await backupWithCustomRole();
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final diverId = await createTestDiver();
    final own = await DiveRoleRepository().createDiveRole(
      name: 'photographer',
      diverId: diverId,
    );

    await restoreInto(backup.xml, diverId);

    expect((await customRolesOf(diverId)).map((r) => r.id), [own.id]);
    expect(await rolesOnDivesOf(diverId), [(own.id, own.id)]);
  });

  test('a restore onto a clean device keeps the original id', () async {
    final backup = await backupWithCustomRole();
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final diverId = await createTestDiver();

    await restoreInto(backup.xml, diverId);

    expect((await customRolesOf(diverId)).map((r) => r.id), [backup.role.id]);
    expect(await rolesOnDivesOf(diverId), [(backup.role.id, backup.role.id)]);
  });
}
