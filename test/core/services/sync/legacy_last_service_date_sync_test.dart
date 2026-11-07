import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../helpers/test_database.dart';

/// Issue #4201. The v346 repair stamps nothing, so a sync store keeps the
/// older date a peer wrote, and a peer below v346 goes on writing one when
/// an older service record is logged there. A device past the rung never
/// runs it again, and a new device never ran it at all, so applying such a
/// row has to repair it.
void main() {
  // 2025-03-01 and 2026-03-01 at noon UTC, in milliseconds.
  const older = 1740830400000;
  const newer = 1772366400000;

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

  SyncService buildService() =>
      SyncService(syncRepository: SyncRepository(), serializer: serializer);

  /// An item and its two records as a peer below v346 publishes them: the
  /// older record was logged last, so the item holds its date.
  Future<SyncPayload> legacyPeerPayload() async {
    await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: 'template',
        name: 'Regulator',
        type: EquipmentType.regulator,
      ),
    );
    final now = DateTime.now();
    await ServiceRecordRepository().createRecord(
      ServiceRecord(
        id: 'template-record',
        equipmentId: 'template',
        serviceCategory: ServiceCategory.annual,
        serviceDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final item = (await serializer.fetchRecord('equipment', 'template'))!;
    final record = (await serializer.fetchRecord(
      'serviceRecords',
      'template-record',
    ))!;
    final updatedAt = now.millisecondsSinceEpoch + 60000;
    final hlc = Hlc(updatedAt, 0, 'peer-dev').toString();
    final data = SyncData(
      equipment: [
        {
          ...item,
          'id': 'peer-reg',
          'lastServiceDate': older,
          'updatedAt': updatedAt,
          'hlc': hlc,
        },
      ],
      serviceRecords: [
        for (final (id, day) in [('peer-new', newer), ('peer-old', older)])
          {
            ...record,
            'id': id,
            'equipmentId': 'peer-reg',
            'serviceDate': day,
            'updatedAt': updatedAt,
            'hlc': hlc,
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

  Future<void> expectRepaired() async {
    final row = (await serializer.fetchRecord('equipment', 'peer-reg'))!;
    expect(row['lastServiceDate'], newer);
  }

  /// [payload] written out as a base file, removed after the test.
  Future<String> asBaseFile(SyncPayload payload) async {
    final dir = await Directory.systemTemp.createTemp('legacy_last_service');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));
    return file.path;
  }

  test('a payload applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyPayload(payload);

    await expectRepaired();
  });

  test('a base file applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyBaseFile(await asBaseFile(payload));

    await expectRepaired();
  });

  test('a library adopted from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugAdoptStreaming(
      [await asBaseFile(payload)],
      [payload.exportedAt],
      const [],
    );

    await expectRepaired();
  });

  test('the in-memory reference adopt repairs it too', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugAdoptInMemory([payload]);

    await expectRepaired();
  });
}
