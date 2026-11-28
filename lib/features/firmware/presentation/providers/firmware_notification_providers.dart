import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_settings_providers.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// More new updates than this at once send one summary instead.
const int _maxSingleNotices = 3;

/// One firmware notification to show.
typedef FirmwareNotice = ({
  String equipmentId,
  String title,
  String body,
  String payload,
});

/// Shows a [FirmwareNotice] as a system notification. A provider so tests can
/// record what would be shown.
final firmwareNoticeSenderProvider =
    Provider<Future<void> Function(FirmwareNotice notice)>(
      (ref) =>
          (notice) => NotificationService.instance.showFirmwareUpdate(
            key: notice.equipmentId,
            title: notice.title,
            body: notice.body,
            payload: notice.payload,
          ),
    );

/// The language firmware notifications are written in: the app's.
final firmwareNoticeL10nProvider = Provider<AppLocalizations>(
  (ref) => l10nForLocaleTag(ref.watch(localeProvider)),
);

String _pairOf(FirmwareUpdateEntry u) =>
    '${u.item.id}|${u.status.latest.version}';

/// The updates whose item and newest version have not been notified yet.
List<FirmwareUpdateEntry> firmwareUpdatesToNotify(
  List<FirmwareUpdateEntry> updates,
  Set<String> notifiedPairs,
) => [
  for (final u in updates)
    if (!notifiedPairs.contains(_pairOf(u))) u,
];

final _log = LoggerService.forClass(FirmwareNoticeSync);

/// Marker type for this file's log lines.
abstract final class FirmwareNoticeSync {}

/// Notifies each new firmware update once per item and newest version
/// (issue #5104), remembering the pairs on this device. More than three new
/// at once send one summary that opens the equipment list. Re-runs whenever
/// the updates or the switches change; listened to for the app's lifetime.
final firmwareNotificationSyncProvider = FutureProvider<void>((ref) async {
  final checks = ref.watch(firmwareChecksEnabledProvider);
  final notify = ref.watch(firmwareNotificationsEnabledProvider);
  if (!checks || !notify) return;
  final updates = await ref.watch(firmwareUpdatesProvider.future);
  final prefs = ref.read(sharedPreferencesProvider);
  final notified = {
    ...?prefs.getStringList(SettingsKeys.firmwareNotifiedPairs),
  };
  final fresh = firmwareUpdatesToNotify(updates, notified);
  if (fresh.isEmpty) return;

  // Claimed before anything is sent: a re-run that starts while a send is
  // in flight then sees the pairs and sends nothing. A send that fails is
  // not retried; the item page, list and dashboard still show the update.
  await prefs.setStringList(SettingsKeys.firmwareNotifiedPairs, [
    ...notified,
    for (final u in fresh) _pairOf(u),
  ]);
  final l10n = ref.read(firmwareNoticeL10nProvider);
  final send = ref.read(firmwareNoticeSenderProvider);
  try {
    if (fresh.length > _maxSingleNotices) {
      await send((
        equipmentId: kFirmwareUpdatesPayload,
        title: l10n.firmware_notify_summaryTitle,
        body: l10n.firmware_notify_summaryBody,
        payload: kFirmwareUpdatesPayload,
      ));
    } else {
      for (final u in fresh) {
        final version = u.status.latest.version;
        await send((
          equipmentId: u.item.id,
          title: l10n.firmware_notify_title(u.item.name),
          body: isSafetyUpdate(u.status)
              ? l10n.firmware_notify_bodySafety(version)
              : l10n.firmware_notify_body(version),
          payload: u.item.id,
        ));
      }
    }
  } catch (e, stackTrace) {
    _log.error(
      'Firmware update notification failed',
      error: e,
      stackTrace: stackTrace,
    );
  }
});
