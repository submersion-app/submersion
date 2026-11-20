import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_twin_set_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A cylinder's twin set pairings held in its gear item's sitting (issue
/// #4527, phase 3, plan 7).
void main() {
  CylinderPairing pairing(String id, String a, String b, DateTime on) =>
      CylinderPairing(
        id: id,
        cylinderAId: a,
        cylinderBId: b,
        pairedOn: on,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
  final day = DateTime.utc(2026, 3, 3);

  group('the steps, applied as the repository would', () {
    test('a replace ends a clash that started earlier and deletes one that '
        'started the same day', () {
      final stored = [
        pairing('ab', 'A', 'B', DateTime.utc(2025, 1, 1)),
        pairing('cd', 'C', 'D', day),
      ];

      final after = applyPairingStep(
        stored,
        HeldPairingCreate(
          id: 'new',
          cylinderAId: 'A',
          cylinderBId: 'C',
          pairedOn: day,
          replace: true,
        ),
      );

      expect(after.firstWhere((p) => p.id == 'ab').unpairedOn, day);
      expect(after.any((p) => p.id == 'cd'), isFalse);
      expect(after.firstWhere((p) => p.id == 'new').isOpen, isTrue);
    });

    test('a clash without replace throws, as the repository does', () {
      expect(
        () => applyPairingStep(
          [pairing('ab', 'A', 'B', DateTime.utc(2025, 1, 1))],
          HeldPairingCreate(
            id: 'new',
            cylinderAId: 'A',
            cylinderBId: 'C',
            pairedOn: day,
          ),
        ),
        throwsA(isA<PairingClash>()),
      );
    });

    test('a step the stored pairings now refuse is left out of the view', () {
      final steps = [
        HeldPairingCreate(
          id: 'new',
          cylinderAId: 'A',
          cylinderBId: 'B',
          pairedOn: day,
        ),
      ];

      final shown = pairingsInSitting([pairing('bc', 'B', 'C', day)], steps);

      expect(shown.map((p) => p.id), ['bc']);
    });
  });

  group('held in a sitting', () {
    late AppDatabase db;
    late CylinderPairingRepository repository;
    late EditSession<EquipmentItem> session;

    setUp(() async {
      db = await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
      repository = CylinderPairingRepository();
      for (final id in ['A', 'B', 'C']) {
        await EquipmentRepository().createEquipment(
          EquipmentItem(id: id, name: 'Tank $id', type: EquipmentType.tank),
        );
      }
      session = EditSession(
        (await EquipmentRepository().getEquipmentById('A'))!,
      );
      addTearDown(session.dispose);
    });
    tearDown(tearDownTestDatabase);

    SittingPairingWrites writes() =>
        SittingPairingWrites(session, () async => const [], repository);

    test('deleting a pairing made in the sitting takes the making back, and '
        'releases the change', () async {
      final made = await writes().createPairing(
        cylinderAId: 'A',
        cylinderBId: 'B',
        pairedOn: day,
      );
      expect(session.changedCardIds, {GearItemCardId.twinSet.name});

      await writes().deletePairing(made.id);

      expect(heldPairingSteps(session), isEmpty);
      expect(session.hasHeldWrites, isFalse);
    });

    test('ending a pairing made in the sitting is written with it', () async {
      final made = await writes().createPairing(
        cylinderAId: 'A',
        cylinderBId: 'B',
        pairedOn: day,
      );
      await writes().endPairing(made.id, DateTime.utc(2026, 4, 1));

      await db.transaction(session.runHeldWrites);

      final stored = await repository.getAll();
      expect(stored.single.cylinderBId, 'B');
      expect(stored.single.unpairedOn, DateTime.utc(2026, 4, 1));
    });

    // A link made before the stored pairings load waits for them, so a
    // clash with one of them is still met now (and the diver asked), not
    // only at Save.
    test(
      'a pairing made while the stored pairings load meets their clash',
      () async {
        final stored = await repository.createPairing(
          cylinderAId: 'A',
          cylinderBId: 'B',
          pairedOn: DateTime.utc(2025, 1, 1),
        );
        final loading = Completer<List<CylinderPairing>>();
        final making = SittingPairingWrites(
          session,
          () => loading.future,
          repository,
        ).createPairing(cylinderAId: 'A', cylinderBId: 'C', pairedOn: day);
        loading.complete([stored]);

        await expectLater(making, throwsA(isA<PairingClash>()));
        expect(heldPairingSteps(session), isEmpty);
      },
    );

    // Call 3: a pairing is logged under its first cylinder, and a sitting
    // is pinned to the item it edits.
    test(
      'a pairing ended from its second cylinder\'s page is that page\'s '
      'entry, rooted at the first, and reverting it reopens the pairing',
      () async {
        final stored = await repository.createPairing(
          cylinderAId: 'A',
          cylinderBId: 'B',
          pairedOn: DateTime.utc(2025, 1, 1),
        );
        final changeLog = ChangeLogRepository();
        await changeLog.settleAll();
        await clearLog(db);
        await db.customStatement('DELETE FROM change_log_operations');
        final items = EquipmentRepository();
        final onB = EditSession((await items.getEquipmentById('B'))!);
        addTearDown(onB.dispose);
        await SittingPairingWrites(
          onB,
          () async => [stored],
          repository,
        ).endPairing(stored.id, day);

        await GearItemEditSaveService(items, GearPhotoRepository()).save(
          equipmentId: 'B',
          apply: (s) => gearItemToSave(s, onB.applyTo(s)),
          changedCardIds: onB.changedCardIds,
          alsoWrite: onB.runHeldWrites,
          alsoWriteIsAChange: onB.hasHeldChanges,
        );
        await changeLog.settleAll();

        final ops = await db
            .customSelect('SELECT id, label FROM change_log_operations')
            .get();
        expect(ops.single.data['label'], 'record_edit:equipment:B:twinSet');
        final events = await db
            .customSelect(
              'SELECT root_id FROM change_log_events '
              "WHERE table_name = 'cylinder_pairings'",
            )
            .get();
        expect(events.single.data['root_id'], 'A');

        final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
        await revert.execute(
          await revert.planOperation(ops.single.data['id']! as String),
        );
        expect((await repository.getAll()).single.isOpen, isTrue);
      },
    );

    test('a partner another device paired meanwhile refuses the Save, and '
        'the transaction writes nothing', () async {
      await writes().createPairing(
        cylinderAId: 'A',
        cylinderBId: 'B',
        pairedOn: day,
      );
      // Another device paired B with C before this Save.
      await repository.createPairing(
        cylinderAId: 'C',
        cylinderBId: 'B',
        pairedOn: DateTime.utc(2026, 1, 1),
      );

      Object? refused;
      try {
        await db.transaction(session.runHeldWrites);
      } on RecordSittingRefusal catch (e) {
        refused = e;
      }

      expect(refused, isA<RecordSittingRefusal>());
      final message = (refused! as RecordSittingRefusal).message(
        AppLocalizationsEn(),
      );
      expect(message, contains('Tank C'));
      final stored = await repository.getAll();
      expect(stored.single.cylinderAId, 'C');
      expect(heldPairingSteps(session), hasLength(1));
    });
  });
}
