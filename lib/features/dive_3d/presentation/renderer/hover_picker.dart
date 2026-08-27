import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';

/// A hovered or tapped scene point: its world anchor (so the ring and guide
/// lines can be re-projected every frame), where it was published on
/// screen (viewport-local, pan included), and a scene-specific payload the
/// tooltip reads (a [TissuePick] or a [PathPick]).
class ScenePick {
  final double x, y, z;
  final Offset screenPos;
  final Object payload;

  const ScenePick({
    required this.x,
    required this.y,
    required this.z,
    required this.screenPos,
    required this.payload,
  });

  ScenePick withScreenPos(Offset p) =>
      ScenePick(x: x, y: y, z: z, screenPos: p, payload: payload);
}

/// Finds what sits under the cursor. Implementations cache their projected
/// vertices by projector identity, so callers hand over the SAME projector
/// instance until the camera or canvas size changes.
abstract interface class HoverPicker {
  ScenePick? pick(SceneProjector projector, Offset cursor);
}

/// Picks vertices of a [TissueSurfaceGrid] (tissue landscape and seascape
/// terrain), delegating to [pickNearestTissueVertex].
class GridHoverPicker implements HoverPicker {
  final TissueSurfaceGrid grid;
  SceneProjector? _projector;
  List<Offset>? _projected;
  List<double>? _viewDepths;

  GridHoverPicker(this.grid);

  void _ensure(SceneProjector p) {
    if (identical(_projector, p)) return;
    final n = grid.columns * grid.compartments;
    final proj = List<Offset>.filled(n, Offset.zero);
    final depths = List<double>.filled(n, 0);
    for (var col = 0; col < grid.columns; col++) {
      for (var comp = 0; comp < grid.compartments; comp++) {
        final (x, y, z) = grid.positionAt(col, comp);
        final i = col * grid.compartments + comp;
        proj[i] = p.project(x, y, z);
        depths[i] = p.viewDepth(x, y, z);
      }
    }
    _projector = p;
    _projected = proj;
    _viewDepths = depths;
  }

  @override
  ScenePick? pick(SceneProjector projector, Offset cursor) {
    if (grid.isEmpty) return null;
    _ensure(projector);
    final t = pickNearestTissueVertex(
      cursor: cursor,
      projected: _projected!,
      viewDepths: _viewDepths!,
      columns: grid.columns,
      compartments: grid.compartments,
    );
    if (t == null) return null;
    final (x, y, z) = grid.positionAt(t.col, t.comp);
    return ScenePick(x: x, y: y, z: z, screenPos: t.screenPos, payload: t);
  }
}

/// The decimated sample index picked on the dive path.
class PathPick {
  final int index;
  const PathPick(this.index);
}

/// Picks the nearest node of a [ScrubPath] within [thresholdPx].
class PathHoverPicker implements HoverPicker {
  final ScrubPath path;
  final double thresholdPx;
  SceneProjector? _projector;
  List<Offset>? _projected;

  PathHoverPicker(this.path, {this.thresholdPx = 12});

  void _ensure(SceneProjector p) {
    if (identical(_projector, p)) return;
    final zs = path.zs;
    _projected = [
      for (var i = 0; i < path.xs.length; i++)
        p.project(path.xs[i], path.ys[i], zs?[i] ?? 0),
    ];
    _projector = p;
  }

  @override
  ScenePick? pick(SceneProjector projector, Offset cursor) {
    if (path.xs.isEmpty) return null;
    _ensure(projector);
    final projected = _projected!;
    var best = -1;
    var bestSq = thresholdPx * thresholdPx;
    for (var i = 0; i < projected.length; i++) {
      final dSq = (projected[i] - cursor).distanceSquared;
      if (dSq <= bestSq && (best < 0 || dSq < bestSq)) {
        best = i;
        bestSq = dSq;
      }
    }
    if (best < 0) return null;
    return ScenePick(
      x: path.xs[best],
      y: path.ys[best],
      z: path.zs?[best] ?? 0,
      screenPos: projected[best],
      payload: PathPick(best),
    );
  }
}
