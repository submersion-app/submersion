import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide Dive, DiveHealthRecord;
import 'package:submersion/features/dive_import/data/services/dive_health_metrics_service.dart';
import 'package:submersion/features/dive_import/domain/entities/health_sample.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_health_record_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// What Apple Health has, by true instant. Each read counts, so a test can
/// tell whether a settled dive asked again.
class _Health extends Fake implements HealthImportService {
  List<HealthSample> heartRate = [];
  List<HealthSample> hrv = [];
  List<SleepInterval> sleep = [];
  int reads = 0;

  List<HealthSample> _within(List<HealthSample> s, DateTime a, DateTime b) => [
    for (final x in s)
      if (!x.at.isBefore(a) && !x.at.isAfter(b)) x,
  ];

  @override
  Future<List<HealthSample>> fetchHeartRate({
    required DateTime start,
    required DateTime end,
  }) async {
    reads++;
    return _within(heartRate, start, end);
  }

  @override
  Future<List<HealthSample>> fetchHrv({
    required DateTime start,
    required DateTime end,
  }) async {
    reads++;
    return _within(hrv, start, end);
  }

  @override
  Future<List<SleepInterval>> fetchSleep({
    required DateTime start,
    required DateTime end,
  }) async {
    reads++;
    return [
      for (final s in sleep)
        if (s.end.isAfter(start) && s.start.isBefore(end)) s,
    ];
  }
}

/// Heart rate, recovery and sleep from Apple Health on a dive (issue #637),
/// for the diver the switch is bound to.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late DiveHealthRecordRepository records;
  late _Health health;
  String? bound = 'a';
  final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

  /// A local wall-clock moment as a true instant, so the test reads the same
  /// in every time zone.
  DateTime local(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 7, day, hour, minute).toUtc();
  HealthSample at(DateTime when, double value) =>
      HealthSample(at: when, value: value);

  DiveHealthMetricsService service({DateTime? now}) => DiveHealthMetricsService(
    health: health,
    dives: dives,
    records: records,
    metricsDiverId: () => bound,
    clock: () => now ?? local(18, 12),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    records = DiveHealthRecordRepository();
    health = _Health();
    bound = 'a';
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: created,
              updatedAt: created,
            ),
          );
    }
  });

  tearDown(() => tearDownTestDatabase());

  /// 10:00 to 10:45 on the 17th, wall clock.
  Future<Dive> dive({
    String diverId = 'a',
    List<DiveProfilePoint> profile = const [],
    bool openDraft = false,
  }) => dives.createDive(
    Dive(
      id: '',
      diverId: diverId,
      dateTime: DateTime.utc(2026, 7, 17, 10),
      entryTime: DateTime.utc(2026, 7, 17, 10),
      exitTime: openDraft ? null : DateTime.utc(2026, 7, 17, 10, 45),
      isDraft: openDraft,
      profile: profile,
    ),
  );

  void duringAndAfter() => health.heartRate = [
    at(local(17, 10), 80),
    at(local(17, 10, 20), 90),
    at(local(17, 10, 45), 100),
    at(local(17, 10, 50), 85),
    at(local(17, 11), 70),
  ];

  void nightBefore() => health.sleep = [
    ...health.sleep,
    SleepInterval(start: local(16, 23), end: local(17, 6)),
  ];

  void nightAfter() {
    health.sleep = [
      ...health.sleep,
      SleepInterval(start: local(17, 22, 30), end: local(18, 6, 30)),
    ];
    health.hrv = [at(local(17, 23), 40), at(local(18, 3), 50)];
  }

  test('writes a record for the bound diver\'s dive', () async {
    final d = await dive();
    duringAndAfter();
    nightBefore();
    nightAfter();

    await service().refresh(d.id);

    final r = (await records.forDive(d.id))!;
    int s(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
    expect(r.heartRateSamples, [
      [s(local(17, 10)), 80],
      [s(local(17, 10, 20)), 90],
      [s(local(17, 10, 45)), 100],
    ]);
    expect(r.avgHeartRate, 90);
    expect(r.maxHeartRate, 100);
    expect(r.heartRateAtExit, 100);
    expect(r.heartRateExitPlus5, 85);
    expect(r.heartRateExitPlus15, 70);
    expect(r.overnightHrvMs, 45);
    expect(r.sleepBeforeMinutes, 420);
    expect(r.settled, isTrue);
  });

  test('leaves another diver\'s dive alone', () async {
    final d = await dive(diverId: 'b');
    duringAndAfter();

    await service().refresh(d.id);

    expect(await records.forDive(d.id), isNull);
    expect(health.reads, 0);
  });

  test('does nothing while the switch is off', () async {
    final d = await dive();
    duringAndAfter();
    bound = null;

    await service().refresh(d.id);
    await service().refreshPending();

    expect(health.reads, 0);
  });

  test('a bound diver who was deleted gets nothing read', () async {
    await dive();
    duringAndAfter();
    bound = 'deleted-diver';

    await service().refreshPending();

    expect(health.reads, 0);
  });

  test('keeps heart rate the dive computer measured', () async {
    final d = await dive(
      profile: const [
        DiveProfilePoint(
          timestamp: 0,
          depth: 0,
          heartRate: 72,
          heartRateSource: 'diveComputer',
        ),
        DiveProfilePoint(
          timestamp: 600,
          depth: 12,
          heartRate: 75,
          heartRateSource: 'diveComputer',
        ),
      ],
    );
    duringAndAfter();
    nightBefore();
    nightAfter();

    await service().refresh(d.id);

    final r = (await records.forDive(d.id))!;
    expect(r.heartRateSamples, isEmpty);
    expect(r.avgHeartRate, isNull);
    expect(r.heartRateAtExit, 100);
    expect(r.sleepBeforeMinutes, 420);
    expect(r.settled, isTrue);
  });

  test('skips a draft that is still open', () async {
    final d = await dive(openDraft: true);
    duringAndAfter();

    await service().refresh(d.id);

    expect(await records.forDive(d.id), isNull);
    expect(health.reads, 0);
  });

  test('reads again until the night after arrives, then stops', () async {
    final d = await dive();
    duringAndAfter();
    nightBefore();

    await service(now: local(17, 12)).refreshPending();
    final first = (await records.forDive(d.id))!;
    expect(first.overnightHrvMs, isNull);
    expect(first.settled, isFalse);

    nightAfter();
    await service(now: local(18, 12)).refreshPending();
    final second = (await records.forDive(d.id))!;
    expect(second.overnightHrvMs, 45);
    expect(second.settled, isTrue);

    final reads = health.reads;
    await service(now: local(18, 13)).refreshPending();
    expect(health.reads, reads);
  });

  test('settles three days after the dive with what it has', () async {
    final d = await dive();
    duringAndAfter();
    await service(now: local(17, 12)).refreshPending();

    await service(now: local(20, 11, 46)).refreshPending();

    final r = (await records.forDive(d.id))!;
    expect(r.overnightHrvMs, isNull);
    expect(r.settled, isTrue);
    final reads = health.reads;
    await service(now: local(20, 12)).refreshPending();
    expect(health.reads, reads);
  });
}
