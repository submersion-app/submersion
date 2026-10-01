import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Fake repository that fails if the no-fly query is ever run, so the test can
/// prove the provider short-circuits before touching the database.
class _NoQueryDiveRepository extends Fake implements DiveRepository {
  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Stream<void> watchDiveListChanges() => const Stream.empty();

  @override
  Future<List<NoFlyDiveInput>> getNoFlyDiveInputs({
    required DateTime since,
    String? diverId,
  }) async {
    throw StateError('getNoFlyDiveInputs must not run without an active diver');
  }
}

/// Fake repository that returns a fixed set of dive inputs for the active-diver
/// happy path. Records the diverId it was queried with.
class _StubDiveRepository extends Fake implements DiveRepository {
  final List<NoFlyDiveInput> inputs;
  String? queriedDiverId;

  _StubDiveRepository(this.inputs);

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Future<List<NoFlyDiveInput>> getNoFlyDiveInputs({
    required DateTime since,
    String? diverId,
  }) async {
    queriedDiverId = diverId;
    return inputs;
  }
}

void main() {
  test('returns null without querying dives when no diver is active', () async {
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(_NoQueryDiveRepository()),
        // MockCurrentDiverIdNotifier defaults to null (no active diver).
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final status = await container.read(noFlyStatusProvider.future);
    expect(status, isNull);
  });

  test(
    'computes a restriction for the active diver from recent dives',
    () async {
      // One no-deco dive an hour ago -> single-dive category, 12 h guideline.
      final repo = _StubDiveRepository([
        NoFlyDiveInput(
          endTime: NoFlyService.wallClockNowUtc().subtract(
            const Duration(hours: 1),
          ),
          hadDecoObligation: false,
        ),
      ]);
      final diverNotifier = MockCurrentDiverIdNotifier();
      diverNotifier.setCurrentDiver('diver-1');

      final container = ProviderContainer(
        overrides: [
          diveRepositoryProvider.overrideWithValue(repo),
          currentDiverIdProvider.overrideWith((ref) => diverNotifier),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(noFlyStatusProvider.future);
      expect(status, isNotNull);
      expect(status!.category, NoFlyCategory.single);
      expect(repo.queriedDiverId, 'diver-1');
    },
  );

  ProviderContainer containerFor(_StubDiveRepository repo) {
    final diverNotifier = MockCurrentDiverIdNotifier();
    diverNotifier.setCurrentDiver('diver-1');
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => diverNotifier),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('counts a dive that surfaced minutes ago (issue #2587)', () async {
    // Dive end times are stored wall-clock-as-UTC. East of UTC, a dive that
    // ended a few minutes ago carries a value later than the true UTC
    // instant, so comparing the stored value against DateTime.now().toUtc()
    // dropped it as "in the future" and the countdown kept reporting the
    // previous dive.
    final yesterdayEnd = NoFlyService.wallClockNowUtc().subtract(
      const Duration(hours: 20),
    );
    final justSurfaced = NoFlyService.wallClockNowUtc().subtract(
      const Duration(minutes: 5),
    );
    final container = containerFor(
      _StubDiveRepository([
        NoFlyDiveInput(endTime: yesterdayEnd, hadDecoObligation: false),
        NoFlyDiveInput(endTime: justSurfaced, hadDecoObligation: false),
      ]),
    );

    final status = await container.read(noFlyStatusProvider.future);
    expect(status, isNotNull);
    expect(status!.category, NoFlyCategory.repetitive);
    expect(
      status.until,
      fromWallClockUtc(justSurfaced).toUtc().add(status.interval),
    );
  });

  test('measures the interval in elapsed time, not clock digits', () async {
    // Surfaced at 20:00 the night US clocks spring forward (2027-03-14). In
    // a zone that observes it, 08:00 the next morning is only 11 real hours
    // later, so a 12 h guideline must run to 09:00. The expectation is built
    // with local DateTimes, so it holds in whatever zone the suite runs.
    final surfaced = DateTime(2027, 3, 13, 20);
    final container = containerFor(
      _StubDiveRepository([
        NoFlyDiveInput(
          endTime: asWallClockUtc(surfaced),
          hadDecoObligation: false,
        ),
      ]),
    );

    final status = await withClock(
      Clock.fixed(DateTime(2027, 3, 14, 7)),
      () => container.read(noFlyStatusProvider.future),
    );
    expect(status, isNotNull);
    expect(status!.until, surfaced.toUtc().add(const Duration(hours: 12)));
  });
}
