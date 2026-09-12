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

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Issue #1737: a full UDDF backup restored onto a clean database must
/// attribute every dive to its guides, divemasters and instructors again,
/// so no leader's profile drops to zero dives.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> restore(String xml) async {
    final diverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );
  }

  /// Role id per person name on the [index]th dive in time order.
  Future<Map<String, String>> rolesOn(int index) async {
    final dives = await DiveRepository().getAllDives();
    final dive = ([
      ...dives,
    ]..sort((a, b) => a.dateTime.compareTo(b.dateTime))).elementAt(index);
    return {
      for (final b in await BuddyRepository().getBuddiesForDive(dive.id))
        b.buddy.name: b.role.id,
    };
  }

  Future<int> diveCountFor(String name) async {
    final buddy = (await BuddyRepository().getAllBuddies()).singleWhere(
      (b) => b.name == name,
    );
    return BuddyRepository().getDiveCountForBuddy(buddy.id);
  }

  test('every per-dive role survives export and restore', () async {
    final diverId = await createTestDiver();
    final custom = await DiveRoleRepository().createDiveRole(
      name: 'Photographer',
      diverId: diverId,
    );
    final buddies = BuddyRepository();
    final now = DateTime.now();
    Future<Buddy> person(String name) => buddies.createBuddy(
      Buddy(id: '', name: name, createdAt: now, updatedAt: now),
    );
    final guide = await person('Nicol Sorin');
    final master = await person('Ana Reyes');
    final instructor = await person('Tom Lee');
    final student = await person('Sam Park');
    final photographer = await person('Pat Kim');
    final plain = await person('Joe Bloggs');

    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime(2026, 3, 1, 9)),
    );
    await dives.createDive(
      domain.Dive(id: 'd2', dateTime: DateTime(2026, 3, 1, 14)),
    );
    await buddies.addBuddyToDive('d1', guide.id, DiveRole.diveGuideId);
    await buddies.addBuddyToDive('d1', master.id, DiveRole.diveMasterId);
    await buddies.addBuddyToDive('d1', instructor.id, DiveRole.instructorId);
    await buddies.addBuddyToDive('d1', student.id, DiveRole.studentId);
    await buddies.addBuddyToDive('d1', photographer.id, custom.id);
    await buddies.addBuddyToDive('d1', plain.id, DiveRole.buddyId);
    await buddies.addBuddyToDive('d2', guide.id, DiveRole.diveGuideId);

    final allDives = await dives.getAllDives();
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: allDives,
      buddies: await buddies.getAllBuddies(),
      diveBuddies: await buddies.getBuddiesForDives([
        for (final d in allDives) d.id,
      ]),
      customDiveRoles: [
        for (final r in await DiveRoleRepository().getAllDiveRoles(
          diverId: diverId,
        ))
          if (!r.isBuiltIn) r,
      ],
    );

    // A clean database, as a restore onto a new device would be.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await restore(xml);

    expect(await rolesOn(0), {
      'Nicol Sorin': DiveRole.diveGuideId,
      'Ana Reyes': DiveRole.diveMasterId,
      'Tom Lee': DiveRole.instructorId,
      'Sam Park': DiveRole.studentId,
      'Pat Kim': custom.id,
      'Joe Bloggs': DiveRole.buddyId,
    });
    expect(await rolesOn(1), {'Nicol Sorin': DiveRole.diveGuideId});
    expect(
      (await DiveRoleRepository().getDiveRoleById(custom.id))?.name,
      'Photographer',
      reason: 'the custom role the link points at is restored too',
    );
    expect(await diveCountFor('Nicol Sorin'), 2);
    expect(
      await BuddyRepository().getAllBuddies(),
      hasLength(6),
      reason: 'a leader named in <divemaster> is not minted a second time',
    );
    for (final d in await DiveRepository().getAllDives()) {
      expect(d.diveMaster, isNull, reason: 'no guide name left as bare text');
    }
  });

  test('an exact role the database lacks falls back to buddy', () async {
    // A custom role whose definition did not arrive (the file lost it, or
    // a caller dropped it) must not leave a link naming a role that does
    // not exist: the UI would show its raw id as the role name.
    final diverId = await createTestDiver();
    const parsed = UddfImportResult(
      buddies: [
        {'uddfId': 'buddy_p', 'name': 'Pat Kim'},
        {'uddfId': 'buddy_s', 'name': 'Sam Park'},
      ],
      dives: [
        {
          'sourceUuid': 'dive_1',
          'buddyRoleRefs': [
            {'buddyRef': 'buddy_p', 'roleId': 'role-never-restored'},
            {'buddyRef': 'buddy_s', 'roleId': DiveRole.studentId},
          ],
        },
      ],
    );

    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    expect(await rolesOn(0), {
      'Pat Kim': DiveRole.buddyId,
      'Sam Park': DiveRole.studentId,
    });
  });

  test('a backup written before <buddyroles> restores its guides', () async {
    // The shape of every full export made before this fix: the guide is a
    // declared <buddy>, linked from the dive like any buddy, and named as
    // the leader only in <divemaster>. The second dive has no link, as a
    // third-party file naming the same person would.
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <diver>
    <buddy id="buddy_n">
      <personal><firstname>Nicol</firstname><lastname>Sorin</lastname></personal>
    </buddy>
  </diver>
  <profiledata>
    <repetitiongroup>
      <dive id="dive_1">
        <informationbeforedive>
          <datetime>2026-03-01T09:00:00</datetime>
          <divemaster>Nicol Sorin</divemaster>
          <link ref="buddy_n"/>
        </informationbeforedive>
      </dive>
      <dive id="dive_2">
        <informationbeforedive>
          <datetime>2026-03-01T14:00:00</datetime>
          <divemaster>Nicol Sorin, Walk In Guide</divemaster>
        </informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

    await restore(xml);

    expect(await diveCountFor('Nicol Sorin'), 2);
    expect(await diveCountFor('Walk In Guide'), 1);
    expect(await rolesOn(0), {'Nicol Sorin': DiveRole.diveGuideId});
    expect(await rolesOn(1), {
      'Nicol Sorin': DiveRole.diveGuideId,
      'Walk In Guide': DiveRole.diveGuideId,
    });
    expect(await BuddyRepository().getAllBuddies(), hasLength(2));
  });
}
