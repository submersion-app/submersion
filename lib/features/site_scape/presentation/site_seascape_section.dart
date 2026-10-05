import 'package:flutter/material.dart';

import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The site's underwater terrain in 3D, as a Site Details card.
///
/// The card shows the same [SiteTerrainPane] the fullscreen scape opens in
/// 3D, so its loading and no-data states and its docked controls are the
/// pane's own. Fullscreen is the host's to open: it owns the fullscreen
/// scape page and its map controller, so [onOpenFullscreen] hands control
/// back to it.
class SiteSeascapeSection extends StatelessWidget {
  final String siteId;
  final VoidCallback onOpenFullscreen;

  /// The host page's card inset, so this card lines up with its neighbours.
  final EdgeInsetsGeometry padding;

  const SiteSeascapeSection({
    super.key,
    required this.siteId,
    required this.onOpenFullscreen,
    this.padding = const EdgeInsets.all(12),
  });

  /// Height of the terrain slot. The pane fills whatever slot it gets, so
  /// inside a scrolling page the card has to bound it; this is tall enough
  /// to orbit and read the depth legend, and short enough to leave room for
  /// the rest of the page.
  static const double terrainHeight = 320;

  /// The slot's height on a card narrower than [narrowWidth]. The pane's
  /// overlay chips sit below the terrain and wrap onto several rows at
  /// phone width, and each row comes out of the terrain's own height.
  static const double narrowTerrainHeight = 440;

  /// Below this card width the slot grows to [narrowTerrainHeight].
  static const double narrowWidth = 600;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_in_ar, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.dive3d_seascape_siteTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('siteSeascapeFullscreenButton'),
                  icon: const Icon(Icons.fullscreen, size: 20),
                  tooltip: context.l10n.diveLog_detail_tooltip_viewFullscreen,
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenFullscreen,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: constraints.maxWidth < narrowWidth
                      ? narrowTerrainHeight
                      : terrainHeight,
                  child: SiteTerrainPane(siteId: siteId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
