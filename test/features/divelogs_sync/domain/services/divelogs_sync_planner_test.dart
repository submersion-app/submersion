import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_sync_planner.dart';

void main() {
  const planner = DivelogsSyncPlanner();

  DivelogsDivelistEntry remote(
    String id,
    DateTime at, {
    int? duration = 2808,
    double? depth = 12,
  }) => DivelogsDivelistEntry(
    id: id,
    dateTime: at,
    durationSeconds: duration,
    maxDepth: depth,
  );

  DiveSummary local(
    String id,
    DateTime at, {
    Duration? runtime = const Duration(seconds: 2808),
    double? depth = 12,
  }) => DiveSummary(
    id: id,
    dateTime: at,
    entryTime: at,
    runtime: runtime,
    maxDepth: depth,
    isFavorite: false,
    diveTypeIds: const [],
    tags: const [],
    sortTimestamp: at.millisecondsSinceEpoch,
  );

  final t0 = DateTime.utc(2022, 9, 3, 14, 42);

  test('matched pairs are neither pulled nor pushed', () {
    final plan = planner.plan(
      remote: [remote('r1', t0)],
      local: [local('l1', t0)],
    );
    expect(plan.pullCandidates, isEmpty);
    expect(plan.pushCandidates, isEmpty);
    expect(plan.matchedCount, 1);
  });

  test('remote-only dives are pull candidates, local-only are push', () {
    final plan = planner.plan(
      remote: [remote('r1', t0), remote('r2', t0.add(const Duration(days: 1)))],
      local: [local('l1', t0), local('l2', t0.add(const Duration(days: 2)))],
    );
    expect(plan.pullCandidates.map((e) => e.id), ['r2']);
    expect(plan.pushCandidates.map((s) => s.id), ['l2']);
    expect(plan.matchedCount, 1);
  });

  test('time gate: 20 minutes apart is not a match', () {
    final plan = planner.plan(
      remote: [remote('r1', t0)],
      local: [local('l1', t0.add(const Duration(minutes: 20)))],
    );
    expect(plan.pullCandidates, hasLength(1));
    expect(plan.pushCandidates, hasLength(1));
  });

  test('same time but wildly different depth/duration is not a match', () {
    final plan = planner.plan(
      remote: [remote('r1', t0, duration: 2808, depth: 40)],
      local: [local('l1', t0, runtime: const Duration(minutes: 5), depth: 3)],
    );
    expect(plan.pullCandidates, hasLength(1));
    expect(plan.pushCandidates, hasLength(1));
  });

  test('degraded match: divelist without depth/duration matches on time', () {
    final plan = planner.plan(
      remote: [remote('r1', t0, duration: null, depth: null)],
      local: [local('l1', t0.add(const Duration(minutes: 5)))],
    );
    expect(plan.pullCandidates, isEmpty);
    expect(plan.pushCandidates, isEmpty);
    expect(plan.matchedCount, 1);
  });

  test('one-to-one: a single local dive cannot match two remote entries', () {
    final plan = planner.plan(
      remote: [
        remote('r1', t0),
        remote('r2', t0.add(const Duration(minutes: 3))),
      ],
      local: [local('l1', t0)],
    );
    expect(plan.matchedCount, 1);
    expect(plan.pullCandidates, hasLength(1));
    expect(plan.pushCandidates, isEmpty);
  });
}
