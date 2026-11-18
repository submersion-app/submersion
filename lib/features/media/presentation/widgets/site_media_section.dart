import 'package:flutter/material.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/helpers/site_media_import_helper.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/attachment_details_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_groups.dart';
import 'package:submersion/features/media/presentation/widgets/site_category_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Section widget displaying a site's direct attachments: maps, entry-point
/// photos and documents. Photos from the dives logged at the site have their
/// own card, `SiteDivePhotosCard` (issue #4502).
///
/// Add actions and document opening are injected by the page so this widget
/// stays free of picker/viewer wiring, mirroring [DiveMediaSection].
///
/// On a page that edits the site in place (issue #4527, phase 2) the card
/// reads only, except for an attachment's own details (its own record), and
/// [editing], the open card's sitting, holds what it adds and unlinks until
/// Save.
class SiteMediaSection extends ConsumerStatefulWidget {
  final String siteId;
  final VoidCallback? onAddPhotosPressed;
  final VoidCallback? onAddDocumentPressed;
  final void Function(MediaItem)? onOpenDocument;

  /// The open Media card's sitting on the site.
  final EditSession<DiveSite>? editing;

  const SiteMediaSection({
    super.key,
    required this.siteId,
    this.onAddPhotosPressed,
    this.onAddDocumentPressed,
    this.onOpenDocument,
    this.editing,
  });

  @override
  ConsumerState<SiteMediaSection> createState() => _SiteMediaSectionState();
}

class _SiteMediaSectionState extends ConsumerState<SiteMediaSection> {
  /// A browser shows the media it can and links none (issue #4121).
  bool get _canAttach => ref.watch(deviceCapabilitiesProvider).mediaAttach;

  /// Owns the bulk-selection state machine for this section.
  ///
  /// Id-based, unlike the positional per-category grids it drives (see
  /// [SiteAttachmentGroups]). Each grid derives its indices from ids on every
  /// build, so reordering or regrouping the media can never repoint the
  /// selection at different files.
  final SelectionController _selection = SelectionController();

  bool get _isSelectionMode => _selection.value.isActive;

  /// A page that edits in place, with no sitting given: nothing may be
  /// added or unlinked here.
  bool _readOnly = false;

  /// The ids the sitting has added and not yet written: no file to open,
  /// no row to check or give details to before Save.
  Set<String> _heldIds = const {};

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

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

    final editing = widget.editing;
    if (confirmed == true && editing != null) {
      unlinkMediaInSitting(editing, selectedIds.toSet());
      return BulkActionOutcome.completed;
    }
    // The card closed while the dialog was up: read only now.
    if (_readOnly) return BulkActionOutcome.cancelled;
    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(siteMediaListNotifierProvider(widget.siteId).notifier)
            .unlinkMultipleMedia(selectedIds);

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
        return BulkActionOutcome.completed;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.media_siteMediaSection_unlinkError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return BulkActionOutcome.failed;
      }
    }
    return BulkActionOutcome.cancelled;
  }

  /// Bulk Set category (issue #1039): one category for every checked item.
  Future<BulkActionOutcome> _setCategoryForSelected(
    BuildContext context,
  ) async {
    final ids = _selection.value.checkedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;
    final choice = await showSiteCategoryPicker(context);
    if (choice == null || !context.mounted) return BulkActionOutcome.cancelled;
    try {
      // The count of rows actually changed: an id unlinked while the
      // picker was open is skipped and must not be reported as updated.
      final updated = await ref
          .read(siteMediaListNotifierProvider(widget.siteId).notifier)
          .setSiteCategory(ids, choice.category);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_siteAttachment_setCategorySuccess(updated),
            ),
          ),
        );
      }
      return BulkActionOutcome.completed;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_siteAttachment_setCategoryError(e),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return BulkActionOutcome.failed;
    }
  }

  /// Edit details for the one checked item: the path for a tile, and for a
  /// non-PDF document, which has no viewer to edit from.
  Future<BulkActionOutcome> _editSelected(
    BuildContext context,
    List<MediaItem> media,
  ) async {
    final ids = _selection.value.checkedIds;
    if (ids.length != 1) return BulkActionOutcome.cancelled;
    final item = media.where((m) => m.id == ids.single).firstOrNull;
    if (item == null) return BulkActionOutcome.cancelled;
    final saved = await showAttachmentDetailsSheet(
      context,
      item: item,
      siteId: widget.siteId,
    );
    return saved == null
        ? BulkActionOutcome.cancelled
        : BulkActionOutcome.completed;
  }

  void _openItem(BuildContext context, MediaItem item, SiteViewerScope scope) {
    // Held until Save: there is no row to open yet.
    if (_heldIds.contains(item.id)) return;
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
    final scope = RecordEditScope.maybeOf<DiveSite>(context);
    _readOnly = scope != null && widget.editing == null;
    final session = widget.editing ?? scope?.session;
    final stored = ref.watch(mediaForSiteProvider(widget.siteId));
    // During a sitting, the media it holds: added ones in, unlinked out.
    final mediaAsync = session == null
        ? stored
        : stored.whenData((media) => mediaInSitting(session, media));
    _heldIds = session == null
        ? const {}
        : {for (final a in sittingMedia(session).added) a.preview.id};
    final settings = ref.watch(unitFormatterProvider).settings;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final visibleIds = [
      for (final m in mediaAsync.value ?? const <MediaItem>[])
        if (!_heldIds.contains(m.id)) m.id,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selection.pruneToSettled(mediaAsync, (rows) => rows.map((m) => m.id));
      }
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
    UnitFormatterSettings settings,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final selectionMedia = [
      for (final m in mediaAsync.value ?? const <MediaItem>[])
        if (!_heldIds.contains(m.id)) m,
    ];
    // In the open card the adds go to the sitting.
    final editing = widget.editing;
    final VoidCallback? onAddPhotos = _readOnly
        ? null
        : editing == null
        ? widget.onAddPhotosPressed
        : () => SiteMediaImportHelper.importPhotosForSite(
            context: context,
            ref: ref,
            siteId: widget.siteId,
            onHold: (adds) => addMediaToSitting(editing, adds),
            unlinkedInSitting: sittingMedia(editing).unlinked,
          );
    final VoidCallback? onAddDocument = _readOnly
        ? null
        : editing == null
        ? widget.onAddDocumentPressed
        : () => DocumentOpenHelper.pickAndAttach(
            context: context,
            ref: ref,
            siteId: widget.siteId,
            onHold: (adds) => addMediaToSitting(editing, adds),
          );
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
            if (_isSelectionMode)
              SelectionAppBar(
                controller: _selection,
                selectableIds: selectionMedia.map((m) => m.id).toList(),
                shell: SelectionBarShell.pane,
                // Unlinking removes the rows from the library unless
                // a dive still uses them; files on disk are never
                // touched. There is no separate delete here.
                onDelete: null,
                actions: [
                  if (!_readOnly)
                    BulkAction(
                      id: 'unlink',
                      icon: Icons.link_off,
                      label: context.l10n
                          .media_diveMediaSection_unlinkSelectedButton(
                            _selection.value.count,
                          ),
                      onInvoke: () => _unlinkSelected(context, selectionMedia),
                    ),
                  BulkAction(
                    id: 'setCategory',
                    icon: Icons.label_outline,
                    label: context.l10n.media_siteAttachment_setCategory,
                    onInvoke: () => _setCategoryForSelected(context),
                  ),
                  BulkAction(
                    id: 'editDetails',
                    icon: Icons.edit_outlined,
                    label: context.l10n.media_siteAttachment_editDetails,
                    maxCount: 1,
                    onInvoke: () => _editSelected(context, selectionMedia),
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
                      context.l10n.media_siteMediaSection_title,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  // The only way into selection: entry by long-press was
                  // removed, so nothing but this control opens the mode.
                  mediaAsync.whenOrNull(
                        data: (media) => media.isEmpty || !_canAttach
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
                  if (_canAttach &&
                      (onAddPhotos != null || onAddDocument != null))
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      tooltip: context.l10n.media_diveMediaSection_addTooltip,
                      onSelected: (value) {
                        if (value == 'photos') onAddPhotos?.call();
                        if (value == 'document') onAddDocument?.call();
                      },
                      itemBuilder: (context) => [
                        if (onAddPhotos != null)
                          PopupMenuItem(
                            value: 'photos',
                            child: Text(
                              context.l10n.media_siteMediaSection_addPhotos,
                            ),
                          ),
                        if (onAddDocument != null)
                          PopupMenuItem(
                            value: 'document',
                            child: Text(
                              context.l10n.media_siteMediaSection_addDocument,
                            ),
                          ),
                      ],
                    ),
                  // Its pencil, while the site is unlocked (issue #4527).
                  RecordCardPencil(
                    cardTitle: context.l10n.media_siteMediaSection_title,
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
                return SiteAttachmentGroups(
                  layout: layoutSiteAttachments(media),
                  selection: _selection,
                  isSelectionMode: _isSelectionMode,
                  settings: settings,
                  onOpen: (item) =>
                      _openItem(context, item, SiteViewerScope.attachments),
                  // An attachment's details are its own record's; one
                  // held until Save has none to give yet.
                  onEditDetails: (item) {
                    if (_heldIds.contains(item.id)) return;
                    showAttachmentDetailsSheet(
                      context,
                      item: item,
                      siteId: widget.siteId,
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
