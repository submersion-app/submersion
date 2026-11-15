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
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

/// Issue #4534. A peer that predates `equipment_attributes.value_unit` sends
/// attribute rows without the key. Applying one must keep the unit this
/// device holds; only a peer that sends the key may change or clear it.
void main() {
  late SyncDataSerializer serializer;
  late EquipmentRepository repository;
  const gaugeId = 'gauge';
  final rangeId = EquipmentAttribute.curatedId(
    gaugeId,
    'gauge_max_pressure_bar',
  );

  setUp(() async {
    SyncClock.instance.reset();
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    repository = EquipmentRepository();
    await repository.createEquipment(
      const EquipmentItem(
        id: gaugeId,
        name: 'SPG',
        type: EquipmentType.instrument,
      ),
    );
    await repository.saveAttributes(gaugeId, [
      EquipmentAttribute.curated(
        equipmentId: gaugeId,
        key: 'gauge_max_pressure_bar',
        valueNum: 275.79,
        valueUnit: 'psi',
      ),
    ]);
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  SyncService buildService() =>
      SyncService(syncRepository: SyncRepository(), serializer: serializer);

  /// The local range row as a peer sends it, newer, with [edit] applied.
  Future<SyncPayload> peerPayload(
    Map<String, dynamic> Function(Map<String, dynamic>) edit,
  ) async {
    final row = (await serializer.fetchRecord('equipmentAttributes', rangeId))!;
    final updatedAt = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      equipmentAttributes: [
        edit({
          ...row,
          'valueNum': 310.26,
          'updatedAt': updatedAt,
          'hlc': Hlc(updatedAt, 0, 'peer-dev').toString(),
        }),
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

  Future<String> asBaseFile(SyncPayload payload) async {
    final dir = await Directory.systemTemp.createTemp('attribute_value_unit');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));
    return file.path;
  }

  Future<Map<String, dynamic>> range() async =>
      (await serializer.fetchRecord('equipmentAttributes', rangeId))!;

  Map<String, dynamic> withoutUnit(Map<String, dynamic> row) =>
      Map.of(row)..remove('valueUnit');

  test('a payload from an older peer keeps the unit', () async {
    await buildService().debugApplyPayload(await peerPayload(withoutUnit));

    final row = await range();
    expect(row['valueNum'], 310.26);
    expect(row['valueUnit'], 'psi');
  });

  test('a base file from an older peer keeps the unit', () async {
    final payload = await peerPayload(withoutUnit);

    await buildService().debugApplyBaseFile(await asBaseFile(payload));

    final row = await range();
    expect(row['valueNum'], 310.26);
    expect(row['valueUnit'], 'psi');
  });

  test('a peer that sends a null unit clears it', () async {
    await buildService().debugApplyPayload(
      await peerPayload((row) => {...row, 'valueUnit': null}),
    );

    expect((await range())['valueUnit'], isNull);
  });

  test('a peer that sends a unit sets it', () async {
    await buildService().debugApplyPayload(
      await peerPayload((row) => {...row, 'valueUnit': 'bar'}),
    );

    expect((await range())['valueUnit'], 'bar');
  });
}
