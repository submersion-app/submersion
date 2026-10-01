import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

import '../../../../helpers/test_database.dart';

void main() {
  final at = DateTime.utc(2026, 3, 9, 8, 15);

  TripCylinderEvent fill({
    String id = 'e1',
    double? o2 = 32,
    double? he,
    double? analyzedO2,
    double? analyzedHe,
    TripCylinderEventKind kind = TripCylinderEventKind.fill,
  }) => TripCylinderEvent(
    id: id,
    tripCylinderId: 'c1',
    kind: kind,
    occurredAt: at,
    pressure: 200,
    o2Percent: o2,
    hePercent: he,
    analyzedO2: analyzedO2,
    analyzedHe: analyzedHe,
    note: 'drive-through',
    createdAt: at,
    updatedAt: at,
  );

  group('passportCopyOf', () {
    test('the id is derived from the trip event and stable', () {
      expect(tripFillPassportCopyId('e1'), tripFillPassportCopyId('e1'));
      expect(tripFillPassportCopyId('e1'), isNot(tripFillPassportCopyId('e2')));
      expect(
        passportCopyOf(fill(), passportId: 'p', equipmentId: 'q').id,
        tripFillPassportCopyId('e1'),
      );
    });

    test('the analysed mix wins over the ordered one', () {
      final copy = passportCopyOf(
        fill(o2: 32, analyzedO2: 31.6, analyzedHe: 0),
        passportId: 'p',
        equipmentId: 'q',
      );
      expect(copy.o2Percent, 31.6);
      expect(copy.hePercent, 0);
    });

    test('the ordered mix stands in, and air when there is none', () {
      final ordered = passportCopyOf(
        fill(o2: 21, he: 35),
        passportId: 'p',
        equipmentId: 'q',
      );
      expect(ordered.o2Percent, 21);
      expect(ordered.hePercent, 35);
      final none = passportCopyOf(
        fill(o2: null),
        passportId: 'p',
        equipmentId: 'q',
      );
      expect(none.o2Percent, 21);
      expect(none.hePercent, 0);
    });

    test('the fill time is the diver\'s wall clock, local', () {
      final copy = passportCopyOf(
        fill(),
        passportId: 'p',
        equipmentId: 'q',
        stationName: 'Dive Friends',
      );
      expect(copy.filledAt, DateTime(2026, 3, 9, 8, 15));
      expect(copy.filledAt.isUtc, isFalse);
      expect(copy.pressureBar, 200);
      expect(copy.stationName, 'Dive Friends');
      expect(copy.notes, 'drive-through');
    });
  });

  group('TripFillPassportCopier', () {
    late TripCylinderRepository slots;
    late CylinderFillRepository fills;
    late TripCylinder owned;
    late TripCylinder rental;
    late String equipmentId;
    final copier = TripFillPassportCopier();

    setUp(() async {
      await setUpTestDatabase();
      slots = TripCylinderRepository();
      fills = CylinderFillRepository();
      final now = DateTime.now();
      final trip = await TripRepository().createTrip(
        Trip(
          id: '',
          name: 'Bonaire',
          startDate: DateTime(2026, 3, 8),
          endDate: DateTime(2026, 3, 14),
          createdAt: now,
          updatedAt: now,
        ),
      );
      equipmentId = (await EquipmentRepository().createEquipment(
        const EquipmentItem(id: '', name: 'My HP100', type: EquipmentType.tank),
      )).id;
      owned = await slots.createCylinder(
        TripCylinder(
          id: '',
          tripId: trip.id,
          equipmentId: equipmentId,
          label: 'My HP100',
          createdAt: now,
          updatedAt: now,
        ),
      );
      rental = await slots.createCylinder(
        TripCylinder(
          id: '',
          tripId: trip.id,
          label: 'Truck 1',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    tearDown(tearDownTestDatabase);

    Future<TripCylinderEvent> save(
      TripCylinder slot, {
      double? analyzedO2,
      TripCylinderEventKind kind = TripCylinderEventKind.fill,
    }) => slots.createEvent(
      fill(
        id: '',
        analyzedO2: analyzedO2,
        kind: kind,
      ).copyWith(tripCylinderId: slot.id),
    );

    test('a fill on an owned cylinder lands on its passport', () async {
      final event = await save(owned, analyzedO2: 31.6);
      await copier.afterSave(event, owned, stationName: 'Dive Friends');

      final copy = await fills.getById(tripFillPassportCopyId(event.id));
      expect(copy, isNotNull);
      expect(copy!.equipmentId, equipmentId);
      expect(
        copy.passportId,
        await CylinderPassportRepository().getPassportId(equipmentId),
      );
      expect(copy.o2Percent, 31.6);
      expect(copy.stationName, 'Dive Friends');
    });

    test('an edit updates the copy in place', () async {
      final event = await save(owned, analyzedO2: 31.6);
      await copier.afterSave(event, owned);
      final edited = event.copyWith(analyzedO2: 32.2);
      await copier.afterSave(edited, owned);

      final copy = await fills.getById(tripFillPassportCopyId(event.id));
      expect(copy!.o2Percent, 32.2);
    });

    test(
      'an edit whose station could not be looked up keeps the name',
      () async {
        final event = await save(owned, analyzedO2: 31.6);
        await copier.afterSave(event, owned, stationName: 'Dive Friends');
        final edited = event.copyWith(analyzedO2: 32.2);

        await copier.afterSave(edited, owned, stationResolved: false);
        var copy = await fills.getById(tripFillPassportCopyId(event.id));
        expect(copy!.o2Percent, 32.2);
        expect(copy.stationName, 'Dive Friends');

        // A lookup that ran and found no station clears it.
        await copier.afterSave(edited, owned);
        copy = await fills.getById(tripFillPassportCopyId(event.id));
        expect(copy!.stationName, isNull);
      },
    );

    test('a fill on a rental slot never reads the passport table', () async {
      final counting = _CountingFills();
      final rentalCopier = TripFillPassportCopier(fills: counting);
      final event = await save(rental);
      await rentalCopier.afterSave(event, rental);
      expect(counting.lookups, 0);
    });

    test('deleting the fill removes the copy', () async {
      final event = await save(owned);
      await copier.afterSave(event, owned);
      await copier.afterDelete(event.id);

      expect(await fills.getById(tripFillPassportCopyId(event.id)), isNull);
    });

    test('a rental slot and an adjustment write no copy', () async {
      final onRental = await save(rental);
      await copier.afterSave(onRental, rental);
      final adjustment = await save(
        owned,
        kind: TripCylinderEventKind.adjustment,
      );
      await copier.afterSave(adjustment, owned);

      expect(await fills.getById(tripFillPassportCopyId(onRental.id)), isNull);
      expect(
        await fills.getById(tripFillPassportCopyId(adjustment.id)),
        isNull,
      );
    });

    test('deleting the slot keeps the copy', () async {
      final event = await save(owned);
      await copier.afterSave(event, owned);
      await slots.deleteCylinder(owned.id);

      expect(await fills.getById(tripFillPassportCopyId(event.id)), isNotNull);
    });
  });
}

/// Counts copy lookups.
class _CountingFills extends CylinderFillRepository {
  int lookups = 0;

  @override
  Future<CylinderFill?> getById(String id) {
    lookups++;
    return super.getById(id);
  }
}
