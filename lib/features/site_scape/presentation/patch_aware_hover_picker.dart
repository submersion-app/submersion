import 'package:flutter/rendering.dart';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';

/// Tries the finer LOD patch grid first, falling back to the coarser base
/// grid. The patch visually covers the base terrain in its footprint, so a
/// hover there should read the patch's own depth, not the base grid
/// underneath it; outside the patch's footprint [patchPicker] finds nothing
/// within its own threshold and returns null, falling through to the base
/// grid exactly like there was no patch at all.
///
/// [onGridUsed] reports which grid actually produced the hit -- a
/// [TissuePick]'s row/col indices are only meaningful against the SAME
/// grid the picker that found it was built from, so the caller must track
/// this alongside the pick itself to build a correct `SeascapeHoverTooltip`.
class PatchAwareHoverPicker implements HoverPicker {
  final HoverPicker? patchPicker;
  final BathymetryGrid? patchGrid;
  final HoverPicker basePicker;
  final BathymetryGrid baseGrid;
  final ValueChanged<BathymetryGrid> onGridUsed;

  const PatchAwareHoverPicker({
    required this.patchPicker,
    required this.patchGrid,
    required this.basePicker,
    required this.baseGrid,
    required this.onGridUsed,
  });

  @override
  ScenePick? pick(SceneProjector projector, Offset cursor) {
    final patch = patchPicker;
    if (patch != null) {
      final hit = patch.pick(projector, cursor);
      if (hit != null) {
        onGridUsed(patchGrid!);
        return hit;
      }
    }
    final hit = basePicker.pick(projector, cursor);
    if (hit != null) onGridUsed(baseGrid);
    return hit;
  }
}
