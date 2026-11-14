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
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

/// Issue #4534. The v368 repair stamps nothing, so a peer below v368 goes on
/// sending a cylinder volume saved as water cubic feet, and a new device
/// never ran the rung. Applying such a row has to repair it.
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

  SyncService buildService() =>
      SyncService(syncRepository: SyncRepository(), serializer: serializer);

  /// An AL80 as a peer below v368 publishes it: 77.4 typed as cubic feet of
  /// water.
  Future<SyncPayload> legacyPeerPayload() async {
    final repository = EquipmentRepository();
    await repository.createEquipment(
      const EquipmentItem(
        id: 'template',
        name: 'AL80',
        type: EquipmentType.tank,
      ),
    );
    await repository.saveAttributes('template', [
      EquipmentAttribute.curated(
        equipmentId: 'template',
        key: EquipmentAttrKeys.volumeL,
        valueNum: 1,
      ),
      EquipmentAttribute.curated(
        equipmentId: 'template',
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 206.843,
      ),
    ]);
    final item = (await serializer.fetchRecord('equipment', 'template'))!;
    final volume = (await serializer.fetchRecord(
      'equipmentAttributes',
      EquipmentAttribute.curatedId('template', EquipmentAttrKeys.volumeL),
    ))!;
    final pressure = (await serializer.fetchRecord(
      'equipmentAttributes',
      EquipmentAttribute.curatedId(
        'template',
        EquipmentAttrKeys.workingPressureBar,
      ),
    ))!;
    final updatedAt = DateTime.now().millisecondsSinceEpoch + 60000;
    final hlc = Hlc(updatedAt, 0, 'peer-dev').toString();
    Map<String, dynamic> peer(Map<String, dynamic> row, String key) => {
      ...row,
      'id': EquipmentAttribute.curatedId('peer-al80', key),
      'equipmentId': 'peer-al80',
      'updatedAt': updatedAt,
      'hlc': hlc,
    }..remove('valueUnit');
    final data = SyncData(
      equipment: [
        {...item, 'id': 'peer-al80', 'updatedAt': updatedAt, 'hlc': hlc},
      ],
      equipmentAttributes: [
        {
          ...peer(volume, EquipmentAttrKeys.volumeL),
          'valueNum': 77.4 / 0.0353147,
        },
        peer(pressure, EquipmentAttrKeys.workingPressureBar),
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
    final row = (await serializer.fetchRecord(
      'equipmentAttributes',
      EquipmentAttribute.curatedId('peer-al80', EquipmentAttrKeys.volumeL),
    ))!;
    expect(row['valueNum'], 11.1);
  }

  Future<String> asBaseFile(SyncPayload payload) async {
    final dir = await Directory.systemTemp.createTemp('legacy_cyl_volume');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));
    return file.path;
  }

  test('a payload applied from an older peer is repaired', () async {
    await buildService().debugApplyPayload(await legacyPeerPayload());

    await expectRepaired();
  });

  test('a base file applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyBaseFile(await asBaseFile(payload));

    await expectRepaired();
  });
}
