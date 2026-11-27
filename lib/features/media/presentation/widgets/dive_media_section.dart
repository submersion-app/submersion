import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/media/presentation/helpers/lightroom_scan_helper.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/helpers/media_link_replacer.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/utils/file_reveal.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/lightroom_suggestions_row.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_hover_region.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/dive_gallery_scan_in_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/helpers/photo_import_helper.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// The height the dive card packs its media rows at, smaller than the
/// library's so the card sits within a details page (issue #4739).
const double kDiveMediaRowHeight = 120;

/// The space between the dive card's tiles, across and down (issue #4739).
const double kDiveMediaGap = 4;

/// Returns the OS-appropriate label for the "show file in OS file manager"
/// menu item used by the right-click context menu.
///
/// Top-level (public) so it can be unit-tested without a widget tree;
/// the right-click handlers in [DiveMediaSection] only fire on desktop and
/// can't be exercised from `flutter test`.
@visibleForTesting
String showInOsFileManagerLabel() {
  if (HostPlatform.isMacOS) return 'Show in Finder';
  // coverage:ignore-start
  // Windows-only branch — test suite runs on macOS / Linux. On Linux the
  // `if (Platform.isWindows)` evaluates false and the function falls
  // through to 'Show in Files' (covered).
  if (HostPlatform.isWindows) {
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

  /// Invoked when a document tile is tapped (documents never enter the
  /// photo viewer).
  final void Function(MediaItem)? onOpenDocument;

  /// Invoked with the item when a mouse pointer enters its thumbnail, and
  /// with null when the pointer leaves the item last reported (issue #4524).
  /// Every item reported is followed by a null before the next item, and a
  /// leave for any other item is not reported, so the last call always
  /// names what is under the pointer now. Touch never hovers.
  final void Function(MediaItem? item)? onHoverMedia;

  /// The open Media card's sitting on the dive (issue #4527): photos and
  /// documents added, unlinked or relinked go there, held until Save. With
  /// no sitting given the card reads only: a tap still opens a photo or a
  /// document.
  final EditSession<Dive>? editing;

  const DiveMediaSection({
    super.key,
    required this.diveId,
    this.onOpenDocument,
    this.onHoverMedia,
    this.editing,
  });

  @override
  ConsumerState<DiveMediaSection> createState() => _DiveMediaSectionState();
}

class _DiveMediaSectionState extends ConsumerState<DiveMediaSection> {
  /// A browser shows the media it can and links none (issue #4121).
  bool get _canAttach => ref.watch(deviceCapabilitiesProvider).mediaAttach;

  /// Whether this card can link, unlink or relink media here and now: only
  /// the open card can, holding what it changes until Save.
  bool get _canWrite => _canAttach && widget.editing != null;

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

  /// The item last reported through [DiveMediaSection.onHoverMedia], and the
  /// callback it was reported to. Not build state: nothing here draws
  /// differently for them.
  String? _hoveredMediaId;
  void Function(MediaItem? item)? _hoverReportedTo;

  /// Passes a thumbnail's hover on, dropping a leave that is not for the
  /// item last reported. A removed thumbnail reports its leave after the
  /// frame ([MediaHoverRegion]), by which time its neighbour may already
  /// have reported an enter; that late leave must not clear the neighbour.
  ///
  /// The leave goes to the callback that was told about the enter. By the
  /// time a late leave arrives this State may have been handed another
  /// dive's callback (the page reuses it from dive to dive), and telling
  /// that one would leave the first dive marked for good.
  void _onTileHover(MediaItem item, bool hovered) {
    if (hovered) {
      // Another thumbnail still marked hovered has not reported its leave
      // yet (it is the late one). Close it now, so every callback told
      // about an enter hears the leave that ends it.
      if (_hoveredMediaId != null && _hoveredMediaId != item.id) {
        _hoverReportedTo?.call(null);
      }
      _hoveredMediaId = item.id;
      _hoverReportedTo = widget.onHoverMedia;
      _hoverReportedTo?.call(item);
    } else if (_hoveredMediaId == item.id) {
      final reportedTo = _hoverReportedTo;
      _hoveredMediaId = null;
      _hoverReportedTo = null;
      reportedTo?.call(null);
    }
  }

  /// The last layout, kept while the card's width and the items' shapes
  /// stay the same, so the grid delegate (which compares tables by
  /// identity) does not relayout on every rebuild.
  ({List<double> ratios, double width, JustifiedMediaTable table})? _layout;

  /// The justified layout of [ratios] across [width] (issue #4739): rows of
  /// about [kDiveMediaRowHeight], [kDiveMediaGap] apart, ending flush with
  /// the card.
  JustifiedMediaTable _tableFor(List<double> ratios, double width) {
    final cached = _layout;
    if (cached != null &&
        cached.width == width &&
        listEquals(cached.ratios, ratios)) {
      return cached.table;
    }
    final table = JustifiedMediaTable.build(
      sections: [JustifiedSection(headerExtents: const [], ratios: ratios)],
      paneWidth: width,
      targetHeight: kDiveMediaRowHeight,
      gap: kDiveMediaGap,
      inset: 0,
    );
    _layout = (ratios: ratios, width: width, table: table);
    return table;
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  /// The open card's Lightroom scan: what it finds is held in the sitting
  /// until Save (issue #4527).
  Future<void> _scanLightroom(BuildContext context) async {
    final editing = widget.editing;
    if (editing == null) return;
    await runLightroomScanInSitting(context, ref, editing);
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

  Future<BulkActionOutcome> _unlinkSelected(
    BuildContext context,
    List<MediaItem> media,
  ) async {
    final selectedIds = _selection.value.checkedIds.toList();

    if (selectedIds.isEmpty) return BulkActionOutcome.cancelled;

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

    // The card closed while the dialog was up: there is no sitting to hold
    // the unlink, so nothing happens.
    final editing = widget.editing;
    if (confirmed != true || editing == null) {
      return BulkActionOutcome.cancelled;
    }
    unlinkMediaInSitting(editing, selectedIds.toSet());
    return BulkActionOutcome.completed;
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
    // Offered only in the open card, which holds the relink until Save.
    final editing = widget.editing;
    if (editing == null) return;
    await replaceMediaLink(
      context,
      ref,
      item,
      onHold: (proposal) => replaceLinkInSitting(editing, item.id, proposal),
    );
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
    if (!HostPlatform.isDesktop) return;

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
        if (ref.read(deviceCapabilitiesProvider).mediaAttach &&
            widget.editing != null)
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
    final scope = RecordEditScope.maybeOf<Dive>(context);
    final session = widget.editing ?? scope?.session;
    final stored = ref.watch(mediaForDiveProvider(widget.diveId));
    // During a sitting, the media it holds: added ones in, unlinked out.
    final mediaAsync = session == null
        ? stored
        : stored.whenData((media) => mediaInSitting(session, media));
    _scheduleEnrichmentBackfill(mediaAsync.valueOrNull);
    // The shapes the library has learned from decoded thumbnails, so a photo
    // stored sideways lays out the way it is shown. Watched here, in this
    // State's build, so the subscription lives with the card rather than
    // being reopened by the selection builder below, and only once there is
    // media to lay out, so an empty dive does not read the whole cache. A
    // cache that cannot be read loads as empty, so this never waits for good.
    final hasMedia = mediaAsync.value?.isNotEmpty ?? false;
    final learned = hasMedia
        ? ref.watch(mediaLearnedAspectsProvider).value
        : null;
    final settings = ref.watch(unitFormatterProvider).settings;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Drop checked media that is no longer attached to this dive, so an
    // unlink can never reach an item that is not on screen.
    final visibleIds =
        mediaAsync.value?.map((m) => m.id).toList() ?? const <String>[];
    // Judged here, in build: _canWrite watches a provider.
    final canWrite = _canWrite;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A card that can no longer write keeps no selection, so its Unlink
      // cannot outlive the open card (or reach the stored rows directly).
      if (!canWrite) {
        if (_isSelectionMode) _selection.exit();
        return;
      }
      _selection.pruneToSettled(mediaAsync, (rows) => rows.map((m) => m.id));
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => _buildCard(
          context,
          mediaAsync,
          learned,
          settings,
          colorScheme,
          textTheme,
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AsyncValue<List<MediaItem>> mediaAsync,
    Map<String, LearnedAspect>? learned,
    UnitFormatterSettings settings,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final selectionMedia = mediaAsync.value ?? const <MediaItem>[];
    // Only the open card adds, holding what it adds in its sitting.
    final editing = widget.editing;
    final adding = _canAttach ? editing : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: selection mode or normal
            // Built from the value rather than the data branch, so a reload
            // that holds its rows keeps the bar (and its exit) on screen; the
            // controller disables the row actions while the rows are loading.
            if (_isSelectionMode && _canWrite)
              SelectionAppBar(
                controller: _selection,
                selectableIds: selectionMedia.map((m) => m.id).toList(),
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
                    onInvoke: () => _unlinkSelected(context, selectionMedia),
                  ),
                ],
              )
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
                        data: (media) => media.isEmpty || !_canWrite
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
                  if (adding != null)
                    IconButton(
                      icon: Icon(
                        Icons.image_search,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.media_diveScan_scanTooltip,
                      onPressed: () =>
                          scanGalleryInSitting(context, ref, adding),
                    ),
                  // Lightroom scan hidden pending Adobe review
                  // (lightroomUiEnabled).
                  if (_canWrite &&
                      lightroomUiEnabled &&
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
                  if (adding != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onSelected: (value) {
                        if (value == 'photos') {
                          PhotoImportHelper.importPhotosForDive(
                            context: context,
                            ref: ref,
                            dive: adding.working,
                            onHold: (adds) => addMediaToSitting(adding, adds),
                          );
                        }
                        if (value == 'document') {
                          DocumentOpenHelper.pickAndAttach(
                            context: context,
                            ref: ref,
                            diveId: widget.diveId,
                            onHold: (adds) => addMediaToSitting(adding, adds),
                          );
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
                  // Its pencil, while the dive is unlocked.
                  RecordCardPencil(
                    cardTitle: context.l10n.media_diveMediaSection_title,
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
                // The first layout waits for the learned shapes, as the
                // library's does, so photos do not jump into place.
                if (learned == null) return const _MediaLoading();
                final ratios = mediaLayoutRatios(media, learned);
                final indexById = {
                  for (var i = 0; i < media.length; i++) media[i].id: i,
                };
                return LayoutBuilder(
                  builder: (context, constraints) => _buildGrid(
                    context,
                    media,
                    _tableFor(ratios, constraints.maxWidth),
                    indexById,
                    settings,
                  ),
                );
              },
              loading: () => const _MediaLoading(),
              // The open card offers to read again, as every card of a
              // sitting does (issue #4527).
              error: (error, stack) => widget.editing != null
                  ? SittingLoadFailed(
                      onRetry: () =>
                          ref.invalidate(mediaForDiveProvider(widget.diveId)),
                    )
                  : Text(
                      context.l10n.media_diveMediaSection_errorLoading,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
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

  /// The media in justified rows (issue #4739). The grid finds the tile
  /// under a drag by each tile's own key, so drag-select works across rows
  /// of uneven tiles as it did across the old square columns.
  Widget _buildGrid(
    BuildContext context,
    List<MediaItem> media,
    JustifiedMediaTable table,
    Map<String, int> indexById,
    UnitFormatterSettings settings,
  ) {
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
      onSelectionModeChanged: (_) {}, // coverage:ignore-line
      onItemTap: (index) {
        final item = media[index];
        final scope = RecordEditScope.maybeOf<Dive>(context);
        final session = widget.editing ?? scope?.session;
        if (item.isDocument) {
          // A document held until Save has no file to open yet.
          if (session != null &&
              sittingMedia(session).added.any((a) => a.preview.id == item.id)) {
            return;
          }
          widget.onOpenDocument?.call(item);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PhotoViewerPage(
              diveId: widget.diveId,
              initialMediaId: item.id,
              // The photos as the dive's sitting has them, so a
              // photo held for Save opens on itself; with no row
              // it cannot be unlocked, and reads only.
              diveEditing: scope,
            ),
          ),
        );
      },
      gridDelegate: JustifiedMediaGridDelegate(table),
      itemBuilder: (context, item, isSelected) {
        final cell = table.rectOf(indexById[item.id]!).size;
        final thumbnail = MediaThumbnailTile(
          item: item,
          settings: settings,
          isSelectionMode: _isSelectionMode,
          isSelected: isSelected,
          semanticsLabel: context.l10n.media_diveMediaSection_thumbnailLabel,
          targetSize: mediaThumbnailDecodeTarget(cell),
          // Teaches the library a photo's displayed shape, which
          // relays this card out too.
          onImageSize: (size) =>
              ref.read(mediaLearnedAspectsProvider.notifier).report(item, size),
        );
        return MediaHoverRegion(
          // By item, not by grid slot: the grid keys its cells by
          // index, so when an item is unlinked its neighbour takes
          // over the same cell, and without this the cell would
          // stay "hovered" for the item that left.
          key: ValueKey(item.id),
          onHoverChanged: (hovered) => _onTileHover(item, hovered),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // coverage:ignore-start
            // The right-click context menu is desktop-only:
            // touchscreens never fire it and no test drives a
            // secondary tap here. It is exercised by manual
            // desktop smoke tests.
            onSecondaryTapDown: (details) =>
                _showLocalFileContextMenu(context, item, details),
            // coverage:ignore-end
            child: thumbnail,
          ),
        );
      },
    );
  }
}

/// The card's spinner while its media or the learned shapes load.
class _MediaLoading extends StatelessWidget {
  const _MediaLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 100,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}
