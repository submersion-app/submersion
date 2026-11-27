import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_findings_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A gear item's condition findings dismissed and restored in its page's
/// sitting (issue #4527, phase 3, plan 7).
void main() {
  late AppDatabase db;
  late EquipmentFindingsRepository repository;
  late EditSession<EquipmentItem> session;

  Future<Object?> dismissedAt(String id) async =>
      (await db
              .customSelect(
                "SELECT dismissed_at FROM equipment_findings WHERE id = '$id'",
              )
              .getSingleOrNull())
          ?.data['dismissed_at'];

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    repository = EquipmentFindingsRepository();
    await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: 'g1',
        name: 'Apex',
        type: EquipmentType.regulator,
      ),
    );
    for (final id in ['f1', 'f2']) {
      await db.customStatement(
        'INSERT INTO equipment_findings (id, equipment_id, rule_id, '
        'severity, value, evidence, evidence_fingerprint, engine_version, '
        "created_at) VALUES ('$id', 'g1', 'incidentLinked', 'info', 1.0, "
        '\'{"n":1,"windowStart":0,"windowEnd":0}\', \'fp\', 1, 0)',
      );
    }
    session = EditSession(
      (await EquipmentRepository().getEquipmentById('g1'))!,
    );
    addTearDown(session.dispose);
    holdFindingDismissals(session, <T>(p) => repository as T);
  });
  tearDown(tearDownTestDatabase);

  test('a dismissal set back releases the change', () async {
    final f1 = (await repository.getFindings(
      'g1',
    )).firstWhere((f) => f.id == 'f1');
    setFindingDismissedInSitting(session, f1, dismissed: true);
    expect(session.changedCardIds, {GearItemCardId.conditionFindings.name});

    setFindingDismissedInSitting(session, f1, dismissed: false);

    expect(session.changedCardIds, isEmpty);
    expect(session.hasHeldWrites, isFalse);
  });

  test('the write dismisses what the sitting held, and skips a finding a '
      'recompute deleted', () async {
    final findings = await repository.getFindings('g1');
    for (final f in findings) {
      setFindingDismissedInSitting(session, f, dismissed: true);
    }
    expect(await dismissedAt('f1'), isNull);
    await db.customStatement("DELETE FROM equipment_findings WHERE id = 'f2'");

    await session.runHeldWrites();

    expect(await dismissedAt('f1'), isNotNull);
    expect(await dismissedAt('f2'), isNull);
  });

  test(
    'the sitting\'s view lays its dismissals over the stored findings',
    () async {
      final findings = await repository.getFindings('g1');
      setFindingDismissedInSitting(session, findings.first, dismissed: true);

      final shown = findingsInSitting(session, findings);

      expect(shown.first.dismissedAt, isNotNull);
      expect(shown.last.dismissedAt, isNull);
    },
  );
}
