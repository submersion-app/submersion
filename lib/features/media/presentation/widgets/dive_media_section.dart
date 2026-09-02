import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/presentation/helpers/lightroom_scan_helper.dart';
import 'package:submersion/features/media/presentation/helpers/media_link_replacer.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/shared/utils/file_reveal.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/lightroom_suggestions_row.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// Returns the OS-appropriate label for the "show file in OS file manager"
/// menu item used by the right-click context menu.
///
/// Top-level (public) so it can be unit-tested without a widget tree;
/// the right-click handlers in [DiveMediaSection] only fire on desktop and
/// can't be exercised from `flutter test`.
@visibleForTesting
String showInOsFileManagerLabel() {
  if (Platform.isMacOS) return 'Show in Finder';
  // coverage:ignore-start
  // Windows-only branch — test suite runs on macOS / Linux. On Linux the
  // `if (Platform.isWindows)` evaluates false and the function falls
  // through to 'Show in Files' (covered).
  if (Platform.isWindows) {
    return 'Show in Explorer';
  }
  // coverage:ignore-end
  return 'Show in Files';
}

/// Section widget displaying media (photos/videos) for a dive.
///
/// Supports multi-select mode via the Select control, with drag-to-range
/// inside it and bulk unlink.
class DiveMediaSection extends ConsumerStatefulWidget {
  final String diveId;
  final VoidCallback? onAddPressed;
  final VoidCallback? onScanPressed;

  /// When provided, the add button becomes a menu offering photos and
  /// documents; without it the button keeps its historical direct-tap
  /// behavior for callers not yet migrated.
  final VoidCallback? onAddDocumentPressed;

  /// Invoked when a document tile is tapped (documents never enter the
  /// photo viewer).
  final void Function(MediaItem)? onOpenDocument;

  const DiveMediaSection({
    super.key,
    required this.diveId,
    this.onAddPressed,
    this.onScanPressed,
    this.onAddDocumentPressed,
    this.onOpenDocument,
  });

  @override
  ConsumerState<DiveMediaSection> createState() => _DiveMediaSectionState();
}

class _DiveMediaSectionState extends ConsumerState<DiveMediaSection> {
  /// Owns the bulk-selection state machine for this section.
  ///
  /// Id-based, unlike the positional [DragSelectGridView] it drives. Indices
  /// are derived from ids on every build, so reordering the media list can no
  /// longer repoint the selection at different files.
  final SelectionController _selection = SelectionController();

  bool get _isSelectionMode => _selection.value.isActive;

  /// Media ids whose enrichment backfill we've already kicked off, so the
  /// post-frame trigger fires once per item rather than on every rebuild.
  final Set<String> _enrichAttempted = {};

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<void> _scanLightroom(BuildContext context) async {
    final dive = await ref
        .read(diveRepositoryProvider)
        .getDiveById(widget.diveId);
    if (dive == null || !context.mounted) return;
    await runLightroomScan(context, ref, [dive]);
  }

  // coverage:ignore-start
  // Post-frame provider glue: schedules a best-effort enrichment backfill so
  // locally-linked media (which the file/folder picker links WITHOUT an
  // enrichment row) gets positioned on the dive profile chart. The logic lives
  // in DiveMediaEnricher (dive_media_enricher_test); this wiring — a post-frame
  // callback plus a provider round-trip — is exercised by manual smoke tests,
  // as flutter_test can't deterministically pump it. Idempotent and guarded by
  // [_enrichAttempted] so it runs once per item, not on every rebuild.
  void _scheduleEnrichmentBackfill(List<MediaItem>? items) {
    if (items == null) return;
    final missing = items
        .where((m) => m.enrichment == null && !m.isDocument)
        .map((m) => m.id)
        .toSet();
    if (missing.difference(_enrichAttempted).isEmpty) return;
    _enrichAttempted.addAll(missing);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _runEnrichmentBackfill(),
    );
  }

  Future<void> _runEnrichmentBackfill() async {
    // The post-frame callback can fire after this state is disposed; touching
    // `ref` then throws, so bail before using it rather than leaning on the
    // catch-all below.
    if (!mounted) return;
    try {
      final enriched = await ref
          .read(diveMediaEnricherProvider)
          .enrichMissingForDive(widget.diveId);
      // Re-read so the grid and the profile chart (both watch
      // mediaForDiveProvider) pick up the new markers.
      if (enriched > 0 && mounted) {
        ref.invalidate(mediaForDiveProvider(widget.diveId));
      }
    } catch (_) {
      // Best-effort: a failure just leaves those markers absent this session.
    }
  }
  // coverage:ignore-end

  void _exitSelectionMode() => _selection.exit();

  /// Grid indices for the checked ids, against the current ordering.
  ///
  /// Derived every build rather than stored: the ids are the truth and the
  /// positions are recomputed, which is what makes a reorder safe.
  Set<int> _indicesFor(List<MediaItem> media) => {
    for (var i = 0; i < media.length; i++)
      if (_selection.value.isChecked(media[i].id)) i,
  };

  /// Ids for the controller, from the grid's positional selection.
  List<String> _idsFor(List<MediaItem> media, Set<int> indices) => indices
      .where((i) => i >= 0 && i < media.length)
      .map((i) => media[i].id)
      .toList();

  Future<void> _unlinkSelected(
    BuildContext context,
    List<MediaItem> media,
  ) async {
    final selectedIds = _selection.value.checkedIds.toList();

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
        // Unlink IS the removal: the rows leave the library along with
        // their cloud proxies and thumbnails, and only a row a dive site
        // still references survives with its dive link cleared. The
        // original source files are never touched.
        await ref
            .read(mediaListNotifierProvider(widget.diveId).notifier)
            .unlinkMultipleMedia(selectedIds);

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
              content: Text(context.l10n.media_diveMediaSection_unlinkError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  // coverage:ignore-start
  // Right-click context menu helpers (desktop-only). They are only reachable
  // through `onSecondaryTapDown`, which does not fire under flutter_test
  // without a real trackpad / mouse driver. All three helpers shell out to
  // `Process.run` / `FilePicker.pickFiles` / `showMenu`, none of which are
  // unit-testable from flutter_test. Exercised by manual desktop smoke tests.

  /// Prompts the user to pick a replacement file for [item] and routes the
  /// re-link through the repair engine (Media section Phase 3): the picked
  /// file is hash-verified against the row's content identity, bookmark
  /// regeneration is engine-owned, and picking DIFFERENT bytes requires an
  /// explicit confirm because accepting re-uploads them to the media store.
  /// Desktop-only by virtue of the right-click gating in the cell builder.
  ///
  /// Phase 2 photo-only constraint: picker is restricted to `FileType.image`
  /// (videos aren't supported as local-file media yet, see [FilesTab]).
  Future<void> _replaceLink(MediaItem item) async {
    final applied = await replaceMediaLink(context, ref, item);
    // The refresh stays here rather than in the helper: it is dive-scoped,
    // and the info panel calls the same flow without a dive list to refresh.
    if (!applied || !mounted) return;
    await ref.read(mediaListNotifierProvider(widget.diveId).notifier).refresh();
  }

  /// Opens the right-click context menu for a local-file media item.
  ///
  /// Returns immediately for non-`localFile` source types or non-desktop
  /// platforms. Desktop-only because `onSecondaryTapDown` does not fire on
  /// touchscreens.
  Future<void> _showLocalFileContextMenu(
    BuildContext context,
    MediaItem item,
    TapDownDetails details,
  ) async {
    if (item.sourceType != MediaSourceType.localFile) return;
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        if (item.localPath != null)
          PopupMenuItem<String>(
            value: 'show',
            // TODO(media): l10n
            child: Text(showInOsFileManagerLabel()),
          ),
        const PopupMenuItem<String>(
          value: 'replace',
          // TODO(media): l10n
          child: Text('Replace link...'),
        ),
      ],
    );

    if (selected == 'show' && item.localPath != null) {
      await revealInFileManager(item.localPath!);
    } else if (selected == 'replace') {
      if (!context.mounted) return;
      await _replaceLink(item);
    }
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaForDiveProvider(widget.diveId));
    _scheduleEnrichmentBackfill(mediaAsync.valueOrNull);
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Drop checked media that is no longer attached to this dive, so an
    // unlink can never reach an item that is not on screen.
    final visibleIds =
        mediaAsync.valueOrNull?.map((m) => m.id).toList() ?? const <String>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) =>
            _buildCard(context, mediaAsync, settings, colorScheme, textTheme),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AsyncValue<List<MediaItem>> mediaAsync,
    AppSettings settings,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: selection mode or normal
            if (_isSelectionMode)
              mediaAsync.whenOrNull(
                    data: (media) => SelectionAppBar(
                      controller: _selection,
                      selectableIds: media.map((m) => m.id).toList(),
                      shell: SelectionBarShell.pane,
                      // Unlinking removes media from this dive without
                      // destroying files, so this surface has no true delete
                      // and the baseline delete control is omitted.
                      onDelete: null,
                      actions: [
                        BulkAction(
                          id: 'unlink',
                          icon: Icons.link_off,
                          label: context.l10n
                              .media_diveMediaSection_unlinkSelectedButton(
                                _selection.value.count,
                              ),
                          onInvoke: () => _unlinkSelected(context, media),
                        ),
                      ],
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
                  // The only way into selection: entry by long-press was
                  // removed, so nothing but this control opens the mode.
                  mediaAsync.whenOrNull(
                        data: (media) => media.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                key: const ValueKey('enter_selection'),
                                icon: Icon(
                                  Icons.checklist,
                                  color: colorScheme.primary,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip:
                                    context.l10n.common_selection_enterTooltip,
                                onPressed: _selection.enterExplicit,
                              ),
                      ) ??
                      const SizedBox.shrink(),
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
                  // Lightroom scan hidden pending Adobe review
                  // (lightroomUiEnabled).
                  if (lightroomUiEnabled &&
                      ref.watch(lightroomAccountProvider).value != null)
                    IconButton(
                      icon: Icon(
                        Icons.cloud_sync_outlined,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.settings_lightroom_scanNow,
                      onPressed: () => _scanLightroom(context),
                    ),
                  if (widget.onAddPressed != null &&
                      widget.onAddDocumentPressed == null)
                    IconButton(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onPressed: widget.onAddPressed,
                    )
                  else if (widget.onAddPressed != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onSelected: (value) {
                        if (value == 'photos') widget.onAddPressed!();
                        if (value == 'document') {
                          widget.onAddDocumentPressed!();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'photos',
                          child: Text(
                            context.l10n.media_siteMediaSection_addPhotos,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'document',
                          child: Text(
                            context.l10n.media_siteMediaSection_addDocument,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 16),
            // Content
            mediaAsync.when(
              data: (media) {
                if (media.isEmpty) {
                  return MediaEmptyState(
                    icon: Icons.photo_camera_outlined,
                    message: context.l10n.media_diveMediaSection_emptyState,
                  );
                }
                return DragSelectGridView<MediaItem>(
                  items: media,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  startInSelectionMode: _isSelectionMode,
                  initialSelection: _indicesFor(media),
                  // The controller owns the mode, because only it knows how the
                  // mode was entered: a Select-button entry must survive at
                  // zero checked, an incidental one must evaporate. Letting the
                  // grid also decide had the two fight -- its exit callback
                  // cleared the controller and the selection callback
                  // immediately reactivated it, leaving the bar stranded at
                  // "0 selected".
                  exitOnEmptySelection: false,
                  onSelectionChanged: (indices) {
                    // The grid reports its complete selection, not a delta, so
                    // this replaces rather than toggles. Not selectAll: that
                    // declares the mode explicit, which would launder a
                    // grid gesture into a deliberate entry.
                    _selection.replaceChecked(_idsFor(media, indices));
                  },
                  // Entry and exit both travel through onSelectionChanged
                  // above; the grid follows the controller back out via
                  // startInSelectionMode.
                  onSelectionModeChanged: (_) {},
                  onItemTap: (index) {
                    final item = media[index];
                    if (item.isDocument) {
                      widget.onOpenDocument?.call(item);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => PhotoViewerPage(
                          diveId: widget.diveId,
                          initialMediaId: item.id,
                        ),
                      ),
                    );
                  },
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  // coverage:ignore-start
                  // The itemBuilder closure only fires when the dive has
                  // media; this widget has no tests that render media (the
                  // suite would need a populated DB + asset resolver
                  // pipeline), so the closure is unreachable from
                  // flutter_test. The right-click context menu wired via
                  // `onSecondaryTapDown` is also desktop-only — touchscreens
                  // never fire it, and `flutter_test` lacks a trackpad
                  // driver. Both are exercised by manual desktop smoke
                  // tests.
                  itemBuilder: (context, item, isSelected) {
                    final thumbnail = MediaThumbnailTile(
                      item: item,
                      settings: settings,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      semanticsLabel:
                          context.l10n.media_diveMediaSection_thumbnailLabel,
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onSecondaryTapDown: (details) =>
                          _showLocalFileContextMenu(context, item, details),
                      child: thumbnail,
                    );
                  },
                  // coverage:ignore-end
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
            // Lightroom suggestions hidden pending Adobe review
            // (lightroomUiEnabled).
            if (lightroomUiEnabled)
              LightroomSuggestionsRow(diveId: widget.diveId),
          ],
        ),
      ),
    );
  }
}
