import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/documents/data/services/clearance_delete_events.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Provider for the notification service singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Provider for the scheduled notification repository
final scheduledNotificationRepositoryProvider =
    Provider<ScheduledNotificationRepository>((ref) {
      return ScheduledNotificationRepository();
    });

/// Provider for the notification scheduler
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(
    notificationService: ref.watch(notificationServiceProvider),
    equipmentRepository: EquipmentRepository(),
    scheduledNotificationRepository: ref.watch(
      scheduledNotificationRepositoryProvider,
    ),
  );
});

/// Re-arms the medical clearances of every diver a delete took one from
/// (#4609), so the clearance it superseded reminds again: a delete on the
/// documents page or by the agent, and a record's delete taking the
/// documents filed under it. The app keeps it alive from its root.
///
/// Events are handled one at a time, so each re-reads the clearances
/// after the one before has armed what it read; with the cancel of the
/// deleted ids that ends each one, a re-arm that read a clearance a later
/// delete took cannot leave it reminding.
final clearanceDeleteRearmProvider = Provider<void>((ref) {
  final log = LoggerService.forClass(NotificationScheduler);
  var disposed = false;
  Future<void> rearm(Map<String, Set<String>> deletedByDiver) async {
    if (disposed) return;
    final scheduler = ref.read(notificationSchedulerProvider);
    // Until the current diver's settings land, [settingsProvider] holds the
    // defaults or the previous diver's: notifications on, or the wrong time.
    try {
      await ref.read(settingsProvider.notifier).settingsLoaded;
    } catch (_) {
      // A failed load leaves the defaults in place, as every caller does.
    }
    if (disposed) return;
    final settings = ref.read(settingsProvider);
    for (final MapEntry(key: diverId, value: deletedIds)
        in deletedByDiver.entries) {
      // A reminder failure never fails the delete: the next full
      // reschedule repairs it.
      try {
        await scheduler.updateClearancesForDiver(
          diverId,
          settings,
          deletedIds: deletedIds,
        );
      } catch (e, stackTrace) {
        log.warning(
          'Clearance reminders of $diverId not re-armed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  var turn = Future<void>.value();
  final sub = ClearanceDeleteEvents.stream.listen((deletedByDiver) {
    turn = turn.then((_) => rearm(deletedByDiver));
  });
  ref.onDispose(() {
    disposed = true;
    sub.cancel();
  });
});

/// Provider to check if notification permission is granted
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.isPermissionGranted();
});

/// Provider that schedules notifications when settings or equipment changes
final notificationSchedulingProvider = FutureProvider<void>((ref) async {
  // Everything [NotificationScheduler] reads. Rescheduling walks all the gear,
  // so it sits out an edit that cannot move a reminder (issue #3818).
  ref.watch(
    settingsProvider.select(
      (s) => (
        s.notificationsEnabled,
        s.serviceReminderDays,
        s.reminderTime,
        s.tripServiceLeadDays,
        s.locale,
        exposureThresholdsFromSettings(s),
      ),
    ),
  );
  final settings = ref.read(settingsProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);

  // Only schedule if notifications are enabled
  if (!settings.notificationsEnabled) return;

  await scheduler.scheduleAll(settings: settings, diverId: diverId);
});
