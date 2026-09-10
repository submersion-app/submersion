import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';

import '../../../helpers/test_database.dart';

/// equipmentFindings syncs like diveSafetyFindings (condition phase 3b):
/// deterministic id, no hlc of its own, exported for equipment whose clock
/// advanced past the watermark, merged after equipment. The review marker
/// table is device-local and is deliberately absent from every sync list.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> findingJson(String id) => {
    'id': id,
    'equipmentId': 'reg',
    'ruleId': 'incidentLinked',
    'severity': 'info',
    'value': 1.0,
    'evidence': '{"n":1,"windowStart":0,"windowEnd":0}',
    'evidenceFingerprint': 'abc',
    'engineVersion': 1,
    'dismissedAt': null,
    'createdAt': 1000,
  };

  Future<void> insertEquipment(String id) =>
      serializer.upsertRecord('equipment', {
        'id': id,
        'name': id,
        'type': 'regulator',
        'status': 'active',
        'purchaseCurrency': 'USD',
        'notes': '',
        'isActive': true,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  test('SyncData carries the entity and the base table key', () {
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      contains('equipmentFindings'),
    );
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      isNot(contains('equipmentConditionReviews')),
    );
    expect(
      SyncData.fromJson({
        'equipmentFindings': [findingJson('f1')],
      }).equipmentFindings,
      hasLength(1),
    );
    expect(const SyncData().toJson().keys, contains('equipmentFindings'));
  });

  test('round-trips through upsertRecord, fetchRecord, deleteRecord', () async {
    await insertEquipment('reg');
    await serializer.upsertRecord('equipmentFindings', findingJson('f1'));
    final row = await serializer.fetchRecord('equipmentFindings', 'f1');
    expect(row, isNotNull);
    expect(row!['ruleId'], 'incidentLinked');
    expect(row['evidenceFingerprint'], 'abc');
    await serializer.deleteRecord('equipmentFindings', 'f1');
    expect(await serializer.fetchRecord('equipmentFindings', 'f1'), isNull);
  });

  test('round-trips through the batch paths and recordIdsFor', () async {
    await insertEquipment('reg');
    await serializer.upsertRecords('equipmentFindings', [
      findingJson('f1'),
      findingJson('f2'),
    ]);
    final fetched = await serializer.fetchRecords('equipmentFindings', [
      'f1',
      'f2',
    ]);
    expect(fetched.keys, containsAll(['f1', 'f2']));
    expect(
      await serializer.recordIdsFor('equipmentFindings'),
      containsAll(['f1', 'f2']),
    );
  });

  test('a saved review is exported by the parent equipment clock', () async {
    await insertEquipment('reg');
    final repo = EquipmentFindingsRepository(syncRepository: SyncRepository());
    final evidence = FindingEvidence(
      n: 1,
      windowStart: DateTime.utc(2026),
      windowEnd: DateTime.utc(2026),
    );
    await repo.saveReview(
      equipmentId: 'reg',
      inputFingerprint: 'fp',
      findings: [
        EquipmentFinding(
          id: 'cf_reg_incidentLinked',
          equipmentId: 'reg',
          ruleId: ConditionRuleId.incidentLinked,
          severity: ConditionSeverity.info,
          value: 1,
          evidence: evidence,
          evidenceFingerprint: evidenceFingerprint(evidence),
          engineVersion: 1,
          createdAt: DateTime.utc(2026),
        ),
      ],
      engineVersion: 1,
      now: DateTime.utc(2026),
    );
    final base = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(
      base.data.equipmentFindings.map((r) => r['id']),
      contains('cf_reg_incidentLinked'),
    );
    final since = await serializer.exportChangeset(
      deviceId: 'dev',
      // Canonical form: zero-padded millis, counter, node.
      hlcWatermark: '000000000000000:000000:0',
      deletions: const [],
    );
    expect(
      since.data.equipmentFindings.map((r) => r['id']),
      contains('cf_reg_incidentLinked'),
    );
    final later = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '999999999999999:999999:z',
      deletions: const [],
    );
    expect(later.data.equipmentFindings, isEmpty);
  });

  test('is registered as a clockless child of equipment', () {
    expect(SyncService.entityHasUpdatedAt['equipmentFindings'], isFalse);
    expect(
      SyncService.entityHasUpdatedAt.containsKey('equipmentConditionReviews'),
      isFalse,
    );
    final refs = SyncService.parentRefs['equipmentFindings']!;
    expect(refs.map((r) => '${r.field}:${r.parent}:${r.nullable}'), [
      'equipmentId:equipment:false',
    ]);
  });
}
