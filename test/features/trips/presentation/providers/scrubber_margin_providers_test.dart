import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide Trip, ServiceRecord;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// One margin per active rebreather, computed as of the trip start from
/// the repack record, the loop dives since it, and the diver's history.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  Future<void> ccrDive(
    String id,
    DateTime at,
    String equipmentId, {
    int runtime = 3600,
    double? scrubber,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: at.millisecondsSinceEpoch,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(diveMode: const Value('ccr'), runtime: Value(runtime)),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: id, equipmentId: equipmentId),
        );
    if (scrubber != null) {
      await db
          .into(db.diveSensorSummaries)
          .insert(
            DiveSensorSummariesCompanion.insert(
              diveId: id,
              engineVersion: 1,
              sourceUpdatedAt: 1,
              computedAt: 1,
            ).copyWith(scrubberConsumedMinutes: Value(scrubber)),
          );
    }
  }

  Future<Trip> trip(String name, DateTime start, DateTime end) =>
      TripRepository().createTrip(
        Trip(
          id: '',
          name: name,
          startDate: start,
          endDate: end,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

  test(
    'reads rating, repack, loop dives and history as of the start',
    () async {
      final ccr = await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: '',
          name: 'CCR',
          type: EquipmentType.rebreather,
          attributes: [
            EquipmentAttribute(
              id: '',
              equipmentId: '',
              key: 'scrubber_duration_h',
              valueNum: 5,
            ),
          ],
        ),
      );
      await ServiceRecordRepository().createRecord(
        ServiceRecord(
          id: '',
          equipmentId: ccr.id,
          serviceCategory: ServiceCategory.values.first,
          serviceKindId: 'scrubber-repack',
          serviceDate: DateTime(2026, 2, 1),
          currency: 'USD',
          notes: '',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await ccrDive('before', DateTime(2026, 1, 15), ccr.id, scrubber: 30);
      await ccrDive('m1', DateTime(2026, 3, 10), ccr.id, scrubber: 40);
      await ccrDive('m2', DateTime(2026, 3, 20), ccr.id, runtime: 3000);
      final june = await trip(
        'June',
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 5),
      );
      final march = await trip(
        'March',
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
      );

      final margins = await container.read(
        tripScrubberMarginsProvider(june.id).future,
      );
      final m = margins.single;
      expect(m.item.id, ccr.id);
      expect(m.ratedMinutes, 300);
      // 40 from the summary plus 50 minutes of runtime; the January dive
      // predates the repack.
      expect(m.consumedMinutes, 90);
      expect(m.remainingBefore, 210);
      // No earlier trips: 5 calendar days at the default 2 per day.
      expect(m.expectedDives, 10);
      expect(m.expectedDivesN, 0);
      // Summary figures of every CCR dive before June: 40 and 30.
      expect(m.minutesPerDive, 35);
      expect(m.minutesPerDiveN, 2);
      expect(m.caution, isTrue);

      final past = await container.read(
        tripScrubberMarginsProvider(march.id).future,
      );
      // As of 1 March: nothing consumed since the repack, one history dive.
      expect(past.single.consumedMinutes, 0);
      expect(past.single.minutesPerDive, 30);
      expect(past.single.minutesPerDiveN, 1);
    },
  );

  test('a repack on the trip start date is the anchor', () async {
    // Service dates come from a date picker, so a repack logged on the
    // day the trip starts is a real case. Excluding it would charge the
    // trip for every loop dive before a scrubber that was just packed.
    final ccr = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        name: 'CCR',
        type: EquipmentType.rebreather,
        attributes: [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'scrubber_duration_h',
            valueNum: 5,
          ),
        ],
      ),
    );
    await ServiceRecordRepository().createRecord(
      ServiceRecord(
        id: '',
        equipmentId: ccr.id,
        serviceCategory: ServiceCategory.values.first,
        serviceKindId: 'scrubber-repack',
        serviceDate: DateTime(2026, 2, 1),
        currency: 'USD',
        notes: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await ccrDive('older', DateTime(2026, 1, 15), ccr.id, scrubber: 30);
    final sameDay = await trip(
      'SameDay',
      DateTime(2026, 2, 1),
      DateTime(2026, 2, 5),
    );

    final margins = await container.read(
      tripScrubberMarginsProvider(sameDay.id).future,
    );
    // The January dive predates the repack, so nothing is consumed.
    expect(margins.single.consumedMinutes, 0);
    expect(margins.single.remainingBefore, 300);
  });

  test('a diver with no active rebreather gets an empty list', () async {
    await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final t = await trip('T', DateTime(2026, 6, 1), DateTime(2026, 6, 5));
    expect(
      await container.read(tripScrubberMarginsProvider(t.id).future),
      isEmpty,
    );
  });

  test('an unknown trip gets an empty list', () async {
    expect(
      await container.read(tripScrubberMarginsProvider('nope').future),
      isEmpty,
    );
  });
}
