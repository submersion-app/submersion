import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/files_tab_staging.dart';
import 'package:submersion/features/media/presentation/helpers/gallery_album_filter.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';
import 'package:submersion/features/media/presentation/widgets/gallery_album_filter_bar.dart';
import 'package:submersion/features/media/presentation/widgets/gallery_selection_toolbar.dart';
import 'package:submersion/features/media/presentation/widgets/url_tab.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_tab_metrics.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';
import 'package:submersion/core/utils/log_failure.dart';

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

  /// What this picker session attaches media to, when it has an owner.
  ///
  /// Only the Gallery tab hands its selection back to the caller; the Files
  /// and URL tabs write rows themselves, so they need to be told the target
  /// or they cannot link anything. Passing only a dive id (as this used to)
  /// left a session opened from a dive site with no reachable commit path at
  /// all: issue #1098.
  ///
  /// Null when the picker is opened with no owning entity, e.g. the library
  /// importer.
  final MediaAttachTarget? target;

  /// Files the user already has in hand, such as a desktop drag-and-drop
  /// (issue #2488), staged in the Files tab for review the moment the page
  /// opens.
  ///
  /// When set, the page opens on the Files tab and the Gallery tab loads
  /// only once it is shown. On Windows and Linux loading the Gallery opens a
  /// file dialog, which would otherwise pop up over the files the user just
  /// dropped.
  final List<String>? initialFilePaths;

  /// Replaces the Gallery tab's search of [startTime] to [endTime] on a
  /// platform with a photo library, for a caller that knows better than a
  /// date range. It is passed whether the page is still open, so it can stop
  /// work nobody is waiting for.
  final Future<List<AssetInfo>> Function(bool Function() isActive)? loadAssets;

  const PhotoPickerPage({
    super.key,
    required this.startTime,
    required this.endTime,
    this.alreadyLinkedIds = const {},
    this.onSelectionConfirmed,
    this.target,
    this.initialFilePaths,
    this.loadAssets,
  });

  @override
  ConsumerState<PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends ConsumerState<PhotoPickerPage>
    with SingleTickerProviderStateMixin {
  static const _galleryTabIndex = 0;
  static const _filesTabIndex = 1;

  List<AssetInfo>? _assets;

  /// The albums [_assets] came from, for the Gallery tab's album filter.
  List<GalleryAlbumOption> _albumOptions = const [];

  /// The album name the grid is narrowed to, or null for every album (#189).
  String? _albumName;

  late final TabController _tabController;
  late final ValueNotifier<int> _openSessions;
  bool _galleryLoadStarted = false;

  @override
  void initState() {
    super.initState();
    _openSessions = ref.read(openPhotoPickerSessionsProvider);
    _openSessions.value++;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialFilePaths == null
          ? _galleryTabIndex
          : _filesTabIndex,
    )..addListener(_loadGalleryWhenShown);
    Future.microtask(_startSession);
    _loadGalleryWhenShown();
  }

  @override
  void dispose() {
    _openSessions.value--;
    _tabController.dispose();
    super.dispose();
  }

  /// Starts the Gallery tab's permission check and asset load the first time
  /// that tab is the one on screen.
  void _loadGalleryWhenShown() {
    if (_galleryLoadStarted || _tabController.index != _galleryTabIndex) {
      return;
    }
    _galleryLoadStarted = true;
    logFailure(
      _checkPermissionAndLoad(),
      _PhotoPickerPageState,
      'check permission and load',
    );
  }

  /// Clears what an earlier session left behind, then stages the files this
  /// session was opened with. In that order, so the clear cannot wipe them.
  Future<void> _startSession() async {
    _clearStaleStaging();
    final paths = widget.initialFilePaths;
    if (!mounted || paths == null || paths.isEmpty) return;
    await stageFilesForReview(
      ProviderScope.containerOf(context, listen: false),
      paths,
      target: widget.target,
      isActive: () => mounted,
    );
  }

  /// Drops files staged, and URLs drafted, by an earlier session that was
  /// abandoned rather than committed: `filesTabNotifierProvider` and
  /// `urlTabNotifierProvider` are not autoDispose, and this session may well
  /// attach to a different dive, or to a site. The Gallery selection needs
  /// no reset here; its provider is autoDispose.
  ///
  /// Deferred by a microtask because Riverpod forbids mutating a provider
  /// inside a widget life-cycle. It still lands before the first frame the
  /// user can interact with, and before [_startSession] stages any files
  /// the page was opened with.
  void _clearStaleStaging() {
    if (!mounted) return;
    ref.read(filesTabNotifierProvider.notifier).clearStagedFiles();
    ref.read(urlTabNotifierProvider.notifier).startSession();
  }

  Future<void> _checkPermissionAndLoad() async {
    final notifier = ref.read(photoPickerNotifierProvider.notifier);
    await notifier.checkPermission();
    // Closed while the check was in flight: the session's notifier is gone.
    if (!mounted) return;

    // Set already-linked IDs so they appear dimmed and non-selectable
    notifier.setAlreadyLinkedIds(widget.alreadyLinkedIds);

    final state = ref.read(photoPickerNotifierProvider);
    if (state.hasPermission) {
      logFailure(_loadAssets(), _PhotoPickerPageState, 'load assets');
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
    final loadAssets = widget.loadAssets;
    final assets = loadAssets != null
        ? await loadAssets(() => mounted)
        : await service.getAssetsInDateRange(widget.startTime, widget.endTime);
    if (mounted) {
      setState(() {
        _assets = assets;
        _albumOptions = galleryAlbumOptions(assets);
      });
    }
  }

  /// The assets the grid shows: [_assets] narrowed to [_albumName].
  List<AssetInfo> get _visibleAssets => assetsInAlbum(_assets!, _albumName);

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
    // Tropical light fills its app bar with primary, the colour a stock tab
    // and TextButton paint in, so both take colours that read on the bar.
    final barColors = AppBarTabColors.of(Theme.of(context));

    final appBarLeading = IconButton(
      icon: const Icon(Icons.close),
      tooltip: context.l10n.media_photoPicker_closeTooltip,
      onPressed: () => Navigator.of(context).pop(),
    );
    final doneAction = TextButton(
      style: barColors.textButtonStyle,
      onPressed: state.selectionCount > 0 ? _handleDone : null,
      child: Text(
        state.selectionCount > 0
            ? context.l10n.media_photoPicker_doneCountButton(
                state.selectionCount,
              )
            : context.l10n.media_photoPicker_doneButton,
      ),
    );

    final tabController = _tabController;
    return Scaffold(
      appBar: AppBar(
        leading: appBarLeading,
        title: Text(context.l10n.media_photoPicker_appBarTitle),
        actions: [
          // Done commits the GALLERY tab's selection; the Files and URL
          // tabs carry their own commit buttons. Showing a
          // permanently-greyed Done over those tabs read as "the app
          // rejected my photos" to users who had staged files there,
          // so the action tracks the active tab.
          ListenableBuilder(
            listenable: tabController,
            builder: (context, _) => tabController.index == _galleryTabIndex
                ? doneAction
                : const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          labelColor: barColors.selected,
          unselectedLabelColor: barColors.unselected,
          indicatorColor: barColors.selected,
          overlayColor: barColors.overlay,
          // On a coloured bar its own edge separates it from the page.
          dividerColor: barColors.barMatchesPage ? null : Colors.transparent,
          tabs: [
            Tab(text: context.l10n.media_photoPicker_tab_gallery),
            Tab(text: context.l10n.media_photoPicker_tab_files),
            Tab(text: context.l10n.media_photoPicker_tab_url),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _galleryTab(context),
          FilesTab(target: widget.target),
          UrlTab(target: widget.target),
        ],
      ),
    );
  }

  Widget _galleryTab(BuildContext context) {
    final state = ref.watch(photoPickerNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return _buildBody(context, state, colorScheme);
  }

  Set<int> _indicesOf(List<AssetInfo> visible, Set<String> ids) => {
    for (var i = 0; i < visible.length; i++)
      if (ids.contains(visible[i].id)) i,
  };

  /// Takes the grid's report of its whole selection, which covers only the
  /// [visible] assets, without dropping picks the album filter hides.
  void _syncSelectionToNotifier(List<AssetInfo> visible, Set<int> indices) {
    final state = ref.read(photoPickerNotifierProvider);
    final merged = mergeVisibleSelection(
      current: state.selectedIds,
      visibleIds: visible.map((a) => a.id),
      selectedVisibleIds: indices
          .where((i) => i < visible.length)
          .map((i) => visible[i].id),
    );
    ref.read(photoPickerNotifierProvider.notifier).selectAll(merged.toList());
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

    final visible = _visibleAssets;
    final selectableIds = [
      for (final asset in visible)
        if (!state.alreadyLinkedIds.contains(asset.id)) asset.id,
    ];

    // Show grid
    return Column(
      children: [
        // Date range header
        _DateRangeHeader(startTime: widget.startTime, endTime: widget.endTime),
        GalleryAlbumFilterBar(
          options: _albumOptions,
          totalCount: _assets!.length,
          selectedAlbum: _albumName,
          onSelected: (name) => setState(() => _albumName = name),
        ),
        // Selection toolbar. Always present, even with nothing selected, so
        // the first tap does not push the grid down a row under the user's
        // next tap (#2059).
        GallerySelectionToolbar(
          selectedCount: state.selectionCount,
          canSelectAll: selectableIds.any(
            (id) => !state.selectedIds.contains(id),
          ),
          // Adds the photos on screen; picks under other albums stay.
          onSelectAll: () {
            ref.read(photoPickerNotifierProvider.notifier).selectAll([
              ...state.selectedIds,
              ...selectableIds,
            ]);
          },
          onClearSelection: () {
            ref.read(photoPickerNotifierProvider.notifier).clearSelection();
          },
        ),
        // Photo grid
        Expanded(
          child: DragSelectGridView<AssetInfo>(
            // A fresh grid per album: its scroll offset and index-based
            // selection belong to the list it was built with.
            key: ValueKey(_albumName),
            items: visible,
            startInSelectionMode: state.selectionCount > 0,
            initialSelection: _indicesOf(visible, state.selectedIds),
            disabledIndices: _indicesOf(visible, state.alreadyLinkedIds),
            onSelectionChanged: (indices) {
              _syncSelectionToNotifier(visible, indices);
            },
            // Selection visibility is derived from state.selectionCount,
            // so no additional local tracking is needed here.
            onSelectionModeChanged: (_) {},
            onItemTap: (index) {
              ref
                  .read(photoPickerNotifierProvider.notifier)
                  .toggleSelection(visible[index].id);
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
class _DateRangeHeader extends ConsumerWidget {
  final DateTime startTime;
  final DateTime endTime;

  const _DateRangeHeader({required this.startTime, required this.endTime});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final units = ref.watch(unitFormatterProvider);

    final sameDay =
        startTime.day == endTime.day &&
        startTime.month == endTime.month &&
        startTime.year == endTime.year;

    String rangeText;
    if (sameDay) {
      rangeText =
          '${units.formatMonthDay(startTime)}, ${units.formatTime(startTime)} to ${units.formatTime(endTime)}';
    } else {
      rangeText =
          '${units.formatMonthDay(startTime)} ${units.formatTime(startTime)} to ${units.formatMonthDay(endTime)} ${units.formatTime(endTime)}';
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
class _EmptyStateView extends ConsumerWidget {
  final DateTime startTime;
  final DateTime endTime;

  const _EmptyStateView({required this.startTime, required this.endTime});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final units = ref.watch(unitFormatterProvider);

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
                units.formatMonthDay(startTime),
                units.formatTime(startTime),
                units.formatMonthDay(endTime),
                units.formatTime(endTime),
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
                onPressed: () => pm.PhotoManager.openSetting(),
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

/// Placeholder shown in tabs whose features are still pending. Currently
/// unused after Phase 3a wired the URL tab to [UrlTab]; kept for future
/// phases that may temporarily reintroduce a placeholder in the picker
/// shell.
// ignore: unused_element
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

/// Shows the photo picker as a full-screen modal.
///
/// Returns the list of selected [AssetInfo] objects, or null if cancelled.
/// [initialFilePaths] opens it on the Files tab with those files staged; see
/// [PhotoPickerPage.initialFilePaths]. [loadAssets] replaces the Gallery
/// tab's date range search; see [PhotoPickerPage.loadAssets].
Future<List<AssetInfo>?> showPhotoPicker({
  required BuildContext context,
  required DateTime diveStartTime,
  required DateTime diveEndTime,
  Set<String> alreadyLinkedIds = const {},
  Duration buffer = const Duration(minutes: 30),
  MediaAttachTarget? target,
  List<String>? initialFilePaths,
  Future<List<AssetInfo>> Function(bool Function() isActive)? loadAssets,
}) {
  // Nothing comes in while demo mode is on (#3708): the note, not a picker.
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) {
    return Future<List<AssetInfo>?>.value();
  }
  final startTime = diveStartTime.subtract(buffer);
  final endTime = diveEndTime.add(buffer);

  return Navigator.of(context).push<List<AssetInfo>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PhotoPickerPage(
        startTime: startTime,
        endTime: endTime,
        alreadyLinkedIds: alreadyLinkedIds,
        target: target,
        initialFilePaths: initialFilePaths,
        loadAssets: loadAssets,
      ),
    ),
  );
}
