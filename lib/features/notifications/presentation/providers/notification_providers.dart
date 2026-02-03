import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
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

/// Provider to check if notification permission is granted
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.isPermissionGranted();
});

/// Provider that schedules notifications when settings or equipment changes
final notificationSchedulingProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(settingsProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);

  // Only schedule if notifications are enabled
  if (!settings.notificationsEnabled) return;

  await scheduler.scheduleAll(settings: settings, diverId: diverId);
});
