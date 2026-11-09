import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_import/data/services/health_auto_import_service.dart';
import 'package:submersion/features/dive_import/data/services/health_dive_writer.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/health_settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The automatic Apple Health import (issue #637), or null where Health is
/// not available.
// no-tick: builds the HealthAutoImportService SERVICE, not a query result;
// every read happens when it runs.
final healthAutoImportServiceProvider = Provider<HealthAutoImportService?>((
  ref,
) {
  final health = ref.watch(healthImportServiceProvider);
  if (health == null) return null;
  final dives = ref.watch(diveRepositoryProvider);
  return HealthAutoImportService(
    health: health,
    prefs: ref.watch(sharedPreferencesProvider),
    boundDiverId: () => ref.read(healthSettingsProvider).autoImportDiverId,
    dives: dives,
    writer: HealthDiveWriter(
      dives: dives,
      tripForImports: ref.watch(importTripResolverProvider),
    ),
  );
});

/// What the diver hears after an import.
class HealthAutoImportMessage {
  const HealthAutoImportMessage({
    required this.title,
    required this.body,
    required this.payload,
    required this.actionLabel,
  });

  final String title;
  final String body;

  /// A notification payload; [notificationPayloadRoute] maps it to a route.
  final String payload;
  final String actionLabel;
}

/// The message for [result], or null when there is nothing to say: a quiet
/// run, or one that only joined dives the diver already has.
HealthAutoImportMessage? healthAutoImportMessage(
  HealthAutoImportResult result,
  AppLocalizations l10n,
) {
  final dives = [...result.newDiveIds, ...result.filledDraftIds];
  if (dives.isNotEmpty) {
    return HealthAutoImportMessage(
      title: dives.length == 1
          ? l10n.healthAutoImport_newDive_title
          : l10n.healthAutoImport_newDives_title(dives.length),
      body: l10n.healthAutoImport_newDive_body,
      payload: dives.length == 1
          ? '$kWatchDivePayloadPrefix${dives.single}'
          : kWatchDivesPayload,
      actionLabel: l10n.healthAutoImport_addDetails,
    );
  }
  if (result.reviewWorkoutIds.isNotEmpty ||
      result.planReviewWorkoutIds.isNotEmpty) {
    return HealthAutoImportMessage(
      title: l10n.healthAutoImport_review_title,
      body: result.reviewWorkoutIds.isNotEmpty
          ? l10n.healthAutoImport_review_body
          : l10n.healthAutoImport_planReview_body,
      payload: kHealthReviewPayload,
      actionLabel: l10n.healthAutoImport_review,
    );
  }
  return null;
}

/// Lets the import run at most once every [interval], so a burst of
/// resumes reads Health once.
class HealthAutoImportThrottle {
  HealthAutoImportThrottle({
    DateTime Function()? clock,
    this.interval = const Duration(minutes: 10),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration interval;
  DateTime? _last;

  /// True, and starts a new interval, when a run is due.
  bool take() {
    final now = _clock();
    final last = _last;
    if (last != null && now.difference(last) < interval) return false;
    _last = now;
    return true;
  }
}

final _log = LoggerService.forClass(HealthAutoImportService);

/// Runs the import if it is due, then tells the diver: a SnackBar through
/// [messenger] when the app is on screen, else a notification. [open]
/// follows the message's route.
Future<void> runHealthAutoImport(
  WidgetRef ref, {
  required HealthAutoImportThrottle throttle,
  required GlobalKey<ScaffoldMessengerState> messenger,
  required void Function(String route) open,
}) async {
  final service = ref.read(healthAutoImportServiceProvider);
  if (service == null || !throttle.take()) return;
  try {
    final result = await service.run();
    final messengerState = messenger.currentState;
    final context = messenger.currentContext;
    final l10n = context != null && context.mounted
        ? context.l10n
        : l10nForLocaleTag(ref.read(localeProvider));
    final message = healthAutoImportMessage(result, l10n);
    if (message == null) return;
    final route = notificationPayloadRoute(message.payload);
    if (messengerState != null) {
      messengerState.showSnackBar(
        SnackBar(
          content: Text('${message.title}. ${message.body}'),
          // A notice, not a question: it times out like any other.
          persist: false,
          action: route == null
              ? null
              : SnackBarAction(
                  label: message.actionLabel,
                  onPressed: () => open(route),
                ),
        ),
      );
    } else {
      await NotificationService.instance.showWatchDiveMessage(
        title: message.title,
        body: message.body,
        payload: message.payload,
      );
    }
  } catch (e, stackTrace) {
    _log.error(
      'Automatic Apple Health import failed',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
