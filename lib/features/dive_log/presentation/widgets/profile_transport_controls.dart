import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Playback transport for the fullscreen profile: skip / play / skip,
/// a minimap scrub slider, elapsed / total time, and a speed chip.
class ProfileTransportControls extends ConsumerStatefulWidget {
  final String diveId;
  final List<DiveProfilePoint> profile;

  const ProfileTransportControls({
    super.key,
    required this.diveId,
    required this.profile,
  });

  @override
  ConsumerState<ProfileTransportControls> createState() =>
      _ProfileTransportControlsState();
}

class _ProfileTransportControlsState
    extends ConsumerState<ProfileTransportControls> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.profile.isEmpty) return;
      final notifier = ref.read(playbackProvider(widget.diveId).notifier);
      if (ref.read(playbackProvider(widget.diveId)).maxTimestamp !=
          widget.profile.last.timestamp) {
        notifier.initialize(widget.profile.last.timestamp);
      }
      // Re-read after a possible initialize() so we don't act on a stale
      // isActive snapshot from before the reset.
      if (!ref.read(playbackProvider(widget.diveId)).isActive) {
        notifier.togglePlaybackMode();
      }
    });
  }

  void _seek(int timestamp) {
    ref.read(playbackProvider(widget.diveId).notifier).seekTo(timestamp);
    ref.read(profileReviewProvider(widget.diveId).notifier).state = timestamp;
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider(widget.diveId));
    final notifier = ref.read(playbackProvider(widget.diveId).notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = widget.profile.isNotEmpty;

    // Keep the review position in sync with the ticker.
    ref.listen(playbackProvider(widget.diveId), (previous, next) {
      if (next.isActive &&
          previous?.currentTimestamp != next.currentTimestamp) {
        ref.read(profileReviewProvider(widget.diveId).notifier).state =
            next.currentTimestamp;
      }
    });

    return Row(
      children: [
        IconButton(
          onPressed: enabled && !playback.atStart ? () => _seek(0) : null,
          icon: const Icon(Icons.skip_previous),
          tooltip: context.l10n.diveLog_playback_tooltip_skipStart,
          visualDensity: VisualDensity.compact,
        ),
        IconButton.filled(
          onPressed: !enabled
              ? null
              : playback.atEnd && !playback.isPlaying
              ? () {
                  notifier.skipToStart();
                  notifier.play();
                }
              : notifier.togglePlayPause,
          icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
          tooltip: playback.isPlaying
              ? context.l10n.diveLog_playback_tooltip_pause
              : context.l10n.diveLog_playback_tooltip_play,
        ),
        IconButton(
          onPressed: enabled && !playback.atEnd
              ? () => _seek(playback.maxTimestamp)
              : null,
          icon: const Icon(Icons.skip_next),
          tooltip: context.l10n.diveLog_playback_tooltip_skipEnd,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MinimapPainter(
                    profile: widget.profile,
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor: Colors.transparent,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value: playback.progress.clamp(0.0, 1.0),
                  onChanged: enabled
                      ? (v) => _seek((v * playback.maxTimestamp).round())
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${playback.formattedTime} / ${playback.formattedTotalTime}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<double>(
          initialValue: playback.playbackSpeed,
          tooltip: context.l10n.diveLog_playback_tooltip_speed,
          onSelected: notifier.setSpeed,
          itemBuilder: (context) => [
            for (final speed in PlaybackNotifier.speedPresets)
              PopupMenuItem(value: speed, child: Text('${speed.toInt()}x')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${playback.playbackSpeed.toInt()}x',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a filled depth outline of the whole dive inside the slider track,
/// so the scrub bar doubles as a minimap.
class _MinimapPainter extends CustomPainter {
  final List<DiveProfilePoint> profile;
  final Color color;

  _MinimapPainter({required this.profile, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;
    final maxTime = profile.last.timestamp;
    final maxDepth = profile
        .map((p) => p.depth)
        .reduce((a, b) => a > b ? a : b);
    if (maxTime <= 0 || maxDepth <= 0) return;

    final path = Path()..moveTo(0, 0);
    for (final point in profile) {
      path.lineTo(
        point.timestamp / maxTime * size.width,
        point.depth / maxDepth * size.height,
      );
    }
    path
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) =>
      oldDelegate.profile != profile || oldDelegate.color != color;
}
