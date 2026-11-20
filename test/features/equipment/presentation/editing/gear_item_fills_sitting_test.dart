import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/twin_fill_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_fills_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_twin_set_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A cylinder's fills held in its gear item's sitting (issue #4527, phase
/// 3, plan 7).
void main() {
  late AppDatabase db;
  late CylinderPassportRepository passports;
  late CylinderFillRepository fills;
  late EditSession<EquipmentItem> session;
  late String mine;
  final at = DateTime(2026, 3, 3, 10);
  const tag = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  CylinderFill fill({String passportId = '', String? id}) => CylinderFill(
    id: id ?? '',
    passportId: passportId.isEmpty ? mine : passportId,
    equipmentId: 'a',
    filledAt: at,
    o2Percent: 32,
    pressureBar: 220,
    createdAt: at,
    updatedAt: at,
  );

  Future<List<CylinderFill>> fillsOf(String id) async => fills.getForCylinder(
    passportId: await passports.getPassportId(id),
    equipmentId: id,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    passports = CylinderPassportRepository();
    fills = CylinderFillRepository();
    final items = EquipmentRepository();
    for (final id in ['a', 'b']) {
      await items.createEquipment(
        EquipmentItem(id: id, name: 'Tank $id', type: EquipmentType.tank),
      );
    }
    await items.createEquipment(
      const EquipmentItem(
        id: 'old',
        name: 'Old',
        type: EquipmentType.tank,
        status: EquipmentStatus.retired,
        isActive: false,
      ),
    );
    await passports.assignPassportId(equipmentId: 'old', passportId: tag);
    mine = await passports.ensurePassportId('a');
    await fills.create(fill(id: 'f0'));
    session = EditSession((await items.getEquipmentById('a'))!);
    addTearDown(session.dispose);
    await gearItemFillsList.currentOrRead(session);
  });
  tearDown(tearDownTestDatabase);

  test(
    'a fill logged in the sitting is written at Save under its id',
    () async {
      final held = holdLoggedFill(session, fill())!;
      expect(session.changedCardIds, {GearItemCardId.passportFills.name});
      expect(await fillsOf('a'), hasLength(1));
      expect(newFillsOf(session), [held]);

      await db.transaction(session.runHeldWrites);

      expect((await fillsOf('a')).map((f) => f.id), contains(held.id));
    },
  );

  test('a new twin fill writes both fills with one filledTogetherId', () async {
    await CylinderPairingRepository().createPairing(
      cylinderAId: 'a',
      cylinderBId: 'b',
      pairedOn: DateTime(2026),
    );
    holdLoggedFill(session, fill(), twinPartnerId: 'b');

    await db.transaction(session.runHeldWrites);

    final ours = (await fillsOf('a')).firstWhere((f) => f.id != 'f0');
    final theirs = (await fillsOf('b')).single;
    expect(ours.filledTogetherId, isNotNull);
    expect(theirs.filledTogetherId, ours.filledTogetherId);
  });

  group('a twin fill stored', () {
    late CylinderFill stored;

    setUp(() async {
      final saved = await TwinFillService().recordTwinFill(
        fill(id: 'f1'),
        partnerEquipmentId: 'b',
      );
      stored = saved.fill;
      await gearItemFillsList.load(session);
    });

    test('deleted with its tied fill, both go at Save', () async {
      holdDeletedFill(session, stored, tiedToo: true);
      expect(await fillsOf('b'), hasLength(1));

      await db.transaction(session.runHeldWrites);

      expect((await fillsOf('a')).map((f) => f.id), ['f0']);
      expect(await fillsOf('b'), isEmpty);
    });

    test('an edit applied to the tied fill updates both', () async {
      holdEditedFill(session, stored.copyWith(o2Percent: 36), toTied: true);

      await db.transaction(session.runHeldWrites);

      expect((await fillsOf('b')).single.o2Percent, 36);
    });
  });

  // Review Focus 1: a fill carries the passport id the sitting shows, and
  // the link re-keys the rest, whatever the order.
  group('a tag linked and a fill logged in one sitting', () {
    void linkTag() =>
        holdPassportTag(session, tag, stored: mine, repository: passports);
    void logFill() => holdLoggedFill(
      session,
      fill(passportId: passportIdInSitting(session, mine)!),
    );

    for (final (name, steps) in [
      ('tag first', [linkTag, logFill]),
      ('fill first', [logFill, linkTag]),
    ]) {
      test('$name: every fill ends on the new id', () async {
        for (final step in steps) {
          step();
        }

        await db.transaction(session.runHeldWrites);

        expect(await passports.getPassportId('a'), tag);
        expect(await passports.getPassportId('old'), isNull);
        final after = await fillsOf('a');
        expect(after, hasLength(2));
        expect(after.map((f) => f.passportId).toSet(), {tag});
      });
    }
  });

  // Review Focus 4: a tag scan imports the tag's fill before the passport
  // opens, outside any sitting; the sitting's entry holds only its own.
  test('a fill imported before the sitting is its own entry; the sitting\'s '
      'entry holds only the fill logged in it', () async {
    final changeLog = ChangeLogRepository();
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_events');
    await db.customStatement('DELETE FROM change_log_operations');
    await fills.create(fill(id: 'imported'));
    await changeLog.settleAll();
    session = EditSession((await EquipmentRepository().getEquipmentById('a'))!);
    addTearDown(session.dispose);
    await gearItemFillsList.currentOrRead(session);
    final logged = holdLoggedFill(session, fill())!;

    await GearItemEditSaveService(
      EquipmentRepository(),
      GearPhotoRepository(),
    ).save(
      equipmentId: 'a',
      apply: (stored) => gearItemToSave(stored, session.applyTo(stored)),
      changedCardIds: session.changedCardIds,
      alsoWrite: session.runHeldWrites,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    await changeLog.settleAll();

    final ops = await db
        .customSelect('SELECT id, label FROM change_log_operations')
        .get();
    expect(ops, hasLength(2));
    final sitting = ops.singleWhere(
      (o) => o.data['label'] == 'record_edit:equipment:a:passportFills',
    );
    final events = await db
        .customSelect(
          'SELECT record_id FROM change_log_events WHERE operation_id = ? '
          "AND table_name = 'cylinder_fills'",
          variables: [Variable<String>(sitting.data['id']! as String)],
        )
        .get();
    expect(events.map((e) => e.data['record_id']), [logged.id]);
  });

  test('a fill logged under a tag linked in the sitting, after the link is '
      'set back, is written under the cylinder\'s own id', () async {
    holdPassportTag(session, tag, stored: mine, repository: passports);
    holdLoggedFill(session, fill(passportId: tag));
    holdPassportTag(session, mine, stored: mine, repository: passports);

    await db.transaction(session.runHeldWrites);

    expect(await passports.getPassportId('a'), mine);
    expect((await fillsOf('a')).map((f) => f.passportId).toSet(), {mine});
  });

  test('a stored fill edited after a tag is linked in the sitting stays on '
      'the new id', () async {
    holdPassportTag(session, tag, stored: mine, repository: passports);
    final f0 = gearItemFillsList.current(session)!.single;
    holdEditedFill(session, f0.copyWith(o2Percent: 36));

    await db.transaction(session.runHeldWrites);

    final after = (await fillsOf('a')).single;
    expect(after.o2Percent, 36);
    expect(after.passportId, tag);
  });

  test(
    'the fill a Save offers for the tag carries its twin partner\'s',
    () async {
      final held = holdLoggedFill(session, fill(), twinPartnerId: 'b')!;
      await db.transaction(session.runHeldWrites);

      final logged = await savedLoggedFill(fills, held.id);

      expect(logged!.fill.id, held.id);
      expect(logged.partnerFill?.equipmentId, 'b');
    },
  );

  // Review Focus 5: a twin set made in the sitting is the partner of a
  // fill logged after it.
  test('a pairing made, then a twin fill logged: the pairing is written '
      'before both fills', () async {
    final pairings = CylinderPairingRepository();
    await SittingPairingWrites(
      session,
      () async => const [],
      pairings,
    ).createPairing(
      cylinderAId: 'a',
      cylinderBId: 'b',
      pairedOn: DateTime(2026),
    );
    final partner = sittingPairingOn(session)(const [], at);
    expect(partner?.partnerOf('a'), 'b');
    holdLoggedFill(session, fill(), twinPartnerId: partner!.partnerOf('a'));

    await db.transaction(session.runHeldWrites);

    expect((await pairings.getAll()).single.cylinderBId, 'b');
    expect(await fillsOf('b'), hasLength(1));
  });
}
