import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/parsed_profile_event_mapper.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// A UDDF backup carries each profile event's id and source, so a restore
/// brings an annotation back under the id its Notes link names (#4109).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  const notes = 'Current picked up and I [felt sick](annotation:ann-1).';

  Future<String> seedAndExport() async {
    await createTestDiver();
    final dives = DiveRepository();
    await dives.createDive(
      createTestDiveWithBottomTime(
        id: 'd1',
        diveNumber: 1,
      ).copyWith(notes: notes),
    );
    final annotation = ProfileEvent.annotation(
      id: 'ann-1',
      diveId: 'd1',
      timestamp: 1290,
      depth: 19.6,
      words: 'felt sick',
      createdAt: DateTime(2026, 10, 24),
    );
    // The full export, the one a backup uses; the dives-only export never
    // carried profile events.
    return UddfFullExportService().generateAllDataXmlForTest(
      dives: await dives.getDivesByIds(['d1']),
      diveProfileEvents: {
        'd1': [annotation],
      },
    );
  }

  test('the export writes the event id and source', () async {
    final xml = await seedAndExport();
    final event = XmlDocument.parse(
      xml,
    ).findAllElements('profileevents').single.findElements('event').single;
    String child(String name) => event.findElements(name).single.innerText;
    expect(child('eventtype'), 'annotation');
    expect(child('id'), 'ann-1');
    expect(child('source'), 'user');
    expect(child('description'), 'felt sick');
  });

  test('the parse reads them back into the event map', () async {
    final xml = await seedAndExport();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    final maps = parsed.dives.single['profileEvents'] as List;
    final event = profileEventsFromParsed(
      diveId: 'x',
      eventMaps: maps.cast<Map<String, dynamic>>(),
      now: DateTime(2026),
    ).single;
    expect(event.id, 'ann-1');
    expect(event.eventType, ProfileEventType.annotation);
    expect(event.source, EventSource.user);
    expect(event.description, 'felt sick');
    expect(event.depth, 19.6);
  });

  test(
    'a restore on a clean device keeps the annotation under its id',
    () async {
      final xml = await seedAndExport();
      await tearDownTestDatabase();
      final db = await setUpTestDatabase();
      final diverId = await createTestDiver();
      final parsed = await ExportService().importAllDataFromUddf(xml);
      await UddfEntityImporter().import(
        data: parsed,
        selections: UddfImportSelections.selectAll(parsed),
        repositories: buildRepositories(),
        diverId: diverId,
      );

      final restored = (await DiveRepository().getAllDives()).single;
      expect(restored.notes, notes);
      final rows = await db.select(db.diveProfileEvents).get();
      expect(rows, hasLength(1));
      expect(
        (rows.single.id, rows.single.source, rows.single.eventType),
        ('ann-1', 'user', 'annotation'),
      );
    },
  );

  test('restoring the same backup twice keeps one row per annotation id and '
      'does not abort', () async {
    final xml = await seedAndExport();
    await tearDownTestDatabase();
    final db = await setUpTestDatabase();
    final diverId = await createTestDiver();
    Future<void> restore() async {
      final parsed = await ExportService().importAllDataFromUddf(xml);
      await UddfEntityImporter().import(
        data: parsed,
        selections: UddfImportSelections.selectAll(parsed),
        repositories: buildRepositories(),
        diverId: diverId,
      );
    }

    await restore();
    await restore();

    expect(await DiveRepository().getAllDives(), hasLength(2));
    final rows = await db.select(db.diveProfileEvents).get();
    expect(rows.map((r) => r.id), ['ann-1']);
  });
}
