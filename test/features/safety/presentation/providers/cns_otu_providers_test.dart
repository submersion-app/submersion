import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_times.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/cns_otu_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Fake repository that fails if the lookup is ever run, so the test can
/// prove the provider short-circuits before touching the database.
class _NoQueryDiveRepository extends Fake implements DiveRepository {
  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Future<DiveTimes?> getMostRecentDiveTimes({
    required String? diverId,
    required DateTime notAfter,
  }) async {
    throw StateError(
      'getMostRecentDiveTimes must not run without an active diver',
    );
  }
}

/// Fake repository returning a fixed most-recent dive for the active diver,
/// plus whatever dives fall in a queried weekly range.
class _StubDiveRepository extends Fake implements DiveRepository {
  final DiveTimes? lastDive;
  final List<DiveTimes> weekDives;
  String? queriedDiverId;
  ({DateTime start, DateTime end, String? diverId})? weeklyRangeQueried;

  _StubDiveRepository(this.lastDive, {this.weekDives = const []});

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Future<DiveTimes?> getMostRecentDiveTimes({
    required String? diverId,
    required DateTime notAfter,
  }) async {
    queriedDiverId = diverId;
    return lastDive;
  }

  @override
  Future<List<DiveTimes>> getExecutedDiveTimesInRange(
    DateTime start,
    DateTime end, {
    required String diverId,
  }) async {
    weeklyRangeQueried = (start: start, end: end, diverId: diverId);
    return weekDives;
  }
}

/// Fake repository whose most-recent-dive lookup fails, to prove the
/// provider's own Future fails rather than quietly returning null.
class _FailingDiveRepository extends Fake implements DiveRepository {
  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Future<DiveTimes?> getMostRecentDiveTimes({
    required String? diverId,
    required DateTime notAfter,
  }) async {
    throw StateError('simulated database failure');
  }
}

void main() {
  test('returns null without querying dives when no diver is active', () async {
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(_NoQueryDiveRepository()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(cnsOtuSnapshotProvider.future);
    expect(snapshot, isNull);
  });

  test('returns null when the diver has no executed dive on record', () async {
    final diverNotifier = MockCurrentDiverIdNotifier();
    diverNotifier.setCurrentDiver('diver-1');
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(_StubDiveRepository(null)),
        currentDiverIdProvider.overrideWith((ref) => diverNotifier),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(cnsOtuSnapshotProvider.future);
    expect(snapshot, isNull);
  });

  test('a repository failure fails this provider\'s Future, rather than being '
      'swallowed into a false "no dive" null', () async {
    final diverNotifier = MockCurrentDiverIdNotifier();
    diverNotifier.setCurrentDiver('diver-1');
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(_FailingDiveRepository()),
        currentDiverIdProvider.overrideWith((ref) => diverNotifier),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(cnsOtuSnapshotProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  // The totals are anchored to the real clock, so fixtures are placed
  // relative to the start of today rather than on fixed dates.
  final now = NoFlyService.wallClockNowUtc();
  final today = DateTime.utc(now.year, now.month, now.day);

  ProviderContainer containerFor(
    _StubDiveRepository repo,
    Map<String, O2Exposure?> exposures,
  ) {
    final diverNotifier = MockCurrentDiverIdNotifier();
    diverNotifier.setCurrentDiver('diver-1');
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => diverNotifier),
        profileAnalysisProvider.overrideWith((ref, diveId) async {
          final exposure = exposures[diveId];
          return exposure == null
              ? null
              : ProfileAnalysis.empty().copyWith(o2Exposure: exposure);
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('builds a snapshot from the most recent dive\'s analysis and sums OTU '
      'across the dives in the rolling weekly window', () async {
    final yesterday = today.subtract(const Duration(days: 1));
    final lastDiveEnd = yesterday.add(const Duration(hours: 12));
    final earlierThisWeek = DiveTimes(
      id: 'dive-0',
      dateTime: today.subtract(const Duration(days: 3, hours: -9)),
    );
    final lastDive = DiveTimes(
      id: 'dive-1',
      dateTime: yesterday.add(const Duration(hours: 10)),
      entryTime: yesterday.add(const Duration(hours: 10)),
      exitTime: lastDiveEnd,
    );
    final repo = _StubDiveRepository(
      lastDive,
      // A real getExecutedDiveTimesInRange query returns every dive in the
      // window, including the last dive itself, not just earlier ones.
      weekDives: [earlierThisWeek, lastDive],
    );
    const exposure = O2Exposure(cnsEnd: 42.0, otu: 15.0, otuStart: 5.0);
    final container = containerFor(repo, {
      'dive-1': exposure,
      'dive-0': const O2Exposure(otu: 80.0),
    });

    final snapshot = await container.read(cnsOtuSnapshotProvider.future);
    expect(snapshot, isNotNull);
    expect(snapshot!.lastDiveId, 'dive-1');
    expect(snapshot.lastDiveEnd, lastDiveEnd);
    expect(snapshot.cnsAtDiveEnd, 42.0);
    expect(snapshot.exposure?.otu, exposure.otu);
    // 15 (dive-1) + 80 (dive-0), not just the last dive's own OTU.
    expect(snapshot.weeklyOtu, 95.0);
    // Neither dive reached into today.
    expect(snapshot.dailyOtu, 0.0);
    expect(repo.queriedDiverId, 'diver-1');
    // Anchored to wall-clock now, not the last dive's own calendar day
    // (see weeklyOtuProvider in profile_analysis_provider.dart for the
    // dive-date-anchored version this intentionally does not reuse), and
    // scoped to the active diver.
    expect(repo.weeklyRangeQueried?.diverId, 'diver-1');
  });

  test(
    'falls back to entryTime + runtime when the dive has no exitTime',
    () async {
      final entryTime = today.subtract(const Duration(hours: 14));
      final repo = _StubDiveRepository(
        DiveTimes(
          id: 'dive-2',
          dateTime: entryTime,
          entryTime: entryTime,
          runtime: const Duration(minutes: 40),
        ),
      );
      final container = containerFor(repo, {
        'dive-2': const O2Exposure(cnsEnd: 10.0),
      });

      final snapshot = await container.read(cnsOtuSnapshotProvider.future);
      expect(snapshot!.lastDiveEnd, entryTime.add(const Duration(minutes: 40)));
    },
  );

  test('weekly OTU skips a dive that starts after now', () async {
    final lastDive = DiveTimes(
      id: 'dive-1',
      dateTime: today.subtract(const Duration(hours: 14)),
    );
    // Still inside the queried window (which runs to the end of today), but
    // later than now: its OTU has not been accrued yet.
    final notYetDived = DiveTimes(
      id: 'dive-later',
      dateTime: DateTime.utc(9999, 1, 1),
    );
    final repo = _StubDiveRepository(
      lastDive,
      weekDives: [notYetDived, lastDive],
    );
    final container = containerFor(repo, {
      'dive-1': const O2Exposure(otu: 15.0),
      'dive-later': const O2Exposure(otu: 200.0),
    });

    final snapshot = await container.read(cnsOtuSnapshotProvider.future);
    expect(snapshot!.weeklyOtu, 15.0);
  });

  test(
    'a last dive that crossed midnight counts only its part today',
    () async {
      // 23:30 to 00:20 with 100 OTU; no OTU curve on the stub, so the split
      // follows elapsed time: 20 of its 50 minutes fell on today.
      final start = today.subtract(const Duration(minutes: 30));
      final lastDive = DiveTimes(
        id: 'dive-night',
        dateTime: start,
        entryTime: start,
        runtime: const Duration(minutes: 50),
      );
      final repo = _StubDiveRepository(lastDive, weekDives: [lastDive]);
      final container = containerFor(repo, {
        'dive-night': const O2Exposure(otu: 100.0),
      });

      final snapshot = await container.read(cnsOtuSnapshotProvider.future);
      expect(snapshot!.dailyOtu, closeTo(40.0, 1e-9));
      expect(snapshot.weeklyOtu, closeTo(100.0, 1e-9));
    },
  );

  test('a last dive with no analysis still yields a snapshot, with unknown '
      'exposure and the totals of the dives that have one', () async {
    final earlier = DiveTimes(
      id: 'dive-0',
      dateTime: today.subtract(const Duration(days: 2)),
    );
    final lastDive = DiveTimes(
      id: 'dive-3',
      dateTime: today.subtract(const Duration(hours: 14)),
    );
    final repo = _StubDiveRepository(lastDive, weekDives: [earlier, lastDive]);
    final container = containerFor(repo, {
      'dive-0': const O2Exposure(otu: 80.0),
    });

    final snapshot = await container.read(cnsOtuSnapshotProvider.future);
    expect(snapshot, isNotNull);
    expect(snapshot!.lastDiveId, 'dive-3');
    expect(snapshot.hasProfile, isFalse);
    expect(snapshot.exposure, isNull);
    expect(snapshot.weeklyOtu, 80.0);
  });
}
