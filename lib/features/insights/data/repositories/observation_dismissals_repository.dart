import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';

/// Dismissals of Insights observations (#2381). Rows are keyed by
/// [observationDismissalId] and never deleted here: Undo clears
/// `dismissed_at`, so a later re-dismissal never races a tombstone.
class ObservationDismissalsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(ObservationDismissalsRepository);

  static const entityType = 'insightObservationDismissals';

  /// The keys ([observationKey]) [diverId] has dismissed. Rows whose rule
  /// this build does not know are skipped, and left untouched in the table.
  Stream<Set<String>> watchDismissedKeys(String diverId) {
    final query = _db.select(_db.insightObservationDismissals)
      ..where((t) => t.diverId.equals(diverId) & t.dismissedAt.isNotNull());
    return query.watch().map(
      (rows) => {
        for (final r in rows)
          if (ObservationRuleId.fromDbValue(r.ruleId) case final rule?)
            observationKey(rule, r.fingerprint),
      },
    );
  }

  Future<void> dismiss({
    required String diverId,
    required ObservationRuleId rule,
    required String fingerprint,
  }) => _write(diverId, rule, fingerprint, dismissed: true);

  Future<void> undismiss({
    required String diverId,
    required ObservationRuleId rule,
    required String fingerprint,
  }) => _write(diverId, rule, fingerprint, dismissed: false);

  Future<void> _write(
    String diverId,
    ObservationRuleId rule,
    String fingerprint, {
    required bool dismissed,
  }) async {
    try {
      final now = clock.now().millisecondsSinceEpoch;
      final id = observationDismissalId(diverId, rule, fingerprint);
      final existing = await (_db.select(
        _db.insightObservationDismissals,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      await _db
          .into(_db.insightObservationDismissals)
          .insertOnConflictUpdate(
            InsightObservationDismissalsCompanion(
              id: Value(id),
              diverId: Value(diverId),
              ruleId: Value(rule.dbValue),
              fingerprint: Value(fingerprint),
              dismissedAt: Value(dismissed ? now : null),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to ${dismissed ? 'dismiss' : 'restore'} an observation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
