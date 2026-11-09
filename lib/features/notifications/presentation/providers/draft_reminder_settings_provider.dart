import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// "Remind me about draft dives" (issue #637), kept on this device: the
/// reminder is a local notification, and another device's diver may not
/// want it. Off by default.
class DraftReminderSettingNotifier extends StateNotifier<bool> {
  DraftReminderSettingNotifier(this._prefs)
    : super(_prefs.getBool(SettingsKeys.draftDownloadReminder) ?? false);

  final SharedPreferences _prefs;

  /// Saves before it announces, so a scheduler that reads the preference on
  /// the change sees the new value.
  Future<void> set(bool on) async {
    await _prefs.setBool(SettingsKeys.draftDownloadReminder, on);
    state = on;
  }
}

final draftReminderSettingProvider =
    StateNotifierProvider<DraftReminderSettingNotifier, bool>(
      (ref) =>
          DraftReminderSettingNotifier(ref.watch(sharedPreferencesProvider)),
    );

final _log = LoggerService.forClass(NotificationScheduler);

/// Keeps the draft reminders in step (issue #637): re-run on every dive
/// change, so a draft that surfaces gets its reminder and one filled,
/// completed or deleted, here or on another device, loses it; and on the
/// switch, the reminder time and the diver. Listened to for the app's
/// lifetime; never fails.
final draftReminderSyncProvider = FutureProvider<void>((ref) async {
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  ref.watch(draftReminderSettingProvider);
  ref.watch(
    settingsProvider.select(
      (s) => (s.notificationsEnabled, s.reminderTime, s.locale),
    ),
  );
  final diverId = ref.watch(currentDiverIdProvider);
  try {
    await ref
        .read(notificationSchedulerProvider)
        .updateDraftReminders(
          settings: ref.read(settingsProvider),
          diverId: diverId,
        );
  } catch (e, stackTrace) {
    _log.error(
      'Failed to update draft reminders',
      error: e,
      stackTrace: stackTrace,
    );
  }
});
