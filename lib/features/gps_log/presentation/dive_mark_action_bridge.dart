import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/dive_mark_actions.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/draft_conditions_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gps_log/data/services/dive_mark_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/notifications/presentation/providers/draft_reminder_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The step the lock screen notification offers (issue #637): none while
/// nothing records, Surfaced while a dive is open on this device (whoever's
/// it is, the one Surfaced closes), else Entered water.
final diveMarkNotificationActionProvider = Provider<DiveMarkAction?>((ref) {
  final recording =
      ref.watch(gpsRecorderStateProvider).value?.status ==
      GpsRecorderStatus.recording;
  if (!recording) return null;
  final open = ref.watch(markingDraftProvider).value;
  return nextDiveMarkAction(draftOpen: open != null);
});

/// Sends each lock screen tap to the mark service with the time it arrived.
/// An Entered water tap with no current diver has no one to mark.
StreamSubscription<void> routeDiveMarkTaps(
  Stream<DiveMarkTap> taps, {
  required DiveMarkService Function() marks,
  required String? Function() currentDiverId,
}) => taps
    .asyncMap((tap) async {
      switch (tap.action) {
        case DiveMarkAction.enteredWater:
          final diverId = currentDiverId();
          if (diverId != null) {
            await marks().enteredWater(diverId: diverId, at: tap.at);
          }
        case DiveMarkAction.surfaced:
          await marks().surfaced(at: tap.at);
      }
    })
    .listen(
      null,
      // A failed write is logged, never left as an unhandled async error;
      // the next tap still goes through.
      onError: (Object e, StackTrace stackTrace) => _log.error(
        'Failed to mark a dive from the lock screen',
        error: e,
        stackTrace: stackTrace,
      ),
    );

final _log = LoggerService.forClass(DiveMarkService);

/// Starts the lock screen dive marks for the app's lifetime: taps reach the
/// mark service, and the notification follows the recording and the open
/// draft. Cancel the returned subscription on dispose.
StreamSubscription<void> startDiveMarkActionBridge(WidgetRef ref) {
  // The drafts these marks make get their download reminders, and their
  // weather and tide from where the diver went in (issue #637).
  for (final sync in [draftReminderSyncProvider, draftConditionsSyncProvider]) {
    ref.listenManual<AsyncValue<void>>(sync, (_, _) {}, fireImmediately: true);
  }
  ref.listenManual<DiveMarkAction?>(diveMarkNotificationActionProvider, (
    _,
    action,
  ) {
    final service = NotificationService.instance;
    if (action == null) {
      unawaited(service.cancelDiveMarkActions());
      return;
    }
    final l10n = l10nForLocaleTag(ref.read(localeProvider));
    unawaited(
      service.showDiveMarkActions(
        action: action,
        actionLabel: action == DiveMarkAction.enteredWater
            ? l10n.gpsLogger_enteredWater
            : l10n.gpsLogger_surfaced,
        title: l10n.gpsLogger_markNotification_title,
        body: action == DiveMarkAction.enteredWater
            ? l10n.gpsLogger_markNotification_bodyEnter
            : l10n.gpsLogger_markNotification_bodySurface,
      ),
    );
  });
  return routeDiveMarkTaps(
    DiveMarkActions.instance.taps,
    marks: () => ref.read(diveMarkServiceProvider),
    currentDiverId: () => ref.read(currentDiverIdProvider),
  );
}
