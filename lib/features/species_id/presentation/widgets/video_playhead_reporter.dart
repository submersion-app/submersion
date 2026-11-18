import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// Tells the video's scan where the diver is watching (issue #4709), and
/// that the diver left it when it goes: a
/// seek once the playhead has settled for [settle], and a pause once it
/// has lasted [settle]. Nothing during steady playback. Draws nothing.
///
/// A pause waits because the controls bar pauses the player as a scrub
/// starts: the jump that follows turns it into a seek, reported where the
/// scrub stops, so scrubbing never moves the scan on its way.
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

  /// Whether what is settling is a seek; otherwise it is a pause.
  var _seeking = false;

  /// The service as last read, kept for [dispose], which cannot read
  /// providers. Reports read the provider afresh: it gives a new service
  /// when the pack store, repository or engine changes.
  late MediaIdentificationService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(mediaIdentificationServiceProvider);
    _wasPlaying = widget.playback.value.isPlaying;
    widget.playback.addListener(_changed);
  }

  @override
  void didUpdateWidget(VideoPlayheadReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      // What was settling, and where it was, belong to the video left.
      _settling?.cancel();
      _seeking = false;
      _lastMs = null;
      _wasPlaying = widget.playback.value.isPlaying;
      _service.forgetPlayhead(oldWidget.item.id);
    }
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(_changed);
      _settling?.cancel();
      _seeking = false;
      _lastMs = null;
      _wasPlaying = widget.playback.value.isPlaying;
      widget.playback.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _settling?.cancel();
    widget.playback.removeListener(_changed);
    _service.forgetPlayhead(widget.item.id);
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
    final jumped =
        last != null &&
        (ms - last > widget.jumpMs || last - ms > widget.backMs);
    if (jumped) {
      _seeking = true;
      _settle();
    } else if (_seeking) {
      // A seek is settling: a pause or play now changes nothing about it.
    } else if (wasPlaying && !value.isPlaying) {
      _settle();
    } else if (!wasPlaying && value.isPlaying) {
      // Playing again before the pause settled: nothing to report.
      _settling?.cancel();
    }
  }

  void _settle() {
    _settling?.cancel();
    _settling = Timer(widget.settle, _settled);
  }

  void _settled() {
    final seek = _seeking;
    _seeking = false;
    if (!mounted) return;
    final value = widget.playback.value;
    if (!seek && value.isPlaying) return;
    _report(value.position.inMilliseconds, seek: seek);
  }

  void _report(int ms, {required bool seek}) {
    _service = ref.read(mediaIdentificationServiceProvider);
    _service.followPlayhead(widget.item.id, ms, seek: seek);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
