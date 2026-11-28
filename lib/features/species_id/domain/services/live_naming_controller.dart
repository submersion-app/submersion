import 'dart:async';
import 'dart:typed_data';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';

/// Free memory below which live naming pauses (issue #5122): the camera and
/// identification together are what got the app killed on a phone, so the
/// names go before the camera does.
const int liveNamingMemoryMarginBytes = 512 * 1024 * 1024;

/// Boxes overlapping at least this much in two frames are one animal.
const double liveTrackIou = 0.3;

/// One camera frame, encoded, and when it was taken.
class LiveFrame {
  const LiveFrame(this.jpeg);

  final Uint8List jpeg;
}

/// Why live naming is not running.
enum LivePause { memory }

/// An animal in the preview: where it is, the suggestion for it (null for
/// none), and which animal it is across frames.
class LiveBox {
  const LiveBox({required this.box, required this.name, required this.track});

  final IdentificationBox box;
  final String? name;
  final int track;
}

/// What the preview shows: the animals in the last frame named, or why
/// nothing is named.
class LiveLabels {
  const LiveLabels.boxes(this.boxes) : pause = null;
  const LiveLabels.paused(this.pause) : boxes = const [];

  final List<LiveBox> boxes;
  final LivePause? pause;
}

/// Names what the camera sees, a frame at a time (issue #5122): a frame
/// every [interval] at most, never one while the last is still being
/// named (a newer frame is worth more than a queued one), and none while
/// memory runs short. Suggestions only, with no location: the camera may be
/// pointed at an aquarium or a photo on a screen.
class LiveNamingController {
  LiveNamingController({
    required Future<VisionAnalysis> Function(Uint8List jpeg) analyze,
    required Future<List<String?>> Function(List<VisionDetection> found) name,
    required Future<VisionMemory> Function() memory,
    this.interval = const Duration(milliseconds: 250),
    this.memoryMarginBytes = liveNamingMemoryMarginBytes,
    DateTime Function() now = DateTime.now,
  }) : _analyze = analyze,
       _name = name,
       _memory = memory,
       _now = now;

  final Future<VisionAnalysis> Function(Uint8List jpeg) _analyze;
  final Future<List<String?>> Function(List<VisionDetection> found) _name;
  final Future<VisionMemory> Function() _memory;
  final DateTime Function() _now;
  final Duration interval;
  final int memoryMarginBytes;

  final _labels = StreamController<LiveLabels>.broadcast();
  DateTime? _lastTaken;
  bool _busy = false;
  bool _closed = false;
  int _nextTrack = 0;
  List<LiveBox> _previous = const [];

  /// The labels, one event per frame named or skipped for memory.
  Stream<LiveLabels> get labels => _labels.stream;

  /// Whether a frame offered now would be named. The camera asks before it
  /// pays to encode one.
  bool get wantsFrame {
    if (_closed || _busy) return false;
    final last = _lastTaken;
    return last == null || _now().difference(last) >= interval;
  }

  /// Names [frame] if one is wanted now; drops it otherwise.
  Future<void> offer(LiveFrame frame) async {
    if (!wantsFrame) return;
    _busy = true;
    _lastTaken = _now();
    try {
      if (_short(await _memory())) {
        _previous = const [];
        _emit(const LiveLabels.paused(LivePause.memory));
        return;
      }
      final analysis = await _analyze(frame.jpeg);
      final names = await _name(analysis.detections);
      final boxes = [
        for (var i = 0; i < analysis.detections.length; i++)
          _tracked(
            IdentificationBox(
              x: analysis.detections[i].x,
              y: analysis.detections[i].y,
              width: analysis.detections[i].width,
              height: analysis.detections[i].height,
            ),
            i < names.length ? names[i] : null,
          ),
      ];
      _previous = boxes;
      _emit(LiveLabels.boxes(boxes));
    } finally {
      _busy = false;
    }
  }

  bool _short(VisionMemory memory) {
    if (memory.lowMemory ?? false) return true;
    final available = memory.availableBytes;
    return available != null && available < memoryMarginBytes;
  }

  /// [box], keeping the track of the previous frame's box it overlaps most
  /// when that is at least [liveTrackIou].
  LiveBox _tracked(IdentificationBox box, String? name) {
    LiveBox? best;
    var bestIou = liveTrackIou;
    for (final previous in _previous) {
      final overlap = previous.box.iou(box);
      if (overlap >= bestIou) {
        best = previous;
        bestIou = overlap;
      }
    }
    return LiveBox(box: box, name: name, track: best?.track ?? _nextTrack++);
  }

  void _emit(LiveLabels labels) {
    if (!_closed) _labels.add(labels);
  }

  /// Stops naming. Frames offered after are dropped.
  Future<void> dispose() async {
    _closed = true;
    await _labels.close();
  }
}
