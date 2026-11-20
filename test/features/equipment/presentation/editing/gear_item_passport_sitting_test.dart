import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../helpers/test_database.dart';

/// A passport's tag link and trip packing, held in the gear item's sitting
/// (issue #4527, phase 3, plan 7).
void main() {
  late AppDatabase db;
  late CylinderPassportRepository passports;
  late EquipmentRepository items;
  late EditSession<EquipmentItem> session;
  const tag = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    passports = CylinderPassportRepository();
    items = EquipmentRepository();
    await items.createEquipment(
      const EquipmentItem(id: 'c1', name: 'New 12', type: EquipmentType.tank),
    );
    await items.createEquipment(
      const EquipmentItem(
        id: 'old',
        name: 'Old 12',
        type: EquipmentType.tank,
        status: EquipmentStatus.retired,
        isActive: false,
      ),
    );
    await passports.assignPassportId(equipmentId: 'old', passportId: tag);
    for (final trip in ['t1', 't2']) {
      await db.customStatement(
        'INSERT INTO trips (id, name, start_date, end_date, created_at, '
        "updated_at) VALUES ('$trip', '$trip', 0, 0, 0, 0)",
      );
    }
    await TripEquipmentRepository().pack('t1', ['c1']);
    session = EditSession((await items.getEquipmentById('c1'))!);
    addTearDown(session.dispose);
  });
  tearDown(tearDownTestDatabase);

  group('the tag link', () {
    test('held and set back, it is no change', () {
      holdPassportTag(session, tag, stored: null, repository: passports);
      expect(session.changedCardIds, {GearItemCardId.passportTag.name});
      expect(passportIdInSitting(session, null), tag);

      holdPassportTag(session, 'mine', stored: 'mine', repository: passports);

      expect(session.hasHeldWrites, isFalse);
      expect(passportIdInSitting(session, 'mine'), 'mine');
    });

    test('written at Save, it takes the tag from the retired item', () async {
      holdPassportTag(session, tag, stored: null, repository: passports);
      expect(await passports.getPassportId('c1'), isNull);

      await db.transaction(session.runHeldWrites);

      expect(await passports.getPassportId('c1'), tag);
      expect(await passports.getPassportId('old'), isNull);
    });

    test(
      'a tag a fitted item took meanwhile refuses the Save, naming it',
      () async {
        holdPassportTag(session, tag, stored: null, repository: passports);
        // Back in service, the old cylinder keeps its tag.
        final old = (await items.getEquipmentById('old'))!;
        await items.updateEquipment(
          old.copyWith(status: EquipmentStatus.active, isActive: true),
        );

        Object? refused;
        try {
          await db.transaction(session.runHeldWrites);
        } on RecordSittingRefusal catch (e) {
          refused = e;
        }

        expect(
          (refused! as RecordSittingRefusal).message(AppLocalizationsEn()),
          AppLocalizationsEn().passport_tag_linkInUse('Old 12'),
        );
        expect(await passports.getPassportId('c1'), isNull);
      },
    );

    test(
      'the holder check ignores unfitted holders and the item itself',
      () async {
        expect(
          await passports.fittedHolderOf(tag, exceptEquipmentId: 'c1'),
          isNull,
        );
        await passports.assignPassportId(equipmentId: 'c1', passportId: tag);
        expect(
          await passports.fittedHolderOf(tag, exceptEquipmentId: 'c1'),
          isNull,
        );
        expect(
          await passports.fittedHolderOf(tag, exceptEquipmentId: 'old'),
          'c1',
        );
      },
    );
  });

  group('trip packing', () {
    setUp(() => gearItemTripsList.currentOrRead(session));

    test('packing and unpacking back to stored writes nothing', () {
      unpackFromTripInSitting(session, 't1');
      expect(session.changedCardIds, {GearItemCardId.passportTrip.name});

      packForTripInSitting(session, 't1');

      expect(session.hasHeldWrites, isFalse);
    });

    test('written at Save, it packs and unpacks', () async {
      unpackFromTripInSitting(session, 't1');
      packForTripInSitting(session, 't2');
      expect(await TripEquipmentRepository().tripIdsForEquipment('c1'), {'t1'});

      await db.transaction(session.runHeldWrites);

      expect(await TripEquipmentRepository().tripIdsForEquipment('c1'), {'t2'});
    });
  });
}
