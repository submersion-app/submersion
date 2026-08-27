import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

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
  final List<NoFlyDiveInput> inputs;

  _StubDiveRepository(this.inputs);

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

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
}) {
  final diverNotifier = MockCurrentDiverIdNotifier();
  if (diverId != null) diverNotifier.setCurrentDiver(diverId);
  final container = ProviderContainer(
    overrides: [
      tripRepositoryProvider.overrideWithValue(_StubTripRepository(trip)),
      diveRepositoryProvider.overrideWithValue(_StubDiveRepository(dives)),
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
    expect(status.deadline, flightAt.subtract(const Duration(hours: 18)));
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
    expect(status.deadline, flightAt.subtract(const Duration(hours: 24)));
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
}
