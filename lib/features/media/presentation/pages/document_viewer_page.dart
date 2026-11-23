import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/attachment_details_hold.dart';
import 'package:submersion/features/media/presentation/editing/attachment_page_closes_when_removed.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_editing.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/widgets/attachment_details_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

/// Full-screen in-app viewer for PDF document attachments.
///
/// Bytes come through [mediaBytesProvider], which resolves the row against
/// the source it points at and falls back to the media store, so a PDF views
/// identically whether it lives behind a local bookmark, a SAF URI, a plain
/// path, or only in the cloud store.
class DocumentViewerPage extends ConsumerStatefulWidget {
  final MediaItem item;

  /// The site this document is attached to, when its category and display
  /// size may be edited here (issue #1039). The document then has its own
  /// lock (issue #4527): opened locked, with no Edit details, and unlocked
  /// its details are held until one Save. Null for dive and equipment
  /// documents, which read only. The filename is never editable.
  final String? editableSiteId;

  const DocumentViewerPage({
    super.key,
    required this.item,
    this.editableSiteId,
  });

  @override
  ConsumerState<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends ConsumerState<DocumentViewerPage>
    with
        PhotoViewerEditing<DocumentViewerPage>,
        AttachmentPageClosesWhenRemoved<DocumentViewerPage> {
  /// pdfrx needs its one-time Flutter bootstrap before the first PdfViewer
  /// builds; the call is idempotent and cheap afterwards.
  late final Future<void> _engineReady = pdfrxFlutterInitialize();

  /// Whether the document has its own lock here.
  bool get _hasLock => widget.editableSiteId != null;

  @override
  bool get editingOffered => _hasLock && super.editingOffered;

  @override
  bool get unlocksDocuments => true;

  @override
  void dispose() {
    disposePhotoEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedAsync = ref.watch(mediaBytesProvider(widget.item));
    final stored = followStoredPhoto(widget.item);
    // Only where the document has its own lock; today's viewer stays.
    if (_hasLock) {
      closeWhenRemoved(widget.item.id, siteId: widget.editableSiteId!);
    }

    return photoEditScope(
      child: Scaffold(
        appBar: photoUnlocked
            ? _editingBar(context)
            : _lockedBar(context, stored),
        body: resolvedAsync.when(
          data: (resolved) {
            if (resolved.isUnavailable || resolved.bytes == null) {
              return _UnavailableState(item: widget.item);
            }
            return FutureBuilder<void>(
              future: _engineReady,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _UnavailableState(item: widget.item);
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return PdfViewer.data(
                  resolved.bytes!,
                  sourceName: widget.item.id,
                  params: PdfViewerParams(
                    // A corrupt file must degrade to the unavailable state,
                    // not crash the page.
                    errorBannerBuilder: (context, error, stackTrace, _) =>
                        _UnavailableState(item: widget.item),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _UnavailableState(item: widget.item),
        ),
      ),
    );
  }

  /// The bar while locked: the lock where the document has one, and Share.
  PreferredSizeWidget _lockedBar(BuildContext context, PhotoRecord? stored) {
    return AppBar(
      title: Text(
        widget.item.originalFilename ?? context.l10n.media_documentViewer_title,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // A device that changes no media (a browser) reads only.
        if (_hasLock && editingOffered)
          IconButton(
            key: const ValueKey('document_unlock'),
            icon: const Icon(Icons.lock_outline),
            tooltip: context.l10n.recordEdit_unlockTooltip,
            onPressed: canUnlock(widget.item, stored)
                ? () => unlockPhoto(stored!)
                : null,
          ),
        // Builder so the share popover anchors to this button on iPad:
        // findRenderObject from a Builder's context descends to the
        // IconButton, whereas the page's context would yield the whole page.
        Builder(
          builder: (buttonContext) => IconButton(
            icon: const Icon(Icons.share),
            tooltip: context.l10n.media_photoViewer_shareTooltip,
            onPressed: () =>
                DocumentOpenHelper.share(buttonContext, ref, widget.item),
          ),
        ),
      ],
    );
  }

  /// The bar while unlocked: Cancel, Save, and Edit details, whose choice
  /// is held until Save.
  PreferredSizeWidget _editingBar(BuildContext context) {
    final controller = photoEditController;
    return RecordEditBar(
      title: context.l10n.media_documentViewer_editing,
      canSave: controller.isDirty,
      isSaving: controller.isSaving,
      onCancel: () => unawaited(cancelPhotoSitting()),
      onSave: () => unawaited(savePhotoAndReport()),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: context.l10n.media_siteAttachment_editDetails,
          onPressed: () => showAttachmentDetailsSheet(
            context,
            item: shownItem(widget.item, const []),
            siteId: widget.editableSiteId!,
            onHold: (category, size) =>
                holdAttachmentDetails(photoSitting, category, size),
          ),
        ),
      ],
    );
  }
}

/// Shown when the document's bytes cannot be resolved on this device (or
/// the file is corrupt). Mentions the origin device when known.
class _UnavailableState extends StatelessWidget {
  final MediaItem item;

  const _UnavailableState({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.media_documentViewer_unavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (item.originDeviceId != null) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.media_documentViewer_availableOnOriginDevice,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
