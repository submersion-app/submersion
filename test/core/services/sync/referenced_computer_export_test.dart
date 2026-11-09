import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #4368. A peer that applied a downloaded dive's sources without the
/// computer they point at had its foreign-key repair clear the link, for
/// good. An incremental changeset now carries every computer its dives and
/// sources reference, whatever that computer's own clock.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Future<String> seedComputer() async {
    final now = DateTime(2026, 11, 1);
    await DiveComputerRepository().createComputer(
      DiveComputer(
        id: 'teric',
        name: 'Shearwater Teric',
        manufacturer: 'Shearwater',
        model: 'Teric',
        serialNumber: '8629AC48',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final computer = await serializer.fetchRecord('diveComputers', 'teric');
    return computer!['hlc'] as String;
  }

  Future<SyncData> changesetSince(String watermark) async {
    final payload = await serializer.exportChangeset(
      deviceId: 'me',
      hlcWatermark: watermark,
      deletions: const [],
    );
    return payload.data;
  }

  test('a dive and source newer than the watermark bring their older '
      'computer', () async {
    final watermark = await seedComputer();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "UPDATE dives SET computer_id = 'teric' WHERE id = 'd1'",
    );
    await db.customStatement(
      'INSERT INTO dive_data_sources (id, dive_id, computer_id, '
      'source_format, imported_at, created_at) '
      "VALUES ('s1', 'd1', 'teric', 'dive_computer', 1, 1)",
    );

    final data = await changesetSince(watermark);

    expect(data.diveDataSources.map((s) => s['id']), ['s1']);
    expect(data.diveComputers.map((c) => c['id']), ['teric']);
  });

  test('a dive alone brings its computer too', () async {
    final watermark = await seedComputer();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await DatabaseService.instance.database.customStatement(
      "UPDATE dives SET computer_id = 'teric' WHERE id = 'd1'",
    );

    final data = await changesetSince(watermark);

    expect(data.diveDataSources, isEmpty);
    expect(data.diveComputers.map((c) => c['id']), ['teric']);
  });

  test('a changed series or transmitter alone brings its computer', () async {
    final watermark = await seedComputer();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final newer = Hlc(
      DateTime.now().millisecondsSinceEpoch + 60000,
      0,
      'me',
    ).toString();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dive_profile_series (id, dive_id, computer_id, '
      'sample_count, start_timestamp, end_timestamp, max_depth, '
      'first_depth, last_depth, codec_version, samples, created_at, '
      'updated_at, hlc) VALUES '
      "('p1', 'd1', 'teric', 0, 0, 0, 0, 0, 0, 1, x'', 1, 1, ?)",
      [newer],
    );

    final seriesOnly = await changesetSince(watermark);
    expect(seriesOnly.diveProfileSeries.map((r) => r['id']), ['p1']);
    expect(seriesOnly.diveComputers.map((c) => c['id']), ['teric']);

    await db.customStatement('DELETE FROM dive_profile_series');
    await db.customStatement(
      'INSERT INTO transmitters (id, dive_computer_id, label, tank_role, '
      "created_at, updated_at, hlc) VALUES ('t1', 'teric', 'T1', 'back_gas', "
      '1, 1, ?)',
      [newer],
    );

    final transmitterOnly = await changesetSince(watermark);
    expect(transmitterOnly.transmitters.map((r) => r['id']), ['t1']);
    expect(transmitterOnly.diveComputers.map((c) => c['id']), ['teric']);
  });

  test('a changeset that references no computer carries none', () async {
    final watermark = await seedComputer();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );

    final data = await changesetSince(watermark);

    expect(data.dives.map((d) => d['id']), ['d1']);
    expect(data.diveComputers, isEmpty);
  });
}
