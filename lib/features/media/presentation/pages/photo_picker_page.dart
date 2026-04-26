import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// Page for selecting photos from the device gallery within a date range.
///
/// Shows photos taken during the dive's time window (with buffer).
/// Supports multi-select with checkmark overlays.
class PhotoPickerPage extends ConsumerStatefulWidget {
  /// Start of the date range (dive start minus buffer).
  final DateTime startTime;

  /// End of the date range (dive end plus buffer).
  final DateTime endTime;

  /// Asset IDs already linked to this dive (shown dimmed, non-selectable).
  final Set<String> alreadyLinkedIds;

  /// Called when user confirms selection with the selected assets.
  final void Function(List<AssetInfo> selectedAssets)? onSelectionConfirmed;

  const PhotoPickerPage({
    super.key,
    required this.startTime,
    required this.endTime,
    this.alreadyLinkedIds = const {},
    this.onSelectionConfirmed,
  });

  @override
  ConsumerState<PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends ConsumerState<PhotoPickerPage> {
  List<AssetInfo>? _assets;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final notifier = ref.read(photoPickerNotifierProvider.notifier);
    await notifier.checkPermission();

    // Set already-linked IDs so they appear dimmed and non-selectable
    notifier.setAlreadyLinkedIds(widget.alreadyLinkedIds);

    final state = ref.read(photoPickerNotifierProvider);
    if (state.hasPermission) {
      _loadAssets();
    }
  }

  Future<void> _loadAssets() async {
    final service = ref.read(photoPickerServiceProvider);

    // Desktop doesn't support date-filtered browsing
    if (!service.supportsGalleryBrowsing) {
      // Open file picker directly
      final assets = await service.getAssetsInDateRange(
        widget.startTime,
        widget.endTime,
      );
      if (mounted) {
        setState(() => _assets = assets);
        // Auto-select all picked files on desktop, excluding already-linked
        if (assets.isNotEmpty) {
          final selectableIds = assets
              .where((a) => !widget.alreadyLinkedIds.contains(a.id))
              .map((a) => a.id)
              .toList();
          ref
              .read(photoPickerNotifierProvider.notifier)
              .selectAll(selectableIds);
        }
      }
      return;
    }

    // Mobile: Query gallery by date range
    final assets = await service.getAssetsInDateRange(
      widget.startTime,
      widget.endTime,
    );
    if (mounted) {
      setState(() => _assets = assets);
    }
  }

  void _handleDone() {
    final state = ref.read(photoPickerNotifierProvider);
    if (_assets == null || state.selectionCount == 0) return;

    final selectedAssets = _assets!
        .where((asset) => state.selectedIds.contains(asset.id))
        .toList();

    widget.onSelectionConfirmed?.call(selectedAssets);
    Navigator.of(context).pop(selectedAssets);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoPickerNotifierProvider);
    final showHiddenTabs = ref.watch(mediaPickerHiddenTabsProvider);

    final appBarLeading = IconButton(
      icon: const Icon(Icons.close),
      tooltip: context.l10n.media_photoPicker_closeTooltip,
      onPressed: () => Navigator.of(context).pop(),
    );
    final appBarActions = [
      TextButton(
        onPressed: state.selectionCount > 0 ? _handleDone : null,
        child: Text(
          state.selectionCount > 0
              ? context.l10n.media_photoPicker_doneCountButton(
                  state.selectionCount,
                )
              : context.l10n.media_photoPicker_doneButton,
        ),
      ),
    ];

    if (!showHiddenTabs) {
      return Scaffold(
        appBar: AppBar(
          leading: appBarLeading,
          title: Text(context.l10n.media_photoPicker_appBarTitle),
          actions: appBarActions,
        ),
        body: _galleryTab(context),
      );
    }

    // TODO(media): localize tab labels when phases 2/3 ship
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: appBarLeading,
          title: Text(context.l10n.media_photoPicker_appBarTitle),
          actions: appBarActions,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Gallery'),
              Tab(text: 'Files'),
              Tab(text: 'URL'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _galleryTab(context),
            const _PlaceholderTab(message: 'Coming in Phase 2'),
            const _PlaceholderTab(message: 'Coming in Phase 3'),
          ],
        ),
      ),
    );
  }

  Widget _galleryTab(BuildContext context) {
    final state = ref.watch(photoPickerNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return _buildBody(context, state, colorScheme);
  }

  Set<int> _computeSelectedIndices(Set<String> selectedIds) {
    if (_assets == null) return {};
    final indices = <int>{};
    for (var i = 0; i < _assets!.length; i++) {
      if (selectedIds.contains(_assets![i].id)) {
        indices.add(i);
      }
    }
    return indices;
  }

  Set<int> _computeDisabledIndices(Set<String> alreadyLinkedIds) {
    if (_assets == null) return {};
    final indices = <int>{};
    for (var i = 0; i < _assets!.length; i++) {
      if (alreadyLinkedIds.contains(_assets![i].id)) {
        indices.add(i);
      }
    }
    return indices;
  }

  void _syncSelectionToNotifier(Set<int> indices) {
    if (_assets == null) return;
    final state = ref.read(photoPickerNotifierProvider);
    final ids = indices
        .where((i) => i < _assets!.length)
        .map((i) => _assets![i].id)
        .where((id) => !state.alreadyLinkedIds.contains(id))
        .toList();
    ref.read(photoPickerNotifierProvider.notifier).selectAll(ids);
  }

  Widget _buildBody(
    BuildContext context,
    PhotoPickerState state,
    ColorScheme colorScheme,
  ) {
    // Check permission
    if (!state.hasPermission && state.permissionStatus != null) {
      return _PermissionDeniedView(
        status: state.permissionStatus!,
        onRequestPermission: () {
          ref.read(photoPickerNotifierProvider.notifier).requestPermission();
        },
      );
    }

    // Permission not checked yet or loading
    if (state.permissionStatus == null || _assets == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty state
    if (_assets!.isEmpty) {
      return _EmptyStateView(
        startTime: widget.startTime,
        endTime: widget.endTime,
      );
    }

    // Show grid
    return Column(
      children: [
        // Date range header
        _DateRangeHeader(startTime: widget.startTime, endTime: widget.endTime),
        // Selection toolbar (shown when items are selected)
        if (state.selectionCount > 0)
          _SelectionToolbar(
            selectedCount: state.selectionCount,
            totalCount: _assets!
                .where((a) => !state.alreadyLinkedIds.contains(a.id))
                .length,
            onSelectAll: () {
              final selectableIds = _assets!
                  .where((a) => !state.alreadyLinkedIds.contains(a.id))
                  .map((a) => a.id)
                  .toList();
              ref
                  .read(photoPickerNotifierProvider.notifier)
                  .selectAll(selectableIds);
            },
            onClearSelection: () {
              ref.read(photoPickerNotifierProvider.notifier).clearSelection();
            },
          ),
        // Photo grid
        Expanded(
          child: DragSelectGridView<AssetInfo>(
            items: _assets!,
            startInSelectionMode: state.selectionCount > 0,
            initialSelection: _computeSelectedIndices(state.selectedIds),
            disabledIndices: _computeDisabledIndices(state.alreadyLinkedIds),
            onSelectionChanged: (indices) {
              _syncSelectionToNotifier(indices);
            },
            // Selection visibility is derived from state.selectionCount,
            // so no additional local tracking is needed here.
            onSelectionModeChanged: (_) {},
            onItemTap: (index) {
              ref
                  .read(photoPickerNotifierProvider.notifier)
                  .toggleSelection(_assets![index].id);
            },
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, asset, isSelected) {
              final alreadyLinked = state.alreadyLinkedIds.contains(asset.id);
              return _PhotoThumbnail(
                asset: asset,
                isSelected: isSelected,
                alreadyLinked: alreadyLinked,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Header showing the date range being browsed.
class _DateRangeHeader extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;

  const _DateRangeHeader({required this.startTime, required this.endTime});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dateFormat = DateFormat.MMMd();
    final timeFormat = DateFormat.jm();

    final sameDay =
        startTime.day == endTime.day &&
        startTime.month == endTime.month &&
        startTime.year == endTime.year;

    String rangeText;
    if (sameDay) {
      rangeText =
          '${dateFormat.format(startTime)}, ${timeFormat.format(startTime)} to ${timeFormat.format(endTime)}';
    } else {
      rangeText =
          '${dateFormat.format(startTime)} ${timeFormat.format(startTime)} to ${dateFormat.format(endTime)} ${timeFormat.format(endTime)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Text(
        context.l10n.media_photoPicker_showingPhotosFromRange(rangeText),
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Toolbar showing selection count with Select All and Clear buttons.
class _SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  const _SelectionToolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            context.l10n.media_photoPicker_selectedCount(selectedCount),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (selectedCount < totalCount)
            TextButton(
              onPressed: onSelectAll,
              child: Text(context.l10n.media_photoPicker_selectAllButton),
            ),
          TextButton(
            onPressed: onClearSelection,
            child: Text(context.l10n.media_photoPicker_clearSelectionButton),
          ),
        ],
      ),
    );
  }
}

/// Individual photo thumbnail with selection overlay.
class _PhotoThumbnail extends ConsumerWidget {
  final AssetInfo asset;
  final bool isSelected;
  final bool alreadyLinked;
  const _PhotoThumbnail({
    required this.asset,
    required this.isSelected,
    this.alreadyLinked = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailAsync = ref.watch(assetThumbnailProvider(asset.id));
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: alreadyLinked
          ? context.l10n.media_photoPicker_thumbnailAlreadyLinkedLabel
          : isSelected
          ? context.l10n.media_photoPicker_thumbnailToggleSelectedLabel
          : context.l10n.media_photoPicker_thumbnailToggleLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: thumbnailAsync.when(
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, stack) => _buildPlaceholder(colorScheme),
            ),
          ),

          // Selection overlay
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.primary, width: 3),
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),

          // Checkmark
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

          // Video icon
          if (asset.isVideo)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam, size: 14, color: Colors.white),
                    if (asset.durationSeconds != null) ...[
                      const SizedBox(width: 2),
                      Text(
                        _formatDuration(asset.durationSeconds!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Already-linked overlay (dimmed with link icon)
          if (alreadyLinked)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Icon(Icons.link, color: Colors.white70, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// View shown when no photos are found in the date range.
class _EmptyStateView extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;

  const _EmptyStateView({required this.startTime, required this.endTime});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat.MMMd();
    final timeFormat = DateFormat.jm();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.media_photoPicker_emptyTitle,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.media_photoPicker_emptyMessage(
                dateFormat.format(startTime),
                timeFormat.format(startTime),
                dateFormat.format(endTime),
                timeFormat.format(endTime),
              ),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// View shown when photo library permission is denied.
class _PermissionDeniedView extends StatelessWidget {
  final PhotoPermissionStatus status;
  final VoidCallback onRequestPermission;

  const _PermissionDeniedView({
    required this.status,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isPermanentlyDenied =
        status == PhotoPermissionStatus.denied ||
        status == PhotoPermissionStatus.restricted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.media_photoPicker_permissionTitle,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isPermanentlyDenied
                  ? context.l10n.media_photoPicker_permissionDeniedMessage
                  : context.l10n.media_photoPicker_permissionRequestMessage,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (isPermanentlyDenied)
              FilledButton(
                onPressed: () {
                  // Open app settings
                  // Note: This requires platform-specific handling
                  // For now, just show a message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.media_photoPicker_openSettingsSnackbar,
                      ),
                    ),
                  );
                },
                child: Text(context.l10n.media_photoPicker_openSettingsButton),
              )
            else
              FilledButton(
                onPressed: onRequestPermission,
                child: Text(context.l10n.media_photoPicker_grantAccessButton),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the photo picker as a full-screen modal.
///
/// Returns the list of selected [AssetInfo] objects, or null if cancelled.
Future<List<AssetInfo>?> showPhotoPicker({
  required BuildContext context,
  required DateTime diveStartTime,
  required DateTime diveEndTime,
  Set<String> alreadyLinkedIds = const {},
  Duration buffer = const Duration(minutes: 30),
}) {
  final startTime = diveStartTime.subtract(buffer);
  final endTime = diveEndTime.add(buffer);

  return Navigator.of(context).push<List<AssetInfo>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PhotoPickerPage(
        startTime: startTime,
        endTime: endTime,
        alreadyLinkedIds: alreadyLinkedIds,
      ),
    ),
  );
}

/// Placeholder shown in the Files and URL tabs while those features are
/// pending (Phase 2 / Phase 3). Visible only when the debug toggle
/// [mediaPickerHiddenTabsProvider] is enabled.
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
