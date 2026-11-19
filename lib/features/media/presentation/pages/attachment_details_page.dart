import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/attachment_details_hold.dart';
import 'package:submersion/features/media/presentation/editing/attachment_page_closes_when_removed.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_editing.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/features/media/presentation/widgets/attachment_details_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

/// A site document with no in-app viewer (a Word file, a spreadsheet),
/// opened from a site page that edits in place (issue #4527, phase 2): its
/// name, Open, Share and its details, with the attachment's own lock. It
/// opens locked, the details read only; unlocked, they change in place and
/// are held until one Save, as in the PDF viewer.
class AttachmentDetailsPage extends ConsumerStatefulWidget {
  const AttachmentDetailsPage({
    super.key,
    required this.item,
    required this.siteId,
    this.showOpen,
  });

  final MediaItem item;

  /// The site the document is attached to.
  final String siteId;

  /// Whether Open is offered: where it opens the file in another app, a
  /// desktop. On a phone opening a file is the share sheet, Share again.
  /// Null takes this device's answer.
  final bool? showOpen;

  @override
  ConsumerState<AttachmentDetailsPage> createState() =>
      _AttachmentDetailsPageState();
}

class _AttachmentDetailsPageState extends ConsumerState<AttachmentDetailsPage>
    with
        PhotoViewerEditing<AttachmentDetailsPage>,
        AttachmentPageClosesWhenRemoved<AttachmentDetailsPage> {
  @override
  bool get unlocksDocuments => true;

  @override
  void dispose() {
    disposePhotoEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stored = followStoredPhoto(widget.item);
    closeWhenRemoved(widget.item.id, siteId: widget.siteId);
    // Followed whether or not this device edits, so a browser shows a
    // change made elsewhere too.
    final storedItem =
        ref.watch(photoRecordProvider(widget.item.id)).value?.item ??
        widget.item;
    final shown = shownItem(storedItem, const []);
    final unlocked = photoUnlocked;
    final controller = unlocked ? photoEditController : null;
    // Not while Save runs: the sitting takes nothing then, and a pick
    // would show a value that is never saved.
    final editable = controller != null && !controller.isSaving;
    final showOpen = widget.showOpen ?? HostPlatform.isDesktop;

    return photoEditScope(
      child: Scaffold(
        appBar: controller != null
            ? RecordEditBar(
                title: l10n.media_attachmentDetails_editing,
                canSave: controller.isDirty,
                isSaving: controller.isSaving,
                onCancel: () => unawaited(cancelPhotoSitting()),
                onSave: () => unawaited(savePhotoAndReport()),
              )
            : AppBar(
                title: Text(l10n.media_siteAttachment_detailsTitle),
                actions: [
                  // A device that changes no media (a browser) reads only.
                  if (editingOffered)
                    IconButton(
                      key: const ValueKey('document_unlock'),
                      icon: const Icon(Icons.lock_outline),
                      tooltip: l10n.recordEdit_unlockTooltip,
                      onPressed: canUnlock(widget.item, stored)
                          ? () => unlockPhoto(stored!)
                          : null,
                    ),
                  // Builder so the share popover anchors to this button on
                  // iPad.
                  Builder(
                    builder: (buttonContext) => IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: l10n.media_photoViewer_shareTooltip,
                      onPressed: () => DocumentOpenHelper.share(
                        buttonContext,
                        ref,
                        widget.item,
                      ),
                    ),
                  ),
                ],
              ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              // Never editable: the stored name is how other devices
              // re-find the file.
              title: Text(shown.originalFilename ?? ''),
            ),
            const SizedBox(height: 16),
            AttachmentDetailsFields(
              category: shown.siteCategory,
              size: shown.displaySizeOverride,
              onCategory: editable
                  ? (category) => holdAttachmentDetails(
                      photoSitting,
                      category,
                      shown.displaySizeOverride,
                    )
                  : null,
              onSize: editable
                  ? (size) => holdAttachmentDetails(
                      photoSitting,
                      shown.siteCategory,
                      size,
                    )
                  : null,
            ),
            if (showOpen) ...[
              const SizedBox(height: 24),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.media_attachmentDetails_open),
                  onPressed: () => DocumentOpenHelper.openExternally(
                    context,
                    ref,
                    widget.item,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
