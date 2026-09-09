import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

/// reminder_days_before value that marks a usage-clock reminder (v202).
/// Date reminders use the positive days-before values from settings.
const int kUsageReminderDaysBefore = -1;

/// Repository for tracking scheduled notifications
class ScheduledNotificationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(ScheduledNotificationRepository);

  /// Get all scheduled notifications for an equipment item
  Future<List<ScheduledNotification>> getForEquipment(
    String equipmentId,
  ) async {
    try {
      final query = _db.select(_db.scheduledNotifications)
        ..where((t) => t.equipmentId.equals(equipmentId));
      return await query.get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get scheduled notifications for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check if a notification is already scheduled. When [scheduleId] is
  /// given, the match is per service clock (v122 multi-clock ledger).
  Future<bool> isScheduled({
    required String equipmentId,
    required int reminderDaysBefore,
    required DateTime scheduledDate,
    String? scheduleId,
  }) async {
    try {
      final query = _db.select(_db.scheduledNotifications)
        ..where((t) => t.equipmentId.equals(equipmentId))
        ..where((t) => t.reminderDaysBefore.equals(reminderDaysBefore))
        ..where(
          (t) => t.scheduledDate.equals(scheduledDate.millisecondsSinceEpoch),
        );
      if (scheduleId != null) {
        query.where((t) => t.scheduleId.equals(scheduleId));
      }
      final result = await query.getSingleOrNull();
      return result != null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to check if notification is scheduled',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Whether a usage-clock reminder for [scheduleId] is recorded against
  /// [anchor]. A usage row stores the clock anchor it was armed against in
  /// `created_at` (see [recordScheduled]), so one reminder exists per anchor:
  /// a service record moves the anchor and the scheduler re-arms.
  Future<bool> hasUsageReminder({
    required String scheduleId,
    required DateTime anchor,
  }) async {
    final row =
        await (_db.select(_db.scheduledNotifications)
              ..where((t) => t.scheduleId.equals(scheduleId))
              ..where(
                (t) => t.reminderDaysBefore.equals(kUsageReminderDaysBefore),
              )
              ..where((t) => t.createdAt.equals(anchor.millisecondsSinceEpoch))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Delete one ledger row by its id (used when a usage reminder is
  /// reconciled away because its clock is no longer due).
  Future<void> deleteById(String id) async {
    await (_db.delete(
      _db.scheduledNotifications,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Record a scheduled notification. [createdAt] defaults to now; usage
  /// reminders pass the clock anchor instead, so the row is tied to the
  /// anchor it was armed against rather than to the wall clock.
  Future<void> recordScheduled({
    required String equipmentId,
    required DateTime scheduledDate,
    required int reminderDaysBefore,
    required int notificationId,
    String? scheduleId,
    int? createdAt,
  }) async {
    try {
      final id = _uuid.v4();
      final now = createdAt ?? DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.scheduledNotifications)
          .insert(
            ScheduledNotificationsCompanion(
              id: Value(id),
              equipmentId: Value(equipmentId),
              scheduleId: Value(scheduleId),
              scheduledDate: Value(scheduledDate.millisecondsSinceEpoch),
              reminderDaysBefore: Value(reminderDaysBefore),
              notificationId: Value(notificationId),
              createdAt: Value(now),
            ),
          );

      _log.info(
        'Recorded scheduled notification for equipment $equipmentId, '
        '$reminderDaysBefore days before',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to record scheduled notification',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete scheduled notification records for equipment
  Future<void> deleteForEquipment(String equipmentId) async {
    try {
      await (_db.delete(
        _db.scheduledNotifications,
      )..where((t) => t.equipmentId.equals(equipmentId))).go();
      _log.info('Deleted scheduled notifications for equipment $equipmentId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete scheduled notifications for equipment',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete all scheduled notification records
  Future<void> deleteAll() async {
    try {
      await _db.delete(_db.scheduledNotifications).go();
      _log.info('Deleted all scheduled notification records');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete all scheduled notifications',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all scheduled notifications
  Future<List<ScheduledNotification>> getAll() async {
    try {
      return await _db.select(_db.scheduledNotifications).get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all scheduled notifications',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete expired scheduled notification records
  Future<void> deleteExpired() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Usage-clock rows are the dedupe record for their anchor and outlive
      // their fire date; the equipment-level cancel paths delete them.
      await (_db.delete(_db.scheduledNotifications)..where(
            (t) =>
                t.scheduledDate.isSmallerThanValue(now) &
                t.reminderDaysBefore.isBiggerOrEqualValue(0),
          ))
          .go();
      _log.info('Deleted expired scheduled notification records');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete expired notifications',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
