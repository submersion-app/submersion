import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Recording only makes sense on the device that goes on the boat.
/// defaultTargetPlatform (not dart:io) so widget tests can override it.
bool get canRecordGpsTracks =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Starts and stops the surface GPS logger (discussion #289), with the live
/// point count and last-fix age while a recording runs.
class GpsRecordCard extends ConsumerWidget {
  const GpsRecordCard({super.key});

  static String _formatAge(DateTime lastFixAt) {
    final age = DateTime.now().toUtc().difference(lastFixAt);
    if (age.inMinutes < 1) return '<1min';
    return formatCompactDuration(age);
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Read before any await: the card may rebuild or leave the tree while
    // the permission prompt is up.
    final recorder = ref.read(gpsTrackRecorderProvider);
    if (!await Geolocator.isLocationServiceEnabled()) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsLogger_locationOff)),
      );
      return;
    }
    var permission = await LocationService.instance.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await LocationService.instance.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsLogger_permissionDenied)),
      );
      return;
    }
    await recorder.start(
      notificationTitle: l10n.gpsLogger_androidNotificationTitle,
      notificationText: l10n.gpsLogger_androidNotificationText,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recorder = ref.watch(gpsTrackRecorderProvider);
    final state = ref.watch(gpsRecorderStateProvider).value ?? recorder.state;
    final recording = state.status == GpsRecorderStatus.recording;
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recording) ...[
              Text(
                l10n.gpsLogger_recordingStatus(state.pointCount),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                state.lastFixAt != null
                    ? l10n.gpsLogger_lastFix(
                        _formatAge(state.lastFixAt!),
                        units.formatDistance(state.lastFixAccuracy ?? 0),
                      )
                    : l10n.gpsLogger_noFixYet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.stop),
                label: Text(l10n.gpsLogger_stopButton),
                onPressed: recorder.stop,
              ),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.gps_fixed),
                label: Text(l10n.gpsLogger_startButton),
                onPressed: () => _start(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}
