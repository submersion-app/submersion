import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';

/// One sample of a layer: [value] at [seconds] into the dive.
@immutable
class StripPoint {
  const StripPoint(this.seconds, this.value);

  final int seconds;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is StripPoint && other.seconds == seconds && other.value == value;

  @override
  int get hashCode => Object.hash(seconds, value);

  @override
  String toString() => 'StripPoint($seconds, $value)';
}

/// A line layer on a scale of its own, from [min] at the strip's bottom to
/// [max] at its top. Each run is drawn as one polyline; a gap between runs
/// is a stretch with no value (GTR not yet known, say).
@immutable
class StripLine {
  const StripLine({
    required this.layer,
    required this.key,
    required this.color,
    required this.runs,
    required this.min,
    required this.max,
    this.estimated = false,
    this.label,
    List<List<StripPoint>>? valueRuns,
  }) : _valueRuns = valueRuns;

  final StripLayer layer;

  /// Tells lines of one layer apart (each tank's id); the layer's name for
  /// a layer with one line.
  final String key;
  final Color color;

  /// The runs as drawn, thinned to the strip's point budget.
  final List<List<StripPoint>> runs;

  /// The runs with every sample, where thinning dropped some, so a value
  /// read at the cursor is the sample's own, as the card and the full chart
  /// read it, not one interpolated across the dropped samples.
  final List<List<StripPoint>>? _valueRuns;
  final double min;
  final double max;

  /// A tank pressure synthesized from start and end pressures rather than
  /// logged by a transmitter.
  final bool estimated;

  /// The line's own name where its layer has several (a tank's); null where
  /// the layer's name is enough.
  final String? label;

  /// The value at [seconds], interpolated between the samples either side,
  /// or null outside every run.
  double? valueAt(int seconds) {
    for (final run in _valueRuns ?? runs) {
      final value = stripValueAt(run, seconds);
      if (value != null) return value;
    }
    return null;
  }
}

/// The value of [run] at [seconds], interpolated between the samples either
/// side, or null outside it.
double? stripValueAt(List<StripPoint> run, int seconds) {
  if (run.isEmpty || seconds < run.first.seconds) return null;
  if (seconds > run.last.seconds) return null;
  for (var i = 0; i < run.length; i++) {
    final p = run[i];
    if (p.seconds == seconds) return p.value;
    if (p.seconds > seconds) {
      final a = run[i - 1];
      final share = (seconds - a.seconds) / (p.seconds - a.seconds);
      return a.value + (p.value - a.value) * share;
    }
  }
  return null;
}

/// A stretch of the dive tinted the strip's full height: a phase of the dive
/// ([phase]) or a safety finding's window ([finding]).
@immutable
class StripBand {
  const StripBand({
    required this.layer,
    required this.start,
    required this.end,
    required this.color,
    required this.alpha,
    this.phase,
    this.finding,
  });

  final StripLayer layer;
  final int start;
  final int end;
  final Color color;
  final double alpha;
  final DivePhase? phase;
  final SafetyFinding? finding;
}

/// Which edge of the strip a tick hangs from.
enum StripTickEdge { top, bottom }

/// A short mark at one moment: an annotation, a computer bookmark
/// ([hollow]), a gas switch, a safety finding with no end.
@immutable
class StripTick {
  const StripTick({
    required this.layer,
    required this.seconds,
    required this.color,
    required this.edge,
    this.hollow = false,
  });

  final StripLayer layer;
  final int seconds;
  final Color color;
  final StripTickEdge edge;
  final bool hollow;
}

/// A dot on the depth line where a photo or video was taken.
@immutable
class StripDot {
  const StripDot({required this.seconds, required this.depthMeters});

  final int seconds;
  final double depthMeters;
}

/// A ghosted depth line beside the dive's own: the linked plan, or another
/// computer's record of the dive. Its points' values are depths in metres.
@immutable
class StripGhost {
  const StripGhost({
    required this.layer,
    required this.key,
    required this.label,
    required this.color,
    required this.points,
    List<StripPoint>? valuePoints,
  }) : _valuePoints = valuePoints;

  final StripLayer layer;
  final String key;
  final String label;
  final Color color;

  /// The points as drawn, thinned to the strip's point budget.
  final List<StripPoint> points;

  /// Every point, where thinning dropped some, for reading the depth at the
  /// cursor.
  final List<StripPoint>? _valuePoints;

  /// The depth at [seconds], or null outside the line.
  double? depthAt(int seconds) => stripValueAt(_valuePoints ?? points, seconds);

  double get maxDepth =>
      points.fold(0.0, (deepest, p) => math.max(deepest, p.value));
}

/// Everything the pinned strip can draw for the cards in view (issue #4562),
/// worked out from the dive's data whether or not a card is in view: which
/// layers show is the strengths' business, not this.
@immutable
class PinnedStripLayerData {
  const PinnedStripLayerData({
    this.lines = const [],
    this.bands = const [],
    this.ticks = const [],
    this.dots = const [],
    this.ghosts = const [],
  });

  static const empty = PinnedStripLayerData();

  final List<StripLine> lines;
  final List<StripBand> bands;
  final List<StripTick> ticks;
  final List<StripDot> dots;
  final List<StripGhost> ghosts;

  /// Whether [layer] has anything to draw on this dive.
  bool hasData(StripLayer layer) =>
      lines.any((l) => l.layer == layer) ||
      bands.any((b) => b.layer == layer) ||
      ticks.any((t) => t.layer == layer) ||
      (layer == StripLayer.media && dots.isNotEmpty) ||
      ghosts.any((g) => g.layer == layer);

  /// The deepest point of the ghosts of [layers], or 0 with none.
  double ghostMaxDepth(Set<StripLayer> layers) => ghosts
      .where((g) => layers.contains(g.layer))
      .fold(0.0, (deepest, g) => math.max(deepest, g.maxDepth));
}
