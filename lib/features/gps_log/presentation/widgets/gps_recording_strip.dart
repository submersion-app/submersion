import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App-wide slim banner shown while a GPS track recording is active.
///
/// MainScaffold renders it above the bottom nav (phones) or at the bottom of
/// the content area (rail layouts). It renders nothing while idle, so it is
/// naturally absent on platforms that cannot record.
class GpsRecordingStrip extends ConsumerWidget {
  const GpsRecordingStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorder = ref.watch(gpsTrackRecorderProvider);
    final state = ref.watch(gpsRecorderStateProvider).value ?? recorder.state;
    if (state.status != GpsRecorderStatus.recording) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      child: InkWell(
        onTap: () => context.go('/gps-log'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.fiber_manual_record,
                size: 12,
                color: colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.gpsLogger_stripStatus(state.pointCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
