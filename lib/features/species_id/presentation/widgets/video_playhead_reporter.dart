import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// Tells the video's scan where the diver is watching (issue #4709): a
/// seek once the playhead has settled for [settle], and a pause at once.
/// Nothing during steady playback. Draws nothing.
///
/// A seek is a jump forward over [jumpMs], or back over [backMs], between
/// two player updates: more than playback explains.
class VideoPlayheadReporter extends ConsumerStatefulWidget {
  const VideoPlayheadReporter({
    super.key,
    required this.playback,
    required this.item,
    this.settle = const Duration(milliseconds: 500),
    this.jumpMs = 1500,
    this.backMs = 250,
  });

  final ValueListenable<VideoPlayerValue> playback;
  final MediaItem item;
  final Duration settle;
  final int jumpMs;
  final int backMs;

  @override
  ConsumerState<VideoPlayheadReporter> createState() =>
      _VideoPlayheadReporterState();
}

class _VideoPlayheadReporterState extends ConsumerState<VideoPlayheadReporter> {
  int? _lastMs;
  var _wasPlaying = false;
  Timer? _settling;

  @override
  void initState() {
    super.initState();
    _wasPlaying = widget.playback.value.isPlaying;
    widget.playback.addListener(_changed);
  }

  @override
  void didUpdateWidget(VideoPlayheadReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(_changed);
      _settling?.cancel();
      _lastMs = null;
      _wasPlaying = widget.playback.value.isPlaying;
      widget.playback.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _settling?.cancel();
    widget.playback.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final value = widget.playback.value;
    if (!value.isInitialized) return;
    final ms = value.position.inMilliseconds;
    final last = _lastMs;
    final wasPlaying = _wasPlaying;
    _lastMs = ms;
    _wasPlaying = value.isPlaying;
    if (!marineLifeIdEnabled) return;
    if (last != null &&
        (ms - last > widget.jumpMs || last - ms > widget.backMs)) {
      _settling?.cancel();
      _settling = Timer(widget.settle, _settled);
    }
    if (wasPlaying && !value.isPlaying) _report(ms, seek: false);
  }

  void _settled() {
    if (!mounted) return;
    _report(widget.playback.value.position.inMilliseconds, seek: true);
  }

  void _report(int ms, {required bool seek}) => ref
      .read(mediaIdentificationServiceProvider)
      .followPlayhead(widget.item.id, ms, seek: seek);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
