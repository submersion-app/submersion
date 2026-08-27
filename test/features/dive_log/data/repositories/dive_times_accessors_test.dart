import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  List<domain.DiveProfilePoint> profileOf(int seconds) => [
    for (var t = 0; t <= seconds; t += 10)
      domain.DiveProfilePoint(
        timestamp: t,
        depth: t == 0 || t == seconds ? 0 : 18,
      ),
  ];

  test('getDiveTimes maps fields and profile span fallback', () async {
    await repository.createDive(
      domain.Dive(
        id: 'a',
        dateTime: DateTime.utc(2026, 5, 1, 10),
        entryTime: DateTime.utc(2026, 5, 1, 10, 5),
        bottomTime: const Duration(minutes: 40),
        profile: profileOf(600),
      ),
    );

    final times = await repository.getDiveTimes('a');
    expect(times, isNotNull);
    expect(times!.id, 'a');
    expect(times.entryTime, DateTime.utc(2026, 5, 1, 10, 5));
    expect(times.bottomTime, const Duration(minutes: 40));
    expect(times.profileSpan, const Duration(seconds: 600));
    // No runtime and no exit time: falls through to the profile span,
    // mirroring Dive.effectiveRuntime resolution order.
    expect(times.effectiveRuntime, const Duration(seconds: 600));

    expect(await repository.getDiveTimes('missing'), isNull);
  });

  test('profile span is null for dives without samples', () async {
    await repository.createDive(
      domain.Dive(id: 'bare', dateTime: DateTime.utc(2026, 5, 2, 10)),
    );
    final times = await repository.getDiveTimes('bare');
    expect(times!.profileSpan, isNull);
    expect(times.effectiveRuntime, isNull);
  });

  test('getPreviousDiveTimes matches getPreviousDive', () async {
    await repository.createDive(
      domain.Dive(id: 'p1', dateTime: DateTime.utc(2026, 5, 1, 9)),
    );
    await repository.createDive(
      domain.Dive(
        id: 'p2',
        dateTime: DateTime.utc(2026, 5, 1, 11),
        entryTime: DateTime.utc(2026, 5, 1, 11, 2),
      ),
    );
    await repository.createDive(
      domain.Dive(id: 'p3', dateTime: DateTime.utc(2026, 5, 1, 14)),
    );

    for (final id in ['p2', 'p3']) {
      final legacy = await repository.getPreviousDive(id);
      final slim = await repository.getPreviousDiveTimes(id);
      expect(slim?.id, legacy?.id, reason: 'previous of $id');
    }
    expect(await repository.getPreviousDiveTimes('p1'), isNull);
  });

  test('getDiveTimesInRange matches getDivesInRange ids and order', () async {
    await repository.createDive(
      domain.Dive(id: 'r1', dateTime: DateTime.utc(2026, 6, 1, 8)),
    );
    await repository.createDive(
      domain.Dive(
        id: 'r2',
        dateTime: DateTime.utc(2026, 6, 1, 12),
        entryTime: DateTime.utc(2026, 6, 1, 12, 30),
      ),
    );
    await repository.createDive(
      domain.Dive(id: 'r3', dateTime: DateTime.utc(2026, 6, 2, 9)),
    );
    await repository.createDive(
      domain.Dive(id: 'outside', dateTime: DateTime.utc(2026, 6, 9, 9)),
    );

    final start = DateTime.utc(2026, 6, 1);
    final end = DateTime.utc(2026, 6, 3);
    final legacy = await repository.getDivesInRange(start, end);
    final slim = await repository.getDiveTimesInRange(start, end);

    expect(slim.map((t) => t.id).toList(), legacy.map((d) => d.id).toList());
    expect(slim.map((t) => t.id), isNot(contains('outside')));
  });

  test('getSurfaceInterval semantics unchanged', () async {
    // Previous dive: entry 10:00, runtime 60m -> exit 11:00.
    await repository.createDive(
      domain.Dive(
        id: 's1',
        dateTime: DateTime.utc(2026, 6, 1, 10),
        entryTime: DateTime.utc(2026, 6, 1, 10),
        runtime: const Duration(minutes: 60),
      ),
    );
    // Current dive: entry 13:00 -> surface interval 2h.
    await repository.createDive(
      domain.Dive(
        id: 's2',
        dateTime: DateTime.utc(2026, 6, 1, 13),
        entryTime: DateTime.utc(2026, 6, 1, 13),
      ),
    );

    expect(await repository.getSurfaceInterval('s2'), const Duration(hours: 2));
    expect(await repository.getSurfaceInterval('s1'), isNull);
  });

  test('surface interval uses profile span when runtime absent', () async {
    // Previous dive has no runtime/exit; 600 s profile -> exit 10:10.
    await repository.createDive(
      domain.Dive(
        id: 'ps1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        entryTime: DateTime.utc(2026, 7, 1, 10),
        profile: profileOf(600),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'ps2',
        dateTime: DateTime.utc(2026, 7, 1, 11),
        entryTime: DateTime.utc(2026, 7, 1, 11),
      ),
    );

    expect(
      await repository.getSurfaceInterval('ps2'),
      const Duration(minutes: 50),
    );
  });

  test('getDiveForAnalysis matches getDiveById on analysis fields', () async {
    await repository.createDive(
      domain.Dive(
        id: 'g1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        gradientFactorLow: 45,
        gradientFactorHigh: 80,
        altitude: 300.0,
        profile: profileOf(300),
      ),
    );

    final full = await repository.getDiveById('g1');
    final lean = await repository.getDiveForAnalysis('g1');

    expect(lean, isNotNull);
    expect(lean!.id, full!.id);
    expect(lean.gradientFactorLow, full.gradientFactorLow);
    expect(lean.gradientFactorHigh, full.gradientFactorHigh);
    expect(lean.altitude, full.altitude);
    expect(lean.diveMode, full.diveMode);
    expect(lean.entryTime, full.entryTime);
    expect(lean.dateTime, full.dateTime);
    expect(lean.tanks.length, full.tanks.length);
    expect(lean.profile.length, full.profile.length);
    expect(lean.profile.first.depth, full.profile.first.depth);
    expect(lean.profile.last.timestamp, full.profile.last.timestamp);
    // Display joins deliberately not hydrated on the lean path.
    expect(lean.tags, isEmpty);
    expect(lean.equipment, isEmpty);
  });
}
