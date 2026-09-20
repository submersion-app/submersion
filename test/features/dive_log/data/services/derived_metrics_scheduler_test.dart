import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

class _RecordingRepo implements DerivedMetricsRepository {
  final List<({String id, bool force})> calls = [];
  final List<String> stale;
  final List<String?> sweptDiverIds = [];
  bool throwOnce = false;
  bool sweepThrows = false;

  _RecordingRepo({this.stale = const []});

  @override
  Future<DiveDerivedMetrics?> ensureCurrent(
    String diveId, {
    bool force = false,
  }) async {
    calls.add((id: diveId, force: force));
    if (throwOnce) {
      throwOnce = false;
      throw StateError('boom');
    }
    return DiveDerivedMetrics(
      diveId: diveId,
      engineVersion: DerivedMetricsService.version,
      sourceUpdatedAt: 0,
      computedAt: 0,
    );
  }

  @override
  Future<List<String>> staleDiveIds({String? diverId}) async {
    sweptDiverIds.add(diverId);
    if (sweepThrows) throw StateError('sweep failed');
    return stale;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingRepo repo;

  void useRepo(_RecordingRepo next) {
    repo = next;
    DerivedMetricsScheduler.instance.repositoryFactory = () => repo;
  }

  setUp(() {
    DerivedMetricsScheduler.enabled = true;
    useRepo(_RecordingRepo());
  });

  tearDown(() {
    DerivedMetricsScheduler.enabled = false;
    DerivedMetricsScheduler.instance.repositoryFactory =
        DerivedMetricsScheduler.defaultRepositoryFactory;
    DerivedMetricsScheduler.instance.requestListener = null;
  });

  test('a scheduled dive is refreshed once', () async {
    DerivedMetricsScheduler.instance.schedule({'d1'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['d1']);
  });

  test('a burst merges into one drain', () async {
    DerivedMetricsScheduler.instance
      ..schedule({'d1'})
      ..schedule({'d2'})
      ..schedule({'d1'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id).toSet(), {'d1', 'd2'});
    expect(repo.calls, hasLength(2));
  });

  test('force is carried through', () async {
    DerivedMetricsScheduler.instance.schedule({'d1'}, force: true);
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.single.force, isTrue);
  });

  test('a failure on one dive does not poison the queue', () async {
    repo.throwOnce = true;
    DerivedMetricsScheduler.instance.schedule({'bad'});
    await DerivedMetricsScheduler.instance.idle;
    DerivedMetricsScheduler.instance.schedule({'good'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['bad', 'good']);
  });

  test('the sweep refreshes every stale dive', () async {
    useRepo(_RecordingRepo(stale: const ['a', 'b']));
    DerivedMetricsScheduler.instance.scheduleStaleSweep();
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['a', 'b']);
  });

  test('the sweep carries the diver it was asked for', () async {
    DerivedMetricsScheduler.instance.scheduleStaleSweep(diverId: 'diver1');
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.sweptDiverIds, ['diver1']);
  });

  test('a failed sweep still refreshes the dives already queued', () async {
    repo.sweepThrows = true;
    DerivedMetricsScheduler.instance
      ..schedule({'d1'})
      ..scheduleStaleSweep();
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['d1']);
    // The queue survives: a later request still runs.
    DerivedMetricsScheduler.instance.schedule({'d2'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['d1', 'd2']);
  });

  test('disabled means no work, which is how the suite stays quiet', () async {
    DerivedMetricsScheduler.enabled = false;
    DerivedMetricsScheduler.instance.schedule({'d1'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls, isEmpty);
  });

  test('the listener sees a request the disabled guard drops', () async {
    DerivedMetricsScheduler.enabled = false;
    final seen = <({Set<String> ids, bool force})>[];
    DerivedMetricsScheduler.instance.requestListener = (ids, force) =>
        seen.add((ids: ids, force: force));
    scheduleDerivedMetricsRefresh(['d1', 'd2'], force: true);
    await DerivedMetricsScheduler.instance.idle;
    expect(seen.single.ids, {'d1', 'd2'});
    expect(seen.single.force, isTrue);
    expect(repo.calls, isEmpty);
  });
}
