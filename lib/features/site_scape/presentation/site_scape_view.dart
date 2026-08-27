import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_image.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How the site scape pane is showing its region: the host's 2D map, or
/// the 3D terrain of the selected site.
enum SiteScapeMode { map2d, terrain3d }

/// The 2D/3D pair, unpositioned and card-less, so each host can seat it
/// inside whatever control cluster it already owns rather than have a
/// second floating card land on top of one. In 3D the pane hands this to
/// [SiteTerrainPane.leadingActions], which puts it in the same card as
/// the appearance and chart-view actions.
///
/// 3D needs a selected site and is disabled only when that site's grid is
/// KNOWN absent; while the grid is still loading the button stays live and
/// the terrain pane shows its own no-data state if the fetch comes back
/// empty.
class SiteScapeModeToggle extends ConsumerWidget {
  final SiteScapeMode mode;
  final ValueChanged<SiteScapeMode> onModeChanged;
  final String? selectedSiteId;
  final GeoPoint? selectedSiteLocation;

  const SiteScapeModeToggle({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.selectedSiteId,
    required this.selectedSiteLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = selectedSiteLocation;
    final gridAsync = location == null
        ? null
        : ref.watch(
            bathymetryGridProvider(BathymetryRepository.quantize(location)),
          );
    final gridKnownAbsent =
        gridAsync != null && gridAsync.hasValue && gridAsync.value == null;
    final canEnter3d = selectedSiteId != null && !gridKnownAbsent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('siteScape2dButton'),
          icon: const Icon(Icons.map_outlined, size: 20),
          isSelected: mode == SiteScapeMode.map2d,
          tooltip: context.l10n.siteScape_mode2d,
          onPressed: () => onModeChanged(SiteScapeMode.map2d),
        ),
        IconButton(
          key: const ValueKey('siteScape3dButton'),
          icon: const Icon(Icons.terrain, size: 20),
          isSelected: mode == SiteScapeMode.terrain3d,
          tooltip: canEnter3d
              ? context.l10n.siteScape_mode3d
              : context.l10n.dive3d_seascape_noData,
          onPressed: canEnter3d
              ? () => onModeChanged(SiteScapeMode.terrain3d)
              : null,
        ),
      ],
    );
  }
}

/// Mode-controlled morphable pane: the HOST owns the ephemeral
/// [SiteScapeMode] (each entry starts where the caller asked) and this
/// view renders the host's 2D stack and the terrain pane. The 2D stack
/// stays alive under [Offstage] so the map camera and tiles survive mode
/// flips. Returning to 2D fits the map camera to the grid bounds (camera
/// continuity).
///
/// The pane does NOT position a mode toggle over the 2D stack: hosts seat
/// [SiteScapeModeToggle] in the control cluster they already render, so a
/// floating toggle card can never land on top of one. In 3D the host's
/// stack is offstage, so the pane injects the toggle into the terrain
/// pane's docked card, which is then the only way back to 2D.
class SiteScapeView extends ConsumerStatefulWidget {
  final SiteScapeMode mode;
  final ValueChanged<SiteScapeMode> onModeChanged;
  final WidgetBuilder mapBuilder;
  final String? selectedSiteId;
  final GeoPoint? selectedSiteLocation;
  final MapController? mapController;

  const SiteScapeView({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.mapBuilder,
    required this.selectedSiteId,
    required this.selectedSiteLocation,
    this.mapController,
  });

  @override
  ConsumerState<SiteScapeView> createState() => _SiteScapeViewState();
}

class _SiteScapeViewState extends ConsumerState<SiteScapeView> {
  @override
  void didUpdateWidget(covariant SiteScapeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Selection VANISHED while in 3D: fall back to the map. Transition
    // only (old non-null, new null): a deep link that starts in 3D before
    // the seeded selection lands must not be knocked back to 2D. Deferred
    // a frame because the host may be mid-build.
    if (widget.mode == SiteScapeMode.terrain3d &&
        oldWidget.selectedSiteId != null &&
        widget.selectedSiteId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onModeChanged(SiteScapeMode.map2d);
      });
    }
    // 3D to 2D: fit the (still-alive, Offstage) map to the terrain box.
    if (oldWidget.mode == SiteScapeMode.terrain3d &&
        widget.mode == SiteScapeMode.map2d) {
      _fitMapToGrid();
    }
  }

  void _fitMapToGrid() {
    final controller = widget.mapController;
    final location = widget.selectedSiteLocation;
    if (controller == null || location == null) return;
    final grid = ref
        .read(bathymetryGridProvider(BathymetryRepository.quantize(location)))
        .valueOrNull;
    if (grid == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        controller.fitCamera(
          CameraFit.bounds(
            bounds: bathymetryGridBounds(grid),
            padding: const EdgeInsets.all(40),
          ),
        );
      } catch (_) {
        // Camera continuity is cosmetic: a not-yet-attached controller
        // (host swapped its map out) must never crash the mode switch.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final show3d =
        widget.mode == SiteScapeMode.terrain3d && widget.selectedSiteId != null;

    return Stack(
      // Expand: the pane must fill its host slot even when the host's 2D
      // child is intrinsically sized, or the terrain pane's docked chrome
      // would land outside the Stack's bounds and become untappable.
      fit: StackFit.expand,
      children: [
        Offstage(offstage: show3d, child: widget.mapBuilder(context)),
        if (show3d)
          Positioned.fill(
            child: SiteTerrainPane(
              siteId: widget.selectedSiteId!,
              leadingActions: [
                SiteScapeModeToggle(
                  mode: widget.mode,
                  onModeChanged: widget.onModeChanged,
                  selectedSiteId: widget.selectedSiteId,
                  selectedSiteLocation: widget.selectedSiteLocation,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
