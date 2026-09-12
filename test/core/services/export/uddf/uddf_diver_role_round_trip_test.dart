import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
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

  Future<void> importResult(UddfImportResult data) async {
    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
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
}
