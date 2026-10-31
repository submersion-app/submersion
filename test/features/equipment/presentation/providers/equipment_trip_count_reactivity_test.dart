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
import '../../../../helpers/wait_until.dart';

/// The item page's Trips row reads dives through their gear and tank links,
/// neither of which writes `equipment` or `trips`, so it has to tick on those
/// tables itself (issue #4017).
void main() {
  late AppDatabase db;
  late EquipmentItem item;
  late ProviderContainer container;

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

  Future<void> link(String diveId, [String? equipmentId]) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(
          diveId: diveId,
          equipmentId: equipmentId ?? item.id,
        ),
      );

  /// Dive D moves to trip B, then a new dive E takes the item on trip A: no
  /// write to `equipment` or `trips` in either step.
  Future<void> moveDiveAndAddAnother() async {
    await TripRepository().assignDiveToTrip('D', 'B');
    await addDive('E', 'A');
    await link('E');
  }

  /// Runs [write] and returns once its debounced dive tick has fired, for the
  /// cases that need that tick to land at a known moment, not eventually.
  Future<void> tickDelivered(Future<void> Function() write) async {
    final tick = DiveRepository().watchTables(const {
      'dives',
      'dive_equipment',
      'dive_tanks',
    }).first;
    await write();
    await tick;
  }

  Future<int> tripCount() =>
      container.read(equipmentTripCountProvider(item.id).future);

  Future<Set<String>> tripIds() async =>
      (await container.read(equipmentTripIdsProvider(item.id).future)).toSet();

  /// Listens to both Trips families as the item page does, until the test
  /// closes the subscriptions or ends.
  List<ProviderSubscription<Object?>> openPage() {
    final page = <ProviderSubscription<Object?>>[
      container.listen(equipmentTripCountProvider(item.id), (_, _) {}),
      container.listen(equipmentTripIdsProvider(item.id), (_, _) {}),
    ];
    addTearDown(() {
      for (final subscription in page) {
        subscription.close();
      }
    });
    return page;
  }

  Future<void> rowReads(Set<String> trips) async {
    await waitUntil(() async => await tripCount() == trips.length);
    await waitUntil(() async => (await tripIds()).containsAll(trips));
    expect(await tripIds(), trips);
  }

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
    openPage();
    await rowReads({'A'});

    await moveDiveAndAddAnother();

    await rowReads({'A', 'B'});
  });

  test('taking the item off its dive refreshes an open page', () async {
    openPage();
    await rowReads({'A'});

    await (db.delete(
      db.diveEquipment,
    )..where((t) => t.diveId.equals('D'))).go();

    await waitUntil(() async => await tripCount() == 0);
    await waitUntil(() async => (await tripIds()).isEmpty);
  });

  test('the changes reach a page opened again after them', () async {
    final page = openPage();
    await rowReads({'A'});
    for (final subscription in page) {
      subscription.close();
    }

    await tickDelivered(moveDiveAndAddAnother);

    openPage();
    await rowReads({'A', 'B'});
  });

  test('the changes reach a page paused behind another route', () async {
    final page = openPage();
    await rowReads({'A'});
    for (final subscription in page) {
      subscription.pause();
    }

    await tickDelivered(moveDiveAndAddAnother);

    for (final subscription in page) {
      subscription.resume();
    }
    await rowReads({'A', 'B'});
  });

  test('a tank naming the item on another trip refreshes the row', () async {
    openPage();
    await rowReads({'A'});

    // Let the new dive's own tick pass, so only the tank write can refresh.
    await tickDelivered(() => addDive('T', 'B'));
    expect(await tripCount(), 1);

    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank',
            diveId: 'T',
          ).copyWith(equipmentId: Value(item.id)),
        );

    await rowReads({'A', 'B'});
  });

  test('folding another item in brings its trips to the survivor', () async {
    final duplicate = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Old BCD', type: EquipmentType.bcd),
    );
    await addDive('other', 'B');
    await link('other', duplicate.id);
    openPage();
    await rowReads({'A'});

    // The fold moves gear links in raw SQL, which Drift's streams cannot see.
    await EquipmentItemFold().fold(fromId: duplicate.id, intoId: item.id);

    await rowReads({'A', 'B'});
  });
}
