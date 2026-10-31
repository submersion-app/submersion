import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_item_fold.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/test_database.dart';

/// The item page's Trips row reads dives through their gear and tank links,
/// neither of which writes `equipment` or `trips`, so it has to tick on those
/// tables itself (issue #4017).
void main() {
  late AppDatabase db;
  late EquipmentItem item;
  late ProviderContainer container;

  /// Long enough for a debounced dive tick to fire and the refresh to settle.
  final settle = DiveRepository.changeTickDebounce * 2;

  Future<void> addTrip(String id) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: 1,
          endDate: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> addDive(String id, String tripId) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 1,
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(tripId: Value(tripId)),
      );

  Future<void> link(String diveId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: item.id),
      );

  /// Dive D moves to trip B, then a new dive E takes the item on trip A: no
  /// write to `equipment` or `trips` in either step.
  Future<void> moveDiveAndAddAnother() async {
    await TripRepository().assignDiveToTrip('D', 'B');
    await addDive('E', 'A');
    await link('E');
  }

  Future<int> tripCount() =>
      container.read(equipmentTripCountProvider(item.id).future);

  Future<Set<String>> tripIds() async =>
      (await container.read(equipmentTripIdsProvider(item.id).future)).toSet();

  setUp(() async {
    db = await setUpTestDatabase();
    item = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'BCD', type: EquipmentType.bcd),
    );
    await addTrip('A');
    await addTrip('B');
    await addDive('D', 'A');
    await link('D');
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('moving a dive and linking another refreshes an open page', () async {
    final count = container.listen(
      equipmentTripCountProvider(item.id),
      (_, _) {},
    );
    addTearDown(count.close);
    final ids = container.listen(equipmentTripIdsProvider(item.id), (_, _) {});
    addTearDown(ids.close);
    expect(await tripCount(), 1);
    expect(await tripIds(), {'A'});

    await moveDiveAndAddAnother();
    await Future<void>.delayed(settle);

    expect(await tripCount(), 2);
    expect(await tripIds(), {'A', 'B'});
  });

  test('the changes reach a page opened again after them', () async {
    final count = container.listen(
      equipmentTripCountProvider(item.id),
      (_, _) {},
    );
    final ids = container.listen(equipmentTripIdsProvider(item.id), (_, _) {});
    expect(await tripCount(), 1);
    expect(await tripIds(), {'A'});
    count.close();
    ids.close();

    await moveDiveAndAddAnother();
    await Future<void>.delayed(settle);

    final reopenedCount = container.listen(
      equipmentTripCountProvider(item.id),
      (_, _) {},
    );
    addTearDown(reopenedCount.close);
    final reopenedIds = container.listen(
      equipmentTripIdsProvider(item.id),
      (_, _) {},
    );
    addTearDown(reopenedIds.close);
    await Future<void>.delayed(Duration.zero);

    expect(await tripCount(), 2);
    expect(await tripIds(), {'A', 'B'});
  });

  test('the changes reach a page paused behind another route', () async {
    final count = container.listen(
      equipmentTripCountProvider(item.id),
      (_, _) {},
    );
    addTearDown(count.close);
    final ids = container.listen(equipmentTripIdsProvider(item.id), (_, _) {});
    addTearDown(ids.close);
    expect(await tripCount(), 1);
    expect(await tripIds(), {'A'});
    count.pause();
    ids.pause();

    await moveDiveAndAddAnother();
    await Future<void>.delayed(settle);
    count.resume();
    ids.resume();
    await Future<void>.delayed(Duration.zero);

    expect(await tripCount(), 2);
    expect(await tripIds(), {'A', 'B'});
  });

  test('a tank naming the item on another trip refreshes the row', () async {
    final count = container.listen(
      equipmentTripCountProvider(item.id),
      (_, _) {},
    );
    addTearDown(count.close);
    expect(await tripCount(), 1);

    await addDive('T', 'B');
    await Future<void>.delayed(settle);
    expect(await tripCount(), 1);

    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank',
            diveId: 'T',
          ).copyWith(equipmentId: Value(item.id)),
        );
    await Future<void>.delayed(settle);

    expect(await tripCount(), 2);
  });

  test('folding another item in brings its trips to the survivor', () async {
    final duplicate = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Old BCD', type: EquipmentType.bcd),
    );
    await addDive('other', 'B');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'other',
            equipmentId: duplicate.id,
          ),
        );
    final count = container.listen(
      equipmentTripCountProvider(item.id),
      (_, _) {},
    );
    addTearDown(count.close);
    expect(await tripCount(), 1);

    // The fold moves gear links in raw SQL, which Drift's streams cannot see.
    await EquipmentItemFold().fold(fromId: duplicate.id, intoId: item.id);
    await Future<void>.delayed(settle);

    expect(await tripCount(), 2);
  });
}
