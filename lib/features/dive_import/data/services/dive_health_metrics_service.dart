import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_import/domain/entities/health_sample.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/domain/services/health_metrics_calculator.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_health_record_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_health_record.dart';

/// Reads a dive's heart rate, recovery and sleep from Apple Health into its
/// health record (issue #637), for the diver the switch is bound to.
///
/// Values Health does not have yet (the night after, above all) are read
/// again on later app opens until every one is in or the dive ended
/// [settleAfter] ago; then the record is settled and Health is not asked
/// again.
class DiveHealthMetricsService {
  DiveHealthMetricsService({
    required HealthImportService health,
    required DiveRepository dives,
    required DiveHealthRecordRepository records,
    required String? Function() metricsDiverId,
    DateTime Function()? clock,
  }) : _health = health,
       _dives = dives,
       _records = records,
       _diverId = metricsDiverId,
       _clock = clock ?? DateTime.now;

  final HealthImportService _health;
  final DiveRepository _dives;
  final DiveHealthRecordRepository _records;
  final String? Function() _diverId;
  final DateTime Function() _clock;

  /// How long after a dive its record keeps waiting for missing values.
  static const settleAfter = Duration(days: 3);

  /// How far back [refreshPending] looks: a day past [settleAfter], so a
  /// dive that was waiting gets its last read and is settled.
  static const _lookBack = Duration(days: 4);

  /// The recovery moments reach 15 minutes past the exit, give or take.
  static const _recoveryReach = Duration(minutes: 17);

  /// The night after the day's last dive starts within 18 hours and may
  /// last 12.
  static const _nightReach = Duration(hours: 30);

  static final _log = LoggerService.forClass(DiveHealthMetricsService);

  /// Reads [diveId]'s readings now, whether or not its record is settled.
  Future<void> refresh(String diveId) =>
      _refresh(diveId, _clock(), _NightReads());

  /// Reads every recent dive of the bound diver whose record is missing or
  /// not settled. One dive failing does not stop the others.
  Future<void> refreshPending({DateTime? now}) async {
    final diverId = _diverId();
    if (diverId == null) return;
    final at = now ?? _clock();
    final ids = await _records.unsettledDiveIds(
      diverId: diverId,
      since: asWallClockUtc(at.subtract(_lookBack).toLocal()),
    );
    // Dives of one day share their night: it is read once.
    final nights = _NightReads();
    for (final id in ids) {
      try {
        await _refresh(id, at, nights);
      } catch (e, stackTrace) {
        _log.error(
          'Reading Apple Health for a dive failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _refresh(String diveId, DateTime now, _NightReads nights) async {
    final diverId = _diverId();
    if (diverId == null) return;
    final dive = await _dives.getDiveById(diveId);
    if (dive == null || dive.diverId != diverId) return;
    if (dive.isPlanned && !dive.isDraft) return;
    final exitWall = _exitOf(dive);
    if (exitWall == null) return;
    final entryWall = dive.entryTime ?? dive.dateTime;
    final entry = fromWallClockUtc(entryWall).toUtc();
    final exit = fromWallClockUtc(exitWall).toUtc();

    final day = await _sameDay(dive, diverId);
    final firstEntry = fromWallClockUtc(
      day.map((d) => d.entryTime ?? d.dateTime).reduce(_earlier),
    );
    final lastExit = fromWallClockUtc(
      day.map(_exitOf).whereType<DateTime>().reduce(_later),
    ).toUtc();
    final eveningBefore = DateTime(
      firstEntry.year,
      firstEntry.month,
      firstEntry.day - 1,
      18,
    ).toUtc();

    final heartRate = await _health.fetchHeartRate(
      start: entry,
      end: exit.add(_recoveryReach),
    );
    final sleep = await (nights.sleep[(eveningBefore, lastExit)] ??= _health
        .fetchSleep(start: eveningBefore, end: lastExit.add(_nightReach)));
    final hrv = await (nights.hrv[lastExit] ??= _health.fetchHrv(
      start: lastExit,
      end: lastExit.add(_nightReach),
    ));

    final ownHeartRate = (await _dives.getDiveProfile(
      diveId,
    )).any((p) => p.heartRate != null && p.heartRateSource != 'appleWatch');
    final inDive = [
      for (final s in heartRate)
        if (!s.at.isAfter(exit)) s,
    ];
    final summary = ownHeartRate ? null : summarizeHeartRate(inDive);
    final offsets = ownHeartRate
        ? const <List<int>>[]
        : heartRateSeries(inDive, from: entry);
    final recovery = recoveryAfter(heartRate, exit);

    final existing = await _records.forDive(diveId);
    final read = DiveHealthRecord(
      id: existing?.id ?? '',
      diveId: diveId,
      heartRateSamples: offsets.isNotEmpty
          ? offsets
          : existing?.heartRateSamples ?? const [],
      avgHeartRate: summary?.average ?? existing?.avgHeartRate,
      maxHeartRate: summary?.maximum ?? existing?.maxHeartRate,
      heartRateAtExit: recovery.atExit ?? existing?.heartRateAtExit,
      heartRateExitPlus5: recovery.plus5 ?? existing?.heartRateExitPlus5,
      heartRateExitPlus15: recovery.plus15 ?? existing?.heartRateExitPlus15,
      overnightHrvMs:
          overnightHrv(hrv, sleep, lastExit) ?? existing?.overnightHrvMs,
      sleepBeforeMinutes:
          sleepBeforeMinutes(sleep, firstEntry) ?? existing?.sleepBeforeMinutes,
      fetchedAt: now,
    );
    final complete =
        (ownHeartRate ||
            (read.heartRateSamples.isNotEmpty && read.avgHeartRate != null)) &&
        read.heartRateAtExit != null &&
        read.heartRateExitPlus5 != null &&
        read.heartRateExitPlus15 != null &&
        read.overnightHrvMs != null &&
        read.sleepBeforeMinutes != null;
    final record = read.copyWith(
      settled: complete || now.difference(exit) > settleAfter,
    );

    // Nothing found and nothing kept: no row. The dive is asked again on
    // later opens until it falls out of the look-back window.
    if (existing == null && !_hasAnything(record)) return;
    // Nothing changed: no write, so sync has nothing to carry.
    if (existing != null &&
        record.copyWith(fetchedAt: existing.fetchedAt) == existing) {
      return;
    }
    await _records.upsert(record);
  }

  /// [diverId]'s logged dives on [dive]'s calendar day, [dive] included.
  Future<List<Dive>> _sameDay(Dive dive, String diverId) async {
    final start = dive.entryTime ?? dive.dateTime;
    final dayStart = DateTime.utc(start.year, start.month, start.day);
    final dayEnd = dayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final found = await _dives.getDivesInRange(
      dayStart,
      dayEnd,
      diverId: diverId,
    );
    return [
      dive,
      for (final d in found)
        if (d.id != dive.id && !(d.isPlanned && !d.isDraft)) d,
    ];
  }

  static DateTime? _exitOf(Dive dive) {
    if (dive.exitTime != null) return dive.exitTime;
    final runtime = dive.effectiveRuntime;
    if (runtime == null) return null;
    return (dive.entryTime ?? dive.dateTime).add(runtime);
  }

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static bool _hasAnything(DiveHealthRecord r) =>
      r.heartRateSamples.isNotEmpty ||
      r.avgHeartRate != null ||
      r.heartRateAtExit != null ||
      r.heartRateExitPlus5 != null ||
      r.heartRateExitPlus15 != null ||
      r.overnightHrvMs != null ||
      r.sleepBeforeMinutes != null;
}

/// Sleep and HRV reads of one pass, by the window they cover, so the dives
/// of one day ask Health for their night once.
class _NightReads {
  final sleep = <(DateTime, DateTime), Future<List<SleepInterval>>>{};
  final hrv = <DateTime, Future<List<HealthSample>>>{};
}
