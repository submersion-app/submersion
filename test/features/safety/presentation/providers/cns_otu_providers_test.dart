import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_times.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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
  Future<List<DiveTimes>> getDiveTimesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
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

  test('builds a snapshot from the most recent dive\'s analysis and sums OTU '
      'across the dives in the rolling weekly window', () async {
    final diverNotifier = MockCurrentDiverIdNotifier();
    diverNotifier.setCurrentDiver('diver-1');
    final lastDiveEnd = DateTime.utc(2026, 7, 17, 12);
    final earlierThisWeek = DiveTimes(
      id: 'dive-0',
      dateTime: DateTime.utc(2026, 7, 15, 9),
    );
    final lastDive = DiveTimes(
      id: 'dive-1',
      dateTime: DateTime.utc(2026, 7, 17, 10),
      entryTime: DateTime.utc(2026, 7, 17, 10),
      exitTime: lastDiveEnd,
    );
    final repo = _StubDiveRepository(
      lastDive,
      // A real getDiveTimesInRange query returns every dive in the window,
      // including the last dive itself -- not just earlier ones.
      weekDives: [earlierThisWeek, lastDive],
    );
    const exposure = O2Exposure(cnsEnd: 42.0, otu: 15.0, otuStart: 5.0);

    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => diverNotifier),
        profileAnalysisProvider.overrideWith((ref, diveId) async {
          final o2Exposure = diveId == 'dive-1'
              ? exposure
              : const O2Exposure(otu: 80.0);
          return ProfileAnalysis.empty().copyWith(o2Exposure: o2Exposure);
        }),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(cnsOtuSnapshotProvider.future);
    expect(snapshot, isNotNull);
    expect(snapshot!.lastDiveId, 'dive-1');
    expect(snapshot.lastDiveEnd, lastDiveEnd);
    expect(snapshot.cnsAtDiveEnd, 42.0);
    expect(snapshot.exposure.otu, exposure.otu);
    // 15 (dive-1) + 80 (dive-0), not just the last dive's own OTU.
    expect(snapshot.weeklyOtu, 95.0);
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
      final diverNotifier = MockCurrentDiverIdNotifier();
      diverNotifier.setCurrentDiver('diver-1');
      final entryTime = DateTime.utc(2026, 7, 17, 10);
      final repo = _StubDiveRepository(
        DiveTimes(
          id: 'dive-2',
          dateTime: entryTime,
          entryTime: entryTime,
          runtime: const Duration(minutes: 40),
        ),
      );
      const exposure = O2Exposure(cnsEnd: 10.0);

      final container = ProviderContainer(
        overrides: [
          diveRepositoryProvider.overrideWithValue(repo),
          currentDiverIdProvider.overrideWith((ref) => diverNotifier),
          profileAnalysisProvider.overrideWith(
            (ref, diveId) async =>
                ProfileAnalysis.empty().copyWith(o2Exposure: exposure),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await container.read(cnsOtuSnapshotProvider.future);
      expect(snapshot!.lastDiveEnd, entryTime.add(const Duration(minutes: 40)));
    },
  );

  test('returns null when the dive has no analysis', () async {
    final diverNotifier = MockCurrentDiverIdNotifier();
    diverNotifier.setCurrentDiver('diver-1');
    final repo = _StubDiveRepository(
      DiveTimes(id: 'dive-3', dateTime: DateTime.utc(2026, 7, 17)),
    );

    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => diverNotifier),
        profileAnalysisProvider.overrideWith((ref, diveId) async => null),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(cnsOtuSnapshotProvider.future);
    expect(snapshot, isNull);
  });
}
