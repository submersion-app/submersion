import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// GPS surface track logger (discussion #289): record the phone's position
/// during a dive day; imported dives are matched to positions by timestamp.
class GpsLoggerPage extends ConsumerStatefulWidget {
  const GpsLoggerPage({super.key});

  @override
  ConsumerState<GpsLoggerPage> createState() => _GpsLoggerPageState();
}

class _GpsLoggerPageState extends ConsumerState<GpsLoggerPage> {
  final _log = LoggerService.forClass(GpsLoggerPage);

  /// Recording only makes sense on the device that goes on the boat.
  /// defaultTargetPlatform (not dart:io) so widget tests can override it.
  bool get _canRecord =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    // Riverpod 3 forbids provider mutation inside lifecycle callbacks; defer
    // the recovery read to a microtask. Surfaces tracks a crash left open.
    Future.microtask(() async {
      if (!mounted) return;
      final recorder = ref.read(gpsTrackRecorderProvider);
      if (recorder.isRecording) return;
      try {
        final recovered = await ref
            .read(gpsTrackRepositoryProvider)
            .recoverOrphanedTracks();
        if (recovered.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.gpsLogger_interruptedNotice)),
          );
        }
      } catch (e, stackTrace) {
        // Recovery is best-effort; the page must render regardless.
        _log.error(
          'Orphan track recovery failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<void> _startLogging() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
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
    await ref
        .read(gpsTrackRecorderProvider)
        .start(
          notificationTitle: l10n.gpsLogger_androidNotificationTitle,
          notificationText: l10n.gpsLogger_androidNotificationText,
        );
  }

  Future<void> _matchNow() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final stamped = await ref.read(gpsTrackMatchServiceProvider).sweep();
    if (!mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          stamped.isEmpty
              ? l10n.gpsLogger_matchResultNone
              : l10n.gpsLogger_matchResult(stamped.length),
        ),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss.
        persist: false,
        showCloseIcon: true,
        action: stamped.isEmpty
            ? null
            : SnackBarAction(
                label: l10n.gpsLogger_reviewSites,
                onPressed: () =>
                    router.push('/dives/match-sites', extra: stamped),
              ),
      ),
    );
  }

  Future<void> _deleteTrack(GpsTrack track) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.gpsLogger_deleteTrackTitle),
        content: Text(l10n.gpsLogger_deleteTrackMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(gpsTrackRepositoryProvider).deleteTrack(track.id);
    }
  }

  String _formatAge(DateTime lastFixAt) {
    final age = DateTime.now().toUtc().difference(lastFixAt);
    if (age.inMinutes < 1) return '<1 min';
    if (age.inHours < 1) return '${age.inMinutes} min';
    return '${age.inHours} h ${age.inMinutes % 60} min';
  }

  String _formatTrackDuration(GpsTrack track) {
    final end = track.endTime;
    if (end == null) return '--';
    final duration = Duration(milliseconds: end - track.startTime);
    if (duration.inHours < 1) return '${duration.inMinutes} min';
    return '${duration.inHours} h ${duration.inMinutes % 60} min';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recorder = ref.watch(gpsTrackRecorderProvider);
    final state = ref.watch(gpsRecorderStateProvider).value ?? recorder.state;
    final tracks = ref.watch(gpsTracksProvider).value ?? const <GpsTrack>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tools_gpsLogger_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_canRecord) ...[
            _RecordCard(
              state: state,
              formatAge: _formatAge,
              onStart: _startLogging,
              onStop: () => ref.read(gpsTrackRecorderProvider).stop(),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(l10n.gpsLogger_matchButton),
            onPressed: _matchNow,
          ),
          const SizedBox(height: 24),
          Text(l10n.gpsLogger_tracksHeader, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.gpsLogger_noTracks,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final track in tracks)
              ListTile(
                leading: const Icon(Icons.route_outlined),
                // Track times are wall-clock-as-UTC: format the UTC
                // components directly, never convert to device-local.
                title: Text(
                  DateFormat.yMMMd().add_jm().format(
                    DateTime.fromMillisecondsSinceEpoch(
                      track.startTime,
                      isUtc: true,
                    ),
                  ),
                ),
                subtitle: Text(
                  l10n.gpsLogger_trackSubtitle(
                    track.pointCount,
                    _formatTrackDuration(track),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.common_action_delete,
                  onPressed: () => _deleteTrack(track),
                ),
              ),
        ],
      ),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  final GpsRecorderState state;
  final String Function(DateTime) formatAge;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _RecordCard({
    required this.state,
    required this.formatAge,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recording = state.status == GpsRecorderStatus.recording;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

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
                        formatAge(state.lastFixAt!),
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
                onPressed: onStop,
              ),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.gps_fixed),
                label: Text(l10n.gpsLogger_startButton),
                onPressed: onStart,
              ),
          ],
        ),
      ),
    );
  }
}
