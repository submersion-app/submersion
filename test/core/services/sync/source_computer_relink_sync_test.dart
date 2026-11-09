import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #4368. The foreign-key repair at the end of an apply clears a data
/// source's computer link when the computer row is missing, and nothing gave
/// it back. Every apply now relinks a downloaded source its own dive vouches
/// for, and brings its serial copy in line with the computer.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    SyncClock.instance.reset();
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  /// A dive whose downloaded source lost its computer link and serial.
  Future<void> seedDetachedSource() async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dive_computers (id, name, manufacturer, model, '
      'serial_number, created_at, updated_at) VALUES '
      "('teric', 'Teric', 'Shearwater', 'Teric', '8629AC48', 1, 1)",
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await db.customStatement(
      "UPDATE dives SET computer_id = 'teric' WHERE id = 'd1'",
    );
    await db.customStatement(
      'INSERT INTO dive_data_sources (id, dive_id, computer_model, '
      'source_format, imported_at, created_at) VALUES '
      "('s1', 'd1', 'Shearwater Teric', 'dive_computer', 1, 1)",
    );
  }

  /// Any payload from a peer: one unrelated dive.
  Future<SyncPayload> peerPayload() async {
    final template = (await serializer.fetchRecord('dives', 'd1'))!;
    final updatedAt = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      dives: [
        {
          ...template,
          'id': 'peer-dive',
          'computerId': null,
          'updatedAt': updatedAt,
          'hlc': Hlc(updatedAt, 0, 'peer-dev').toString(),
        },
      ],
    );
    return SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: 'peer-dev',
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: const {},
    );
  }

  test('an apply relinks the source and fills its serial', () async {
    await seedDetachedSource();
    final payload = await peerPayload();

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: serializer,
    ).debugApplyPayload(payload);

    final source = (await serializer.fetchRecord('diveDataSources', 's1'))!;
    expect(source['computerId'], 'teric');
    expect(source['computerSerial'], '8629AC48');
  });

  test('an apply brings a linked decimal serial copy, as a peer below this '
      'fix sends it, to the computer\'s hex', () async {
    await seedDetachedSource();
    await DatabaseService.instance.database.customStatement(
      "UPDATE dive_data_sources SET computer_id = 'teric', "
      "computer_serial = '2250878024' WHERE id = 's1'",
    );
    final payload = await peerPayload();

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: serializer,
    ).debugApplyPayload(payload);

    final source = (await serializer.fetchRecord('diveDataSources', 's1'))!;
    expect(source['computerSerial'], '8629AC48');
  });
}
