import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Several roles per person survive UDDF export and import (issue #1221).
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

  test('several diver roles are written in order and restored', () async {
    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diverRoleIds: const [DiveRole.diveMasterId, DiveRole.diveGuideId],
      ),
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: await dives.getAllDives(),
    );
    final written = RegExp(
      r'<diverrole>([^<]*)</diverrole>',
    ).allMatches(xml).map((m) => m.group(1)).toList();
    expect(written, [DiveRole.diveGuideId, DiveRole.diveMasterId]);

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await restore(xml);

    expect((await DiveRepository().getAllDives()).single.diverRoleIds, [
      DiveRole.diveGuideId,
      DiveRole.diveMasterId,
    ]);
  });

  test('the dives-only export parses every diver role', () async {
    final xml = await UddfExportService().generateDivesUddfContent([
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diverRoleIds: const [DiveRole.diveGuideId, DiveRole.diveMasterId],
      ),
    ]);

    final parsed = await ExportService().importAllDataFromUddf(xml);

    expect(parsed.dives.single['diverRoleIds'], [
      DiveRole.diveGuideId,
      DiveRole.diveMasterId,
    ]);
  });

  test('a buddy with several roles round-trips exactly', () async {
    final buddies = BuddyRepository();
    final now = DateTime.now();
    Future<Buddy> person(String name) => buddies.createBuddy(
      Buddy(id: '', name: name, createdAt: now, updatedAt: now),
    );
    final ana = await person('Ana Reyes');
    final ben = await person('Ben Ortiz');
    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime(2026, 3, 1, 9)),
    );
    await buddies.addBuddyToDiveWithRoles('d1', ana.id, const [
      DiveRole.buddyId,
      DiveRole.instructorId,
    ]);
    await buddies.addBuddyToDiveWithRoles('d1', ben.id, const [
      DiveRole.diveGuideId,
      DiveRole.diveMasterId,
    ]);

    final allDives = await dives.getAllDives();
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: allDives,
      buddies: await buddies.getAllBuddies(),
      diveBuddies: await buddies.getBuddiesForDives([
        for (final d in allDives) d.id,
      ]),
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await restore(xml);

    final dive = (await DiveRepository().getAllDives()).single;
    final roles = {
      for (final b in await BuddyRepository().getBuddiesForDive(dive.id))
        b.buddy.name: b.roleIds,
    };
    expect(roles, {
      'Ana Reyes': [DiveRole.instructorId, DiveRole.buddyId],
      'Ben Ortiz': [DiveRole.diveGuideId, DiveRole.diveMasterId],
    });
    expect(
      await BuddyRepository().getAllBuddies(),
      hasLength(2),
      reason: 'a leader named in <divemaster> is not minted a second time',
    );
  });
}
