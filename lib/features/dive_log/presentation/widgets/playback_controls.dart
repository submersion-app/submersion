import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';

/// Playback controls for stepping through a dive profile.
///
/// Provides play/pause, step forward/backward, skip to start/end,
/// and a timeline slider for seeking.
class PlaybackControls extends ConsumerWidget {
  /// The dive ID for scoping the playback provider
  final String diveId;

  /// Callback when playback is toggled on/off
  final VoidCallback? onTogglePlaybackMode;

  const PlaybackControls({
    super.key,
    required this.diveId,
    this.onTogglePlaybackMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(playbackProvider(diveId));
    final playbackNotifier = ref.read(playbackProvider(diveId).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (!playbackState.isActive) {
      // Show just a button to activate playback mode
      return Center(
        child: OutlinedButton.icon(
          onPressed: () {
            playbackNotifier.togglePlaybackMode();
            onTogglePlaybackMode?.call();
          },
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Step-through Playback'),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timeline slider
        Row(
          children: [
            // Current time
            SizedBox(
              width: 48,
              child: Text(
                playbackState.formattedTime,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Slider
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor: colorScheme.surfaceContainerHighest,
                  thumbColor: colorScheme.primary,
                  overlayColor: colorScheme.primary.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: playbackState.progress,
                  onChanged: (value) => playbackNotifier.seekToProgress(value),
                  onChangeStart: (_) {
                    // Pause during drag
                    if (playbackState.isPlaying) {
                      playbackNotifier.pause();
                    }
                  },
                ),
              ),
            ),
            // Total time
            SizedBox(
              width: 48,
              child: Text(
                playbackState.formattedTotalTime,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Close playback mode
            IconButton(
              onPressed: () {
                playbackNotifier.togglePlaybackMode();
                onTogglePlaybackMode?.call();
              },
              icon: const Icon(Icons.close),
              tooltip: 'Exit playback mode',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            // Skip to start
            IconButton(
              onPressed: playbackState.atStart
                  ? null
                  : playbackNotifier.skipToStart,
              icon: const Icon(Icons.skip_previous),
              tooltip: 'Skip to start',
              visualDensity: VisualDensity.compact,
            ),
            // Step backward
            IconButton(
              onPressed: playbackState.atStart
                  ? null
                  : playbackNotifier.stepBackward,
              icon: const Icon(Icons.replay_10),
              tooltip: 'Back 10 seconds',
              visualDensity: VisualDensity.compact,
            ),
            // Play/Pause
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: playbackState.atEnd && !playbackState.isPlaying
                    ? () {
                        // If at end and not playing, restart from beginning
                        playbackNotifier.skipToStart();
                        playbackNotifier.play();
                      }
                    : playbackNotifier.togglePlayPause,
                icon: Icon(
                  playbackState.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
                tooltip: playbackState.isPlaying ? 'Pause' : 'Play',
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            // Step forward
            IconButton(
              onPressed: playbackState.atEnd
                  ? null
                  : playbackNotifier.stepForward,
              icon: const Icon(Icons.forward_10),
              tooltip: 'Forward 10 seconds',
              visualDensity: VisualDensity.compact,
            ),
            // Skip to end
            IconButton(
              onPressed: playbackState.atEnd
                  ? null
                  : playbackNotifier.skipToEnd,
              icon: const Icon(Icons.skip_next),
              tooltip: 'Skip to end',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            // Speed selector
            _SpeedSelector(
              currentSpeed: playbackState.playbackSpeed,
              onSpeedChanged: playbackNotifier.setSpeed,
            ),
          ],
        ),
      ],
    );
  }
}

/// Speed selector popup button
class _SpeedSelector extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const _SpeedSelector({
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<double>(
      initialValue: currentSpeed,
      onSelected: onSpeedChanged,
      tooltip: 'Playback speed',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${currentSpeed}x',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0.5, child: Text('0.5x')),
        const PopupMenuItem(value: 1.0, child: Text('1x')),
        const PopupMenuItem(value: 2.0, child: Text('2x')),
        const PopupMenuItem(value: 4.0, child: Text('4x')),
      ],
    );
  }
}
