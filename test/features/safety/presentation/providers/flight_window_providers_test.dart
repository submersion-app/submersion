import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/dst_transition.dart';
import '../../../../helpers/mock_providers.dart';

class _StubTripRepository extends Fake implements TripRepository {
  final domain.Trip? trip;

  _StubTripRepository(this.trip);

  @override
  Stream<void> watchTripsChanges() => const Stream.empty();

  @override
  Future<domain.Trip?> getTripById(String id) async => trip;
}

class _StubDiveRepository extends Fake implements DiveRepository {
  List<NoFlyDiveInput> inputs;
  final Stream<void> changes;

  _StubDiveRepository(this.inputs, {this.changes = const Stream.empty()});

  @override
  Stream<void> watchDivesChanges() => changes;

  @override
  Stream<void> watchDiveListChanges() => const Stream.empty();

  @override
  Future<List<NoFlyDiveInput>> getNoFlyDiveInputs({
    required DateTime since,
    String? diverId,
  }) async {
    return inputs;
  }
}

domain.Trip _trip({DateTime? returnFlightAt}) {
  final now = NoFlyService.wallClockNowUtc();
  return domain.Trip(
    id: 't1',
    name: 'Trip',
    startDate: now.subtract(const Duration(days: 3)),
    endDate: now.add(const Duration(days: 3)),
    returnFlightAt: returnFlightAt,
    createdAt: now,
    updatedAt: now,
  );
}

ProviderContainer _container({
  required domain.Trip? trip,
  required List<NoFlyDiveInput> dives,
  String? diverId,
  _StubDiveRepository? diveRepository,
}) {
  final diverNotifier = MockCurrentDiverIdNotifier();
  if (diverId != null) diverNotifier.setCurrentDiver(diverId);
  final container = ProviderContainer(
    overrides: [
      tripRepositoryProvider.overrideWithValue(_StubTripRepository(trip)),
      diveRepositoryProvider.overrideWithValue(
        diveRepository ?? _StubDiveRepository(dives),
      ),
      currentDiverIdProvider.overrideWith((ref) => diverNotifier),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('open window with repetitive floor even before any dives', () async {
    final flightAt = NoFlyService.wallClockNowUtc().add(
      const Duration(hours: 24),
    );
    final container = _container(
      trip: _trip(returnFlightAt: flightAt),
      dives: const [],
      diverId: 'diver-1',
    );

    final status = await container.read(tripFlightWindowProvider('t1').future);

    expect(status!.state, FlightWindowState.open);
    expect(status.category, NoFlyCategory.repetitive);
    expect(
      status.deadline,
      fromWallClockUtc(flightAt).toUtc().subtract(const Duration(hours: 18)),
    );
  });

  test('a deco dive in the lookback escalates to the deco interval', () async {
    final now = NoFlyService.wallClockNowUtc();
    final flightAt = now.add(const Duration(hours: 30));
    final container = _container(
      trip: _trip(returnFlightAt: flightAt),
      dives: [
        NoFlyDiveInput(
          endTime: now.subtract(const Duration(hours: 2)),
          hadDecoObligation: true,
        ),
      ],
      diverId: 'diver-1',
    );

    final status = await container.read(tripFlightWindowProvider('t1').future);

    expect(status!.category, NoFlyCategory.deco);
    expect(
      status.deadline,
      fromWallClockUtc(flightAt).toUtc().subtract(const Duration(hours: 24)),
    );
  });

  test('returns null when the trip has no flight set', () async {
    final container = _container(
      trip: _trip(returnFlightAt: null),
      dives: const [],
      diverId: 'diver-1',
    );

    final status = await container.read(tripFlightWindowProvider('t1').future);

    expect(status, isNull);
  });

  test('conflict when the current no-fly ends after departure', () async {
    final now = NoFlyService.wallClockNowUtc();
    // Flight in 6 h; a no-deco dive an hour ago carries a 12 h restriction
    // (single) that lands 5 h past departure.
    final flightAt = now.add(const Duration(hours: 6));
    final container = _container(
      trip: _trip(returnFlightAt: flightAt),
      dives: [
        NoFlyDiveInput(
          endTime: now.subtract(const Duration(hours: 1)),
          hadDecoObligation: false,
        ),
      ],
      diverId: 'diver-1',
    );

    final status = await container.read(tripFlightWindowProvider('t1').future);

    expect(status!.state, FlightWindowState.conflict);
  });

  test('a dive written later still reaches the window', () async {
    final now = NoFlyService.wallClockNowUtc();
    final changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    final repository = _StubDiveRepository(const [], changes: changes.stream);
    final container = _container(
      trip: _trip(returnFlightAt: now.add(const Duration(hours: 30))),
      dives: const [],
      diverId: 'diver-1',
      diveRepository: repository,
    );
    final provider = tripFlightWindowProvider('t1');
    final readings = <FlightWindowStatus?>[];
    final subscription = container.listen(
      provider,
      (_, next) => readings.add(next.valueOrNull),
    );
    addTearDown(subscription.close);
    expect(
      (await container.read(provider.future))!.category,
      NoFlyCategory.repetitive,
    );

    repository.inputs = [
      NoFlyDiveInput(
        endTime: now.subtract(const Duration(hours: 2)),
        hadDecoObligation: true,
      ),
    ];
    changes.add(null);
    await pumpEventQueue();

    expect(
      (await container.read(provider.future))!.category,
      NoFlyCategory.deco,
    );
    // The card and the banner hide on a null reading, so a refresh that drops
    // the value makes them blink on every dive write.
    expect(readings, isNot(contains(isNull)));
  });

  // Issue #3926: the flight and any dives are stored as clock digits, so an
  // interval taken off them gains or loses an hour across a DST change. These
  // sit on the process zone's own change: the Test job's Sydney and the
  // Timezone Tests job's New York and Adelaide all have one. In a zone with no
  // DST the two readings cannot differ.
  group('across a daylight-saving change', () {
    const interval = Duration(hours: 18);

    Future<FlightWindowStatus?> windowAt(
      DateTime now, {
      required DateTime flight,
      List<NoFlyDiveInput> dives = const [],
    }) {
      final container = _container(
        trip: _trip(returnFlightAt: asWallClockUtc(flight.toLocal())),
        dives: dives,
        diverId: 'diver-1',
      );
      return withClock(
        Clock.fixed(now.toLocal()),
        () => container.read(tripFlightWindowProvider('t1').future),
      );
    }

    test('the deadline leaves the full interval when clocks go on', () async {
      final change = dstTransition(forward: true)!;
      final flight = change.add(const Duration(hours: 6));

      final status = await windowAt(
        change.subtract(const Duration(hours: 14)),
        flight: flight,
      );

      expect(status!.state, FlightWindowState.open);
      expect(status.deadline, flight.subtract(interval));
    });

    test('the deadline leaves only the interval when clocks go back', () async {
      final change = dstTransition(forward: false)!;
      final flight = change.add(const Duration(hours: 6));

      final status = await windowAt(
        change.subtract(const Duration(hours: 14)),
        flight: flight,
      );

      expect(status!.state, FlightWindowState.open);
      expect(status.deadline, flight.subtract(interval));
    });

    test('closes once less than the interval is left', () async {
      // The digits still read open here: they leave an hour less than the
      // interval, which is the window the issue reports.
      final change = dstTransition(forward: true)!;
      final flight = change.add(const Duration(hours: 6));

      final status = await windowAt(
        flight.subtract(const Duration(hours: 17, minutes: 30)),
        flight: flight,
      );

      expect(status!.state, FlightWindowState.closed);
    });

    test('the countdown runs in elapsed time', () async {
      // The change falls between now and the deadline, so the digits between
      // them overstate the time left by an hour.
      final change = dstTransition(forward: true)!;
      final now = change.subtract(const Duration(hours: 2));

      final status = await windowAt(
        now,
        flight: change.add(const Duration(hours: 24)),
      );

      expect(status!.remaining(now), const Duration(hours: 8));
    });

    test('a restriction past departure in elapsed time conflicts', () async {
      // A 12 h single-dive restriction ends half an hour after this flight,
      // although its digits read half an hour before it.
      final change = dstTransition(forward: true)!;

      final status = await windowAt(
        change.add(const Duration(hours: 1)),
        flight: change.add(const Duration(hours: 7, minutes: 30)),
        dives: [
          NoFlyDiveInput(
            endTime: asWallClockUtc(
              change.subtract(const Duration(hours: 4)).toLocal(),
            ),
            hadDecoObligation: false,
          ),
        ],
      );

      expect(status!.state, FlightWindowState.conflict);
    });

    test('closes on time when the change falls before the deadline', () {
      // Four real hours to the deadline; a timer set from the digits would
      // wait five.
      final change = dstTransition(forward: true)!;
      final start = change.subtract(const Duration(hours: 1)).toLocal();
      final flight = change.add(const Duration(hours: 21));

      fakeAsync((async) {
        final container = _container(
          trip: _trip(returnFlightAt: asWallClockUtc(flight.toLocal())),
          dives: const [],
          diverId: 'diver-1',
        );
        final subscription = container.listen(
          tripFlightWindowProvider('t1'),
          (_, _) {},
        );
        addTearDown(subscription.close);
        async.flushMicrotasks();
        expect(subscription.read().value!.state, FlightWindowState.open);

        async.elapse(const Duration(hours: 4, seconds: 2));

        expect(subscription.read().value!.state, FlightWindowState.closed);
      }, initialTime: start);
    });
  }, skip: zoneHasNoDst);
}
