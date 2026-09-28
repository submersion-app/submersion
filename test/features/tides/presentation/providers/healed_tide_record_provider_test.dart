import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';

class _FakeDiveRepository extends Fake implements DiveRepository {
  @override
  Stream<void> watchDiveDetailChanges() => const Stream<void>.empty();
}

class _FakeTideRecordRepository extends TideRecordRepository {
  _FakeTideRecordRepository(this.stored);

  TideRecord? stored;
  int writes = 0;

  @override
  Future<TideRecord?> getTideRecordForDive(String diveId) async => stored;

  @override
  Future<TideRecord> createFromStatus({
    required String diveId,
    required TideStatus status,
  }) async {
    writes++;
    final record = TideRecord.fromStatus(
      id: 'healed-$writes',
      diveId: diveId,
      status: status,
    );
    stored = record;
    return record;
  }
}

const _bonaire = GeoPoint(12.15, -68.27); // UTC-4, no DST
final _entryWallClock = DateTime.utc(2026, 3, 28, 10);
final _calculator = TideCalculator(
  constituents: {
    'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
  },
);

ProviderContainer _container(_FakeTideRecordRepository repository) {
  final container = ProviderContainer(
    overrides: [
      diveRepositoryProvider.overrideWithValue(_FakeDiveRepository()),
      tideRecordRepositoryProvider.overrideWithValue(repository),
      resolvedTideDataProvider(_bonaire).overrideWith(
        (ref) async => ResolvedTideData(
          calculator: _calculator,
          source: const TideDataSource.fesModel(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final _key = (diveId: 'd1', location: _bonaire, entryTime: _entryWallClock);

void main() {
  test('a record computed at the wall clock as an instant is healed', () async {
    // The pre-fix save path evaluated the engine at 10:00Z, four hours early.
    final stale = TideRecord.fromStatus(
      id: 'stale',
      diveId: 'd1',
      status: _calculator.getStatus(_entryWallClock),
    );
    final repository = _FakeTideRecordRepository(stale);
    final container = _container(repository);

    final healed = await container.read(healedTideRecordProvider(_key).future);

    final fresh = _calculator.getStatus(DateTime.utc(2026, 3, 28, 14));
    expect(repository.writes, 1);
    expect(healed!.id, 'healed-1');
    expect(healed.heightMeters, closeTo(fresh.currentHeight, 1e-9));
  });

  test('healing converges: a second view does not rewrite', () async {
    final stale = TideRecord.fromStatus(
      id: 'stale',
      diveId: 'd1',
      status: _calculator.getStatus(_entryWallClock),
    );
    final repository = _FakeTideRecordRepository(stale);
    final container = _container(repository);

    await container.read(healedTideRecordProvider(_key).future);
    container.invalidate(healedTideRecordProvider(_key));
    final again = await container.read(healedTideRecordProvider(_key).future);

    expect(repository.writes, 1);
    expect(again!.id, 'healed-1');
  });

  test('a record computed at the real instant is left alone', () async {
    final correct = TideRecord.fromStatus(
      id: 'correct',
      diveId: 'd1',
      status: _calculator.getStatus(DateTime.utc(2026, 3, 28, 14)),
    );
    final repository = _FakeTideRecordRepository(correct);
    final container = _container(repository);

    final result = await container.read(healedTideRecordProvider(_key).future);

    expect(repository.writes, 0);
    expect(result!.id, 'correct');
  });

  test(
    'a record that cannot be verified at a site without data is hidden',
    () async {
      // Written by the pre-fix path; with no tide data here it can be neither
      // healed nor trusted, and mapping it to site time would double its shift.
      final stale = TideRecord.fromStatus(
        id: 'stale',
        diveId: 'd1',
        status: _calculator.getStatus(_entryWallClock),
      );
      final repository = _FakeTideRecordRepository(stale);
      final container = ProviderContainer(
        overrides: [
          diveRepositoryProvider.overrideWithValue(_FakeDiveRepository()),
          tideRecordRepositoryProvider.overrideWithValue(repository),
          resolvedTideDataProvider(_bonaire).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(healedTideRecordProvider(_key).future),
        isNull,
      );
      expect(repository.writes, 0);
    },
  );
}
