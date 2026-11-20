import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_vessel_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../pages/trip_detail_page_unlock_harness.dart';

/// A liveaboard's vessel held in the trip's sitting (issue #4527, phase 3).
void main() {
  test('a trip with no details reads none', () async {
    final list = tripVesselDetails(FakeVessels());
    final session = EditSession<Trip>(liveaboard);

    await list.load(session);

    expect(list.current(session), isEmpty);
    expect(tripVesselInSitting(list, session), isNull);
  });

  test('a changed vessel is written with createOrUpdate at Save', () async {
    final vessels = FakeVessels(mvBlue);
    final list = tripVesselDetails(vessels);
    final session = EditSession<Trip>(liveaboard);
    await list.load(session);

    list.set(session, [mvBlue.copyWith(cabinType: 'Deluxe')]);
    expect(vessels.writes, isEmpty);
    await session.runHeldWrites();

    expect(vessels.writes.single.cabinType, 'Deluxe');
    expect(session.changedCardIds, {'vessel'});
  });

  test(
    'nothing is written for a trip that is no longer a liveaboard',
    () async {
      final vessels = FakeVessels(mvBlue);
      final list = tripVesselDetails(vessels);
      final session = EditSession<Trip>(liveaboard);
      await list.load(session);
      list.set(session, [mvBlue.copyWith(cabinType: 'Deluxe')]);

      session.set(tripTypeField, TripType.resort);
      await session.runHeldWrites();

      expect(vessels.writes, isEmpty);
    },
  );

  test('a liveaboard needs a vessel name; another type does not', () async {
    final list = tripVesselDetails(FakeVessels());
    final session = EditSession<Trip>(liveaboard);
    await list.load(session);

    expect(tripVesselValid(list, session), isFalse);
    list.set(session, [tripVesselDraft('t1').copyWith(vesselName: 'MV Red')]);
    expect(tripVesselValid(list, session), isTrue);

    final resort = EditSession<Trip>(redSea);
    await list.load(resort);
    expect(tripVesselValid(list, resort), isTrue);
  });

  test('a liveaboard whose vessel could not be read cannot be saved', () async {
    final list = tripVesselDetails(FakeVessels(mvBlue)..failRead = true);
    final session = EditSession<Trip>(liveaboard);
    await list.load(session);

    expect(list.failed(session), isTrue);
    expect(tripVesselValid(list, session), isFalse);
  });
}
