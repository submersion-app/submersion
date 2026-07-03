import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Camera-icon markers over the dive profile chart at each photo's
/// (time, depth), with a tap-to-preview thumbnail card.
///
/// Rendered as a widget layer above the LineChart (a later Stack child) so
/// its tap targets win hit-testing over the chart's pan/scrub/tooltip
/// gestures without entering fl_chart's touch arena.
class PhotoMarkerOverlay extends StatefulWidget {
  /// Time-sorted markers (see [photoMarkersFromMedia]).
  final List<PhotoChartMarker> markers;

  /// Visible time window in seconds (the chart's zoomed/panned X range).
  final double visibleMinSeconds;
  final double visibleMaxSeconds;

  /// Visible depth window in display units (the chart's Y range, positive).
  final double visibleMinDepth;
  final double visibleMaxDepth;

  /// Reserved axis gutters around the plot rect (the chart's _plotInsets).
  final ({double left, double top, double right, double bottom}) insets;

  final UnitFormatter units;

  /// Invoked when a preview-card thumbnail is tapped. When null, pushes
  /// [PhotoViewerPage] for the photo.
  final void Function(MediaItem item)? onOpenPhoto;

  const PhotoMarkerOverlay({
    super.key,
    required this.markers,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
    required this.visibleMinDepth,
    required this.visibleMaxDepth,
    required this.insets,
    required this.units,
    this.onOpenPhoto,
  });

  @override
  State<PhotoMarkerOverlay> createState() => _PhotoMarkerOverlayState();
}

class _PhotoMarkerOverlayState extends State<PhotoMarkerOverlay> {
  /// First member index of the previewed cluster, or null when closed.
  /// Tracking the selected MediaItem id (not a list index or cluster) keeps
  /// the selection pointing at the same photo while clusters re-form during
  /// rebuilds, and makes it vanish naturally if that photo is removed.
  String? _selectedMediaId;

  static const double _chipSize = 22.0;
  static const double _tapTarget = 32.0;
  static const double _thumbSize = 72.0;
  static const double _cardHeight = 112.0;

  @override
  void didUpdateWidget(PhotoMarkerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A pan/zoom invalidates the card's anchor; dismiss. Content changes are
    // handled by id: if the selected photo is gone, no cluster resolves.
    if (oldWidget.visibleMinSeconds != widget.visibleMinSeconds ||
        oldWidget.visibleMaxSeconds != widget.visibleMaxSeconds ||
        oldWidget.visibleMinDepth != widget.visibleMinDepth ||
        oldWidget.visibleMaxDepth != widget.visibleMaxDepth) {
      _selectedMediaId = null;
    }
  }

  void _openPhoto(MediaItem item) {
    if (widget.onOpenPhoto != null) {
      widget.onOpenPhoto!(item);
      return;
    }
    final diveId = item.diveId;
    if (diveId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            PhotoViewerPage(diveId: diveId, initialMediaId: item.id),
      ),
    );
  }

  String _formatRuntime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth =
            constraints.maxWidth - widget.insets.left - widget.insets.right;
        final plotHeight =
            constraints.maxHeight - widget.insets.top - widget.insets.bottom;
        if (plotWidth <= 0 || plotHeight <= 0) {
          return const SizedBox.shrink();
        }

        final clusters = clusterPhotoMarkers(
          points: [
            for (final m in widget.markers)
              (
                seconds: m.elapsedSeconds.toDouble(),
                depthDisplay: widget.units.convertDepth(m.depthMeters),
              ),
          ],
          visibleMinSeconds: widget.visibleMinSeconds,
          visibleMaxSeconds: widget.visibleMaxSeconds,
          visibleMinDepth: widget.visibleMinDepth,
          visibleMaxDepth: widget.visibleMaxDepth,
          plotWidth: plotWidth,
          plotHeight: plotHeight,
        );
        if (clusters.isEmpty) return const SizedBox.shrink();

        PhotoMarkerCluster? selected;
        if (_selectedMediaId != null) {
          for (final c in clusters) {
            if (c.memberIndexes.any(
              (i) => widget.markers[i].item.id == _selectedMediaId,
            )) {
              selected = c;
              break;
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Tap-away dismisses the preview card.
            if (selected != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _selectedMediaId = null),
                ),
              ),
            for (final cluster in clusters)
              Positioned(
                left: widget.insets.left + cluster.x - _tapTarget / 2,
                top: widget.insets.top + cluster.y - _tapTarget / 2,
                width: _tapTarget,
                height: _tapTarget,
                child: _buildChip(context, cluster),
              ),
            if (selected != null)
              _buildPreviewCard(context, selected, plotWidth, plotHeight),
          ],
        );
      },
    );
  }

  Widget _buildChip(BuildContext context, PhotoMarkerCluster cluster) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = cluster.memberIndexes.length;
    // Videos get their own glyph; a mixed cluster reads as a camera since
    // at least one still photo sits at that position.
    final allVideos = cluster.memberIndexes.every(
      (i) => widget.markers[i].item.isVideo,
    );

    return Semantics(
      button: true,
      label: context.l10n.diveLog_profile_semantics_photoMarker,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(
          () => _selectedMediaId =
              widget.markers[cluster.memberIndexes.first].item.id,
        ),
        child: Center(
          child: Container(
            width: _chipSize,
            height: _chipSize,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  allVideos ? Icons.videocam : Icons.camera_alt,
                  size: 12,
                  color: colorScheme.onPrimaryContainer,
                ),
                if (count > 1)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    PhotoMarkerCluster cluster,
    double plotWidth,
    double plotHeight,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final members = [for (final i in cluster.memberIndexes) widget.markers[i]];
    final cardWidth = members.length == 1
        ? _thumbSize + 16
        : (members.length * (_thumbSize + 4) + 12)
              .clamp(0.0, plotWidth)
              .toDouble();

    final chipX = widget.insets.left + cluster.x;
    final chipY = widget.insets.top + cluster.y;
    final minLeft = widget.insets.left;
    // num.clamp returns num; Positioned wants double.
    final maxLeft = (widget.insets.left + plotWidth - cardWidth)
        .clamp(minLeft, double.infinity)
        .toDouble();
    final left = (chipX - cardWidth / 2).clamp(minLeft, maxLeft).toDouble();
    final fitsAbove = chipY - _cardHeight - 8 >= widget.insets.top;
    final top = fitsAbove
        ? chipY - _cardHeight - 8
        : chipY + _tapTarget / 2 + 4;

    return Positioned(
      key: const ValueKey('photoMarkerCard'),
      left: left,
      top: top,
      width: cardWidth,
      height: _cardHeight,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: members.length == 1
              ? _buildThumb(context, members.single)
              : ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final m in members)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: _thumbSize,
                          child: _buildThumb(context, m),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildThumb(BuildContext context, PhotoChartMarker marker) {
    final caption =
        '${widget.units.formatDepth(marker.depthMeters, decimals: 0)}'
        ' · ${_formatRuntime(marker.elapsedSeconds)}';
    return GestureDetector(
      key: ValueKey('photoMarkerCardThumb-${marker.item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPhoto(marker.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: MediaItemView(
                item: marker.item,
                thumbnail: true,
                targetSize: const Size(200, 200),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
