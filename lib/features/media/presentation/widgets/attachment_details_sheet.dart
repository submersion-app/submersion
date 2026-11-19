import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/attachment_details_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sheet_messenger_scope.dart';

/// Opens Edit details for site attachment [item] (issue #1039). Resolves to
/// the saved item, or null when the diver cancels.
///
/// With [onHold] the sheet writes nothing: its button reads Done and hands
/// the chosen category and size over, to be held in the viewer's sitting
/// until it is saved (issue #4527).
Future<MediaItem?> showAttachmentDetailsSheet(
  BuildContext context, {
  required MediaItem item,
  required String siteId,
  void Function(SiteAttachmentCategory? category, AttachmentDisplaySize? size)?
  onHold,
}) => showModalBottomSheet<MediaItem>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SheetMessengerScope(
    child: AttachmentDetailsSheet(item: item, siteId: siteId, onHold: onHold),
  ),
);

/// Category and display size for one site attachment.
///
/// The name is shown but never editable: the stored filename is how other
/// devices re-find a photo and how the repair wizard finds a moved file.
class AttachmentDetailsSheet extends ConsumerStatefulWidget {
  const AttachmentDetailsSheet({
    super.key,
    required this.item,
    required this.siteId,
    this.onHold,
  });

  final MediaItem item;
  final String siteId;

  /// Takes the choice instead of saving it (issue #4527).
  final void Function(
    SiteAttachmentCategory? category,
    AttachmentDisplaySize? size,
  )?
  onHold;

  @override
  ConsumerState<AttachmentDetailsSheet> createState() =>
      _AttachmentDetailsSheetState();
}

class _AttachmentDetailsSheetState
    extends ConsumerState<AttachmentDetailsSheet> {
  late SiteAttachmentCategory? _category = widget.item.siteCategory;

  /// The display size override; null follows the category.
  late AttachmentDisplaySize? _override = widget.item.displaySizeOverride;
  bool _saving = false;

  Future<void> _save() async {
    final hold = widget.onHold;
    if (hold != null) {
      hold(_category, _override);
      Navigator.of(context).pop();
      return;
    }
    final edit = diffAttachmentDetails(
      widget.item,
      category: _category,
      displaySize: _override,
    );
    final navigator = Navigator.of(context);
    if (edit.isEmpty) {
      navigator.pop(widget.item);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(siteMediaListNotifierProvider(widget.siteId).notifier)
          .setAttachmentDetails(widget.item.id, edit);
      // Dismissed by a drag or a tap outside while saving: popping now
      // would close the page underneath instead.
      if (!mounted) return;
      navigator.pop(edit.applyTo(widget.item));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // The sheet's own messenger (SheetMessengerScope), so the snackbar
      // shows above the sheet rather than behind it.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.media_siteAttachment_saveError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final name = widget.item.originalFilename ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.media_siteAttachment_detailsTitle,
            style: textTheme.titleLarge,
          ),
          // Which attachment this is, read-only.
          if (name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          AttachmentDetailsFields(
            category: _category,
            size: _override,
            onCategory: (value) => setState(() => _category = value),
            onSize: (value) => setState(() => _override = value),
          ),
          const SizedBox(height: 24),
          // OverflowBar stacks the buttons when a long translation will not
          // fit beside each other on a narrow phone.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.common_action_cancel),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  widget.onHold == null
                      ? l10n.common_action_save
                      : l10n.common_action_done,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
