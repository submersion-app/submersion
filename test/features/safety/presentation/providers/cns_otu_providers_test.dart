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

/// Fake repository returning a fixed most-recent dive for the active diver.
class _StubDiveRepository extends Fake implements DiveRepository {
  final DiveTimes? lastDive;
  String? queriedDiverId;

  _StubDiveRepository(this.lastDive);

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

  test(
    'builds a snapshot from the most recent dive\'s analysis and weekly OTU',
    () async {
      final diverNotifier = MockCurrentDiverIdNotifier();
      diverNotifier.setCurrentDiver('diver-1');
      final lastDiveEnd = DateTime.utc(2026, 7, 17, 12);
      final repo = _StubDiveRepository(
        DiveTimes(
          id: 'dive-1',
          dateTime: DateTime.utc(2026, 7, 17, 10),
          entryTime: DateTime.utc(2026, 7, 17, 10),
          exitTime: lastDiveEnd,
        ),
      );
      const exposure = O2Exposure(cnsEnd: 42.0, otu: 15.0, otuStart: 5.0);

      final container = ProviderContainer(
        overrides: [
          diveRepositoryProvider.overrideWithValue(repo),
          currentDiverIdProvider.overrideWith((ref) => diverNotifier),
          profileAnalysisProvider.overrideWith((ref, diveId) async {
            expect(diveId, 'dive-1');
            return ProfileAnalysis.empty().copyWith(o2Exposure: exposure);
          }),
          weeklyOtuProvider.overrideWith((ref, diveId) async {
            expect(diveId, 'dive-1');
            return 123.0;
          }),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await container.read(cnsOtuSnapshotProvider.future);
      expect(snapshot, isNotNull);
      expect(snapshot!.lastDiveId, 'dive-1');
      expect(snapshot.lastDiveEnd, lastDiveEnd);
      expect(snapshot.cnsAtDiveEnd, 42.0);
      expect(snapshot.exposure, exposure);
      expect(snapshot.weeklyOtu, 123.0);
      expect(repo.queriedDiverId, 'diver-1');
    },
  );

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
          weeklyOtuProvider.overrideWith((ref, diveId) async => 0.0),
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
