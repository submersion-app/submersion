import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';

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
      return query.get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get scheduled notifications for equipment: $equipmentId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Check if a notification is already scheduled
  Future<bool> isScheduled({
    required String equipmentId,
    required int reminderDaysBefore,
    required DateTime scheduledDate,
  }) async {
    try {
      final query = _db.select(_db.scheduledNotifications)
        ..where((t) => t.equipmentId.equals(equipmentId))
        ..where((t) => t.reminderDaysBefore.equals(reminderDaysBefore))
        ..where(
          (t) => t.scheduledDate.equals(scheduledDate.millisecondsSinceEpoch),
        );
      final result = await query.getSingleOrNull();
      return result != null;
    } catch (e, stackTrace) {
      _log.error('Failed to check if notification is scheduled', e, stackTrace);
      return false;
    }
  }

  /// Record a scheduled notification
  Future<void> recordScheduled({
    required String equipmentId,
    required DateTime scheduledDate,
    required int reminderDaysBefore,
    required int notificationId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.scheduledNotifications)
          .insert(
            ScheduledNotificationsCompanion(
              id: Value(id),
              equipmentId: Value(equipmentId),
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
      _log.error('Failed to record scheduled notification', e, stackTrace);
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
        e,
        stackTrace,
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
      _log.error('Failed to delete all scheduled notifications', e, stackTrace);
      rethrow;
    }
  }

  /// Get all scheduled notifications
  Future<List<ScheduledNotification>> getAll() async {
    try {
      return _db.select(_db.scheduledNotifications).get();
    } catch (e, stackTrace) {
      _log.error('Failed to get all scheduled notifications', e, stackTrace);
      rethrow;
    }
  }

  /// Delete expired scheduled notification records
  Future<void> deleteExpired() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.delete(
        _db.scheduledNotifications,
      )..where((t) => t.scheduledDate.isSmallerThanValue(now))).go();
      _log.info('Deleted expired scheduled notification records');
    } catch (e, stackTrace) {
      _log.error('Failed to delete expired notifications', e, stackTrace);
      rethrow;
    }
  }
}
