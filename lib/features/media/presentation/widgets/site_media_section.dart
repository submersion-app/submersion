import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

/// Section widget displaying a site's media: direct attachments (maps,
/// entry-point photos, documents) plus a collapsed group of photos from
/// dives logged at the site.
///
/// Add actions and document opening are injected by the page so this widget
/// stays free of picker/viewer wiring, mirroring [DiveMediaSection].
class SiteMediaSection extends ConsumerStatefulWidget {
  final String siteId;
  final VoidCallback? onAddPhotosPressed;
  final VoidCallback? onAddDocumentPressed;
  final void Function(MediaItem)? onOpenDocument;

  const SiteMediaSection({
    super.key,
    required this.siteId,
    this.onAddPhotosPressed,
    this.onAddDocumentPressed,
    this.onOpenDocument,
  });

  @override
  ConsumerState<SiteMediaSection> createState() => _SiteMediaSectionState();
}

class _SiteMediaSectionState extends ConsumerState<SiteMediaSection> {
  /// Owns the bulk-selection state machine for this section.
  ///
  /// Id-based, unlike the positional [DragSelectGridView] it drives. Indices
  /// are derived from ids on every build, so reordering the media list can no
  /// longer repoint the selection at different files.
  final SelectionController _selection = SelectionController();

  bool get _isSelectionMode => _selection.value.isActive;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _exitSelectionMode() => _selection.exit();

  /// Grid indices for the checked ids, against the current ordering.
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
          ctx.l10n.media_siteMediaSection_unlinkSelectedTitle(
            selectedIds.length,
          ),
        ),
        content: Text(
          ctx.l10n.media_siteMediaSection_unlinkSelectedContent(
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
            .read(siteMediaListNotifierProvider(widget.siteId).notifier)
            .unlinkMultipleMedia(selectedIds);

        _exitSelectionMode();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.media_siteMediaSection_unlinkSelectedSuccess(
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
              content: Text(context.l10n.media_siteMediaSection_unlinkError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _openItem(BuildContext context, MediaItem item, SiteViewerScope scope) {
    if (item.isDocument) {
      widget.onOpenDocument?.call(item);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SiteMediaViewerPage(
          siteId: widget.siteId,
          initialMediaId: item.id,
          scope: scope,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaForSiteProvider(widget.siteId));
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final visibleIds =
        mediaAsync.value?.map((m) => m.id).toList() ?? const <String>[];
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
                      // Unlinking removes the rows from the library unless
                      // a dive still uses them; files on disk are never
                      // touched. There is no separate delete here.
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
                      context.l10n.media_siteMediaSection_title,
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
                  if (widget.onAddPhotosPressed != null ||
                      widget.onAddDocumentPressed != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onSelected: (value) {
                        if (value == 'photos') {
                          widget.onAddPhotosPressed?.call();
                        }
                        if (value == 'document') {
                          widget.onAddDocumentPressed?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        if (widget.onAddPhotosPressed != null)
                          PopupMenuItem(
                            value: 'photos',
                            child: Text(
                              context.l10n.media_siteMediaSection_addPhotos,
                            ),
                          ),
                        if (widget.onAddDocumentPressed != null)
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
            // Attachments grid
            mediaAsync.when(
              data: (media) {
                if (media.isEmpty) {
                  return MediaEmptyState(
                    icon: Icons.map_outlined,
                    message: context.l10n.media_siteMediaSection_emptyState,
                  );
                }
                return DragSelectGridView<MediaItem>(
                  items: media,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  startInSelectionMode: _isSelectionMode,
                  initialSelection: _indicesFor(media),
                  // The controller owns the mode. Letting the grid also
                  // decide had the two fight -- its exit callback cleared the
                  // controller and the selection callback immediately
                  // reactivated it, leaving a selection emptied by hand
                  // stranded at "0 selected".
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
                  onItemTap: (index) => _openItem(
                    context,
                    media[index],
                    SiteViewerScope.attachments,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, item, isSelected) =>
                      MediaThumbnailTile(
                        item: item,
                        settings: settings,
                        isSelectionMode: _isSelectionMode,
                        isSelected: isSelected,
                        semanticsLabel:
                            context.l10n.media_diveMediaSection_thumbnailLabel,
                      ),
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
            // Photos from dives at this site, collapsed by default so site
            // reference material (maps, documents) stays prominent.
            _DivePhotosGroup(siteId: widget.siteId, settings: settings),
          ],
        ),
      ),
    );
  }
}

/// Collapsed, read-only group of photos aggregated from the site's dives.
class _DivePhotosGroup extends ConsumerWidget {
  final String siteId;
  final AppSettings settings;

  const _DivePhotosGroup({required this.siteId, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(mediaFromDivesAtSiteProvider(siteId));
    final textTheme = Theme.of(context).textTheme;

    final grouped = groupedAsync.valueOrNull;
    if (grouped == null || grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    final flat = grouped.values.expand((list) => list).toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: false,
      title: Text(
        context.l10n.media_siteMediaSection_divePhotosGroup(flat.length),
        style: textTheme.titleSmall,
      ),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: flat.length,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => SiteMediaViewerPage(
                  siteId: siteId,
                  initialMediaId: flat[index].id,
                  scope: SiteViewerScope.divePhotos,
                ),
              ),
            ),
            child: MediaThumbnailTile(
              item: flat[index],
              settings: settings,
              isSelectionMode: false,
              isSelected: false,
              semanticsLabel:
                  context.l10n.media_siteMediaSection_divePhotoLabel,
            ),
          ),
        ),
      ],
    );
  }
}
