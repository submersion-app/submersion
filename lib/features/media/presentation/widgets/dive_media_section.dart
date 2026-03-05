import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// Section widget displaying media (photos/videos) for a dive.
///
/// Supports multi-select mode via long-press and drag, with bulk unlink.
class DiveMediaSection extends ConsumerStatefulWidget {
  final String diveId;
  final VoidCallback? onAddPressed;
  final VoidCallback? onScanPressed;

  const DiveMediaSection({
    super.key,
    required this.diveId,
    this.onAddPressed,
    this.onScanPressed,
  });

  @override
  ConsumerState<DiveMediaSection> createState() => _DiveMediaSectionState();
}

class _DiveMediaSectionState extends ConsumerState<DiveMediaSection> {
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices = {};
    });
  }

  void _selectAll(int totalCount) {
    setState(() {
      _selectedIndices = Set<int>.from(List.generate(totalCount, (i) => i));
    });
  }

  Future<void> _unlinkSelected(
    BuildContext context,
    List<MediaItem> media,
  ) async {
    final selectedIds = _selectedIndices
        .where((i) => i < media.length)
        .map((i) => media[i].id)
        .toList();

    if (selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ctx.l10n.media_diveMediaSection_unlinkSelectedTitle(
            selectedIds.length,
          ),
        ),
        content: Text(
          ctx.l10n.media_diveMediaSection_unlinkSelectedContent(
            selectedIds.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.media_diveMediaSection_cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.media_diveMediaSection_unlinkButton),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(mediaListNotifierProvider(widget.diveId).notifier)
            .deleteMultipleMedia(selectedIds);

        _exitSelectionMode();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.media_diveMediaSection_unlinkSelectedSuccess(
                  selectedIds.length,
                ),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.media_diveMediaSection_unlinkError(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaForDiveProvider(widget.diveId));
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: selection mode or normal
            if (_isSelectionMode)
              mediaAsync.whenOrNull(
                    data: (media) => _SelectionHeader(
                      selectedCount: _selectedIndices.length,
                      totalCount: media.length,
                      onSelectAll: () => _selectAll(media.length),
                      onCancel: _exitSelectionMode,
                      onUnlinkSelected: () => _unlinkSelected(context, media),
                    ),
                  ) ??
                  const SizedBox.shrink()
            else
              Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.media_diveMediaSection_title,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  if (widget.onScanPressed != null)
                    IconButton(
                      icon: Icon(
                        Icons.image_search,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.media_diveScan_scanTooltip,
                      onPressed: widget.onScanPressed,
                    ),
                  if (widget.onAddPressed != null)
                    IconButton(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onPressed: widget.onAddPressed,
                    ),
                ],
              ),
            const SizedBox(height: 16),
            // Content
            mediaAsync.when(
              data: (media) {
                if (media.isEmpty) {
                  return const _EmptyMediaState();
                }
                return DragSelectGridView<MediaItem>(
                  items: media,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  startInSelectionMode: _isSelectionMode,
                  initialSelection: _selectedIndices,
                  onSelectionChanged: (indices) {
                    setState(() {
                      _selectedIndices = indices;
                    });
                  },
                  onSelectionModeChanged: (isSelecting) {
                    setState(() {
                      _isSelectionMode = isSelecting;
                    });
                  },
                  onItemTap: (index) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => PhotoViewerPage(
                          diveId: widget.diveId,
                          initialMediaId: media[index].id,
                        ),
                      ),
                    );
                  },
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, item, isSelected) {
                    return _MediaThumbnailContent(
                      item: item,
                      settings: settings,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                    );
                  },
                );
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, stack) => Text(
                context.l10n.media_diveMediaSection_errorLoading,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header shown during multi-select mode with count, select all, and unlink.
class _SelectionHeader extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback onUnlinkSelected;

  const _SelectionHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onCancel,
    required this.onUnlinkSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.l10n.media_diveMediaSection_cancelSelectionButton,
          onPressed: onCancel,
        ),
        Text(
          context.l10n.media_diveMediaSection_selectedCount(selectedCount),
          style: textTheme.titleMedium,
        ),
        const Spacer(),
        if (selectedCount < totalCount)
          TextButton(
            onPressed: onSelectAll,
            child: Text(context.l10n.media_diveMediaSection_selectAllButton),
          ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          tooltip: context.l10n.media_diveMediaSection_unlinkSelectedButton(
            selectedCount,
          ),
          onPressed: selectedCount > 0 ? onUnlinkSelected : null,
        ),
      ],
    );
  }
}

/// Empty state when no media is associated with the dive
class _EmptyMediaState extends StatelessWidget {
  const _EmptyMediaState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.media_diveMediaSection_emptyState,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Purely visual thumbnail content for media items.
///
/// Gestures (tap, long-press, drag) are handled by [DragSelectGridView].
class _MediaThumbnailContent extends ConsumerWidget {
  final MediaItem item;
  final AppSettings settings;
  final bool isSelectionMode;
  final bool isSelected;

  const _MediaThumbnailContent({
    required this.item,
    required this.settings,
    required this.isSelectionMode,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = UnitFormatter(settings);

    return Semantics(
      label: context.l10n.media_diveMediaSection_thumbnailLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder
            if (item.isOrphaned)
              const _OrphanedPlaceholder()
            else if (item.platformAssetId != null)
              _buildAssetThumbnail(ref, colorScheme)
            else
              _buildPlaceholder(colorScheme),

            // Dimming overlay for unselected items in selection mode
            if (isSelectionMode && !isSelected)
              Container(color: Colors.black.withValues(alpha: 0.3)),

            // Selection overlay with primary border and tint
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.primary, width: 3),
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),

            // Checkmark circle on selected items
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),

            // Video icon (top-right when no checkmark, hidden when checkmark)
            if (item.isVideo && !isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),

            // Depth badge (bottom-left)
            if (item.enrichment?.depthMeters != null)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formatter.formatDepth(
                      item.enrichment!.depthMeters,
                      decimals: 0,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Fetches and displays thumbnail from platform photo library
  Widget _buildAssetThumbnail(WidgetRef ref, ColorScheme colorScheme) {
    final thumbnailAsync = ref.watch(
      assetThumbnailProvider(item.platformAssetId!),
    );

    return thumbnailAsync.when(
      data: (bytes) {
        if (bytes == null) {
          return _buildPlaceholder(colorScheme);
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 200,
          cacheHeight: 200,
          errorBuilder: (context, error, stack) =>
              _buildPlaceholder(colorScheme),
        );
      },
      loading: () => Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => _buildPlaceholder(colorScheme),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
    );
  }
}

/// Placeholder shown for orphaned media (file no longer exists)
class _OrphanedPlaceholder extends StatelessWidget {
  const _OrphanedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
