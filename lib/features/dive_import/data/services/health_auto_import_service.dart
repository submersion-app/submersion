import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_import/data/services/apple_watch_computer.dart';
import 'package:submersion/features/dive_import/data/services/health_dive_writer.dart';
import 'package:submersion/features/dive_import/data/services/health_fill_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_dive_classifier.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// What one automatic Apple Health import did, for the diver's message.
class HealthAutoImportResult {
  const HealthAutoImportResult({
    this.newDiveIds = const [],
    this.filledDraftIds = const [],
    this.consolidatedIds = const [],
    this.reviewWorkoutIds = const [],
    this.planReviewWorkoutIds = const [],
  });

  /// New dives, one per workout.
  final List<String> newDiveIds;

  /// The dives drafts became once a workout filled them.
  final List<String> filledDraftIds;

  /// Logged dives a workout joined as a second set of readings.
  final List<String> consolidatedIds;

  /// Workouts that wait for the diver, announced for the first time.
  final List<String> reviewWorkoutIds;

  /// Workouts on a plan's day that wait for the diver, announced for the
  /// first time.
  final List<String> planReviewWorkoutIds;

  bool get isEmpty =>
      newDiveIds.isEmpty &&
      filledDraftIds.isEmpty &&
      consolidatedIds.isEmpty &&
      reviewWorkoutIds.isEmpty &&
      planReviewWorkoutIds.isEmpty;
}

/// Imports Apple Watch dives without the wizard (issue #637), at app start
/// and on resume. Each new workout fills a draft, joins a downloaded dive or
/// imports as new; a plan's day and an unclear match wait for the diver and
/// are reported once. The workouts read are those since the last run, less a
/// day of overlap for a workout Health stored late.
class HealthAutoImportService {
  HealthAutoImportService({
    required HealthImportService health,
    required SharedPreferences prefs,
    required String? Function() boundDiverId,
    required DiveRepository dives,
    HealthDiveWriter? writer,
    HealthFillService? filler,
    DiveConsolidationService? consolidation,
    Future<Set<String>> Function(Iterable<String> diveIds)? deletedDiveIds,
  }) : _health = health,
       _deletedDiveIds =
           deletedDiveIds ??
           ((ids) => SyncRepository().deletedIds('dives', ids)),
       _prefs = prefs,
       _boundDiverId = boundDiverId,
       _dives = dives,
       _writer = writer ?? HealthDiveWriter(dives: dives),
       _consolidation = consolidation ?? DiveConsolidationService(dives) {
    _filler =
        filler ??
        HealthFillService(
          dives: dives,
          writer: _writer,
          consolidation: _consolidation,
        );
  }

  static final _log = LoggerService.forClass(HealthAutoImportService);

  /// How far before the last run the next one reads again.
  static const overlap = Duration(days: 1);

  /// How far back the first run reads.
  static const firstRunReach = Duration(days: 7);

  /// How long handled and announced workout ids are remembered: well past
  /// [overlap], so a workout is never handled twice.
  static const memory = Duration(days: 14);

  static const _handledKey = 'health_handled_workouts';

  final HealthImportService _health;
  final SharedPreferences _prefs;
  final String? Function() _boundDiverId;
  final DiveRepository _dives;
  final HealthDiveWriter _writer;
  final DiveConsolidationService _consolidation;
  late final HealthFillService _filler;

  /// The watch dive ids among those given that were deleted, here or on a
  /// peer: a workout merged into a downloaded dive leaves its watch dive's
  /// tombstone and nothing else, and is never merged again.
  final Future<Set<String>> Function(Iterable<String> diveIds) _deletedDiveIds;

  Future<HealthAutoImportResult> run({DateTime? now}) async {
    final diverId = _boundDiverId();
    if (diverId == null) return const HealthAutoImportResult();
    if (!(await _health.permissionStatus()).canAttemptRead) {
      return const HealthAutoImportResult();
    }
    final end = now ?? DateTime.now();
    final watermark = _prefs.getInt(SettingsKeys.healthImportWatermark);
    final start = watermark == null
        ? end.subtract(firstRunReach)
        : DateTime.fromMillisecondsSinceEpoch(
            watermark,
            isUtc: end.isUtc,
          ).subtract(overlap);

    final handled = _readIds(_handledKey, end);
    final announced = _readIds(SettingsKeys.healthReviewAnnounced, end);
    final workouts = await _health.fetchDives(startDate: start, endDate: end);
    // Health reads by true instant; dives store a wall clock flagged UTC,
    // so the dive query takes the same window on the diver's clock.
    final nearby = await _dives.getDivesInRange(
      asWallClockUtc(start.toLocal()).subtract(const Duration(hours: 6)),
      asWallClockUtc(end.toLocal()).add(const Duration(hours: 6)),
      diverId: diverId,
    );
    final deleted = await _deletedDiveIds([
      for (final w in workouts)
        healthDiveId(diverId: diverId, workoutUuid: w.sourceId),
    ]);
    final fresh = <ImportedDive>[];
    for (final w in workouts) {
      if (handled.containsKey(w.sourceId)) continue;
      if (nearby.any((d) => d.importId == w.sourceId)) continue;
      final id = healthDiveId(diverId: diverId, workoutUuid: w.sourceId);
      if (deleted.contains(id)) continue;
      if (await _dives.getDiveById(id) != null) continue;
      fresh.add(w);
    }

    final routes = classifyHealthDives(
      fresh,
      unfilled: await _dives.getUnfilledDives(diverId: diverId),
      loggedNear: [
        for (final d in nearby)
          if (!d.isPlanned && !d.isDraft) d,
      ],
    );

    final newIds = <String>[];
    final filled = <String>[];
    final consolidated = <String>[];
    final review = <String>[];
    final planReview = <String>[];
    final stamp = end.millisecondsSinceEpoch;
    for (var i = 0; i < fresh.length; i++) {
      final w = fresh[i];
      try {
        switch (routes[i]) {
          case FillDraft(:final diveId):
            filled.add(
              await _filler.fill(
                targetDiveId: diveId,
                workout: w,
                diverId: diverId,
              ),
            );
            handled[w.sourceId] = stamp;
          case Consolidate(:final diveId):
            final watchDive = await _writer.importAsNew(w, diverId: diverId);
            await _consolidation.apply(
              targetDiveId: diveId,
              secondaryDiveIds: [watchDive.id],
            );
            consolidated.add(diveId);
            handled[w.sourceId] = stamp;
          case ImportNew():
            final dive = await _writer.importAsNew(w, diverId: diverId);
            newIds.add(dive.id);
            handled[w.sourceId] = stamp;
          case FillPlan():
            if (announced.putIfAbsent(w.sourceId, () => stamp) == stamp) {
              planReview.add(w.sourceId);
            }
          case NeedsReview():
            if (announced.putIfAbsent(w.sourceId, () => stamp) == stamp) {
              review.add(w.sourceId);
            }
        }
      } catch (e, stackTrace) {
        // One workout's failure leaves the others, and the next run retries.
        _log.error(
          'Automatic Apple Health import of ${w.sourceId} failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    await _writeIds(_handledKey, handled);
    await _writeIds(SettingsKeys.healthReviewAnnounced, announced);
    await _prefs.setInt(SettingsKeys.healthImportWatermark, stamp);
    return HealthAutoImportResult(
      newDiveIds: newIds,
      filledDraftIds: filled,
      consolidatedIds: consolidated,
      reviewWorkoutIds: review,
      planReviewWorkoutIds: planReview,
    );
  }

  /// Workout id to the time it was handled, minus those older than
  /// [memory]. Stored as "id=millis" strings.
  Map<String, int> _readIds(String key, DateTime now) {
    final cutoff = now.subtract(memory).millisecondsSinceEpoch;
    final result = <String, int>{};
    for (final entry in _prefs.getStringList(key) ?? const <String>[]) {
      final split = entry.lastIndexOf('=');
      if (split <= 0) continue;
      final at = int.tryParse(entry.substring(split + 1));
      if (at == null || at < cutoff) continue;
      result[entry.substring(0, split)] = at;
    }
    return result;
  }

  Future<void> _writeIds(String key, Map<String, int> ids) => _prefs
      .setStringList(key, [for (final e in ids.entries) '${e.key}=${e.value}']);
}
