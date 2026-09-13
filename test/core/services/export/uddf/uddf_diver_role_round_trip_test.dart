import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// `Dive.diverRoleId` is the logbook owner's own role on a dive. A full
/// UDDF backup restored onto a clean database must bring it back, custom
/// roles included, rather than leaving every dive with no role.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  /// Imports [data] for [diverId], creating the test diver when none is
  /// given.
  Future<void> importResult(UddfImportResult data, {String? diverId}) async {
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId ?? await createTestDiver(),
    );
  }

  /// Restores [xml] the way the import wizard does: through the UDDF
  /// parser, whose payload keeps only entity lists plus the custom role
  /// definitions in its metadata.
  Future<void> restoreThroughWizard(String xml) async {
    final payload = await UddfImportParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    await importResult(
      UddfImportResult(
        dives: payload.entitiesOf(ImportEntityType.dives),
        customDiveRoles: [
          for (final role
              in (payload.metadata[ImportPayload.customDiveRolesKey]
                      as List?) ??
                  const [])
            if (role is Map<String, dynamic>) role,
        ],
      ),
    );
  }

  /// The diver's own role on each dive, in time order.
  Future<List<String?>> diverRoles() async {
    final dives = [...await DiveRepository().getAllDives()]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return [for (final d in dives) d.diverRoleId];
  }

  test('the diver role survives a full export and restore', () async {
    final diverId = await createTestDiver();
    final custom = await DiveRoleRepository().createDiveRole(
      name: 'Photographer',
      diverId: diverId,
    );
    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diverRoleId: DiveRole.instructorId,
      ),
    );
    await dives.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime(2026, 3, 1, 14),
        diverRoleId: custom.id,
      ),
    );
    await dives.createDive(
      domain.Dive(id: 'd3', dateTime: DateTime(2026, 3, 2, 9)),
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: await dives.getAllDives(),
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
    await restoreThroughWizard(xml);

    expect(await diverRoles(), [DiveRole.instructorId, custom.id, null]);
    expect(
      (await DiveRoleRepository().getDiveRoleById(custom.id))?.name,
      'Photographer',
      reason: 'the custom role the dive points at is restored too',
    );
  });

  test('a diver role the database lacks falls back to none', () async {
    // A custom role whose definition did not arrive must not leave the dive
    // naming a role that does not exist: the UI would show its raw id.
    await importResult(
      UddfImportResult(
        dives: [
          {
            'dateTime': DateTime(2026, 3, 1, 9),
            'diverRoleId': 'role-never-restored',
          },
          {
            'dateTime': DateTime(2026, 3, 1, 14),
            'diverRoleId': DiveRole.studentId,
          },
        ],
      ),
    );

    expect(await diverRoles(), [null, DiveRole.studentId]);
  });

  test(
    'a custom role the diver already has is kept without its definition',
    () async {
      // A file may declare no <diveroles> (a dives-only export from before
      // it wrote them), yet name a custom role this diver already holds; the
      // database, not the file, vouches for it.
      final diverId = await createTestDiver();
      final custom = await DiveRoleRepository().createDiveRole(
        name: 'Photographer',
        diverId: diverId,
      );

      await importResult(
        UddfImportResult(
          dives: [
            {'dateTime': DateTime(2026, 3, 1, 9), 'diverRoleId': custom.id},
          ],
        ),
        diverId: diverId,
      );

      expect(await diverRoles(), [custom.id]);
    },
  );

  test('a custom role owned by another diver falls back to none', () async {
    // Another diver's backup restored into this profile: the role id is
    // already taken by its owner, so the restore cannot give this diver a
    // copy, and this diver's role list would show the raw id.
    final now = DateTime.now();
    await DiverRepository().createDiver(
      Diver(id: 'diver-other', name: 'Other', createdAt: now, updatedAt: now),
    );
    final foreign = await DiveRoleRepository().createDiveRole(
      name: 'Photographer',
      diverId: 'diver-other',
    );

    await importResult(
      UddfImportResult(
        dives: [
          {'dateTime': DateTime(2026, 3, 1, 9), 'diverRoleId': foreign.id},
        ],
        customDiveRoles: [
          {
            'id': foreign.id,
            'name': 'Photographer',
            'sortOrder': 10,
            'isBuiltIn': false,
          },
        ],
      ),
    );

    expect(await diverRoles(), [null]);
  });

  test('the dives-only export writes the diver role too', () async {
    final xml = await UddfExportService().generateDivesUddfContent([
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diverRoleId: DiveRole.diveGuideId,
      ),
    ]);

    final parsed = await ExportService().importAllDataFromUddf(xml);

    expect(parsed.dives.single['diverRoleId'], DiveRole.diveGuideId);
  });

  test('the dives-only importer reads the diver role back', () async {
    // The dives-only export's paired importer, kept in step with it the
    // way its entry GPS is.
    final xml = await UddfExportService().generateDivesUddfContent([
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diverRoleId: DiveRole.diveGuideId,
      ),
    ]);

    final dive = (await ExportService().importDivesFromUddf(
      xml,
    ))['dives']!.single;

    expect(dive['diverRoleId'], DiveRole.diveGuideId);
  });

  test(
    'a custom diver role survives a dives-only export with no buddies',
    () async {
      // No participant holds the role, so only the dive itself can bring
      // its definition along; without it a new device drops the role.
      final diverId = await createTestDiver();
      final custom = await DiveRoleRepository().createDiveRole(
        name: 'Photographer',
        diverId: diverId,
      );
      final dives = DiveRepository();
      await dives.createDive(
        domain.Dive(
          id: 'd1',
          diverId: diverId,
          dateTime: DateTime(2026, 3, 1, 9),
          diverRoleId: custom.id,
        ),
      );

      final xml = await UddfExportService().generateDivesUddfContent(
        await dives.getAllDives(),
        extras: await resolveDivesExtras(
          BuddyRepository(),
          EquipmentComponentRepository(),
          DiveRoleRepository(),
          diverId,
          ['d1'],
          const UddfExportOptions(),
        ),
      );

      await tearDownTestDatabase();
      await setUpTestDatabase();
      await restoreThroughWizard(xml);

      expect(await diverRoles(), [custom.id]);
      final restored = await DiveRoleRepository().getAllDiveRoles(
        diverId: diverId,
      );
      expect(restored.where((r) => r.id == custom.id).map((r) => r.name), [
        'Photographer',
      ], reason: 'the role is restored into the importing diver\'s own list');
    },
  );

  test(
    'a dives-only export defines the diver role without participants',
    () async {
      // The diver's own role is not a participant: leaving participants out
      // still writes <diverrole>, so it must still write the definition.
      final epoch = DateTime(2024, 1, 1);
      final photographer = DiveRole(
        id: 'role-photo',
        diverId: 'diver-1',
        name: 'Photographer',
        sortOrder: 12,
        createdAt: epoch,
        updatedAt: epoch,
      );

      final xml = await UddfExportService().generateDivesUddfContent(
        [
          domain.Dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 1, 9),
            diverRoleId: photographer.id,
          ),
          domain.Dive(
            id: 'd2',
            dateTime: DateTime(2026, 3, 1, 14),
            diverRoleId: photographer.id,
          ),
        ],
        extras: UddfDivesExtras(
          diveRoles: [DiveRole.builtInBuddy(), photographer],
        ),
        options: const UddfExportOptions(includeParticipants: false),
      );

      final parsed = await ExportService().importAllDataFromUddf(xml);

      expect(parsed.customDiveRoles, [
        {
          'id': 'role-photo',
          'name': 'Photographer',
          'sortOrder': 12,
          'isBuiltIn': false,
        },
      ]);
    },
  );

  test('a dives-only export defines no role the diver does not own', () async {
    // A role outside the diver's own list (another diver's, or an id with
    // no row) would be written under a name the exporter cannot vouch
    // for; the importer already drops such a role on its own.
    final xml = await UddfExportService().generateDivesUddfContent([
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1, 9),
        diverRoleId: 'role-foreign',
      ),
    ], extras: UddfDivesExtras(diveRoles: [DiveRole.builtInBuddy()]));

    final parsed = await ExportService().importAllDataFromUddf(xml);

    expect(parsed.dives.single['diverRoleId'], 'role-foreign');
    expect(parsed.customDiveRoles, isEmpty);
  });
}
