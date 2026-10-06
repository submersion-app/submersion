import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sheet_messenger_scope.dart';

/// Opens Edit details for site attachment [item] (issue #1039). Resolves to
/// the saved item, or null when the diver cancels.
Future<MediaItem?> showAttachmentDetailsSheet(
  BuildContext context, {
  required MediaItem item,
  required String siteId,
}) => showModalBottomSheet<MediaItem>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SheetMessengerScope(
    child: AttachmentDetailsSheet(item: item, siteId: siteId),
  ),
);

/// The three-way size choice; [followCategory] stores a null override.
enum _SizeChoice { followCategory, large, tile }

/// Category and display size for one site attachment.
///
/// The name is shown but never editable: the stored filename is how other
/// devices re-find a photo and how the repair wizard finds a moved file.
class AttachmentDetailsSheet extends ConsumerStatefulWidget {
  const AttachmentDetailsSheet({
    super.key,
    required this.item,
    required this.siteId,
  });

  final MediaItem item;
  final String siteId;

  @override
  ConsumerState<AttachmentDetailsSheet> createState() =>
      _AttachmentDetailsSheetState();
}

class _AttachmentDetailsSheetState
    extends ConsumerState<AttachmentDetailsSheet> {
  late SiteAttachmentCategory? _category = widget.item.siteCategory;
  late _SizeChoice _size = switch (widget.item.displaySizeOverride) {
    null => _SizeChoice.followCategory,
    AttachmentDisplaySize.large => _SizeChoice.large,
    AttachmentDisplaySize.tile => _SizeChoice.tile,
  };
  bool _saving = false;

  AttachmentDisplaySize? get _override => switch (_size) {
    _SizeChoice.followCategory => null,
    _SizeChoice.large => AttachmentDisplaySize.large,
    _SizeChoice.tile => AttachmentDisplaySize.tile,
  };

  Future<void> _save() async {
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
    final defaultSize =
        _category?.defaultDisplaySize ?? AttachmentDisplaySize.tile;

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
          DropdownButtonFormField<SiteAttachmentCategory?>(
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.media_siteAttachment_categoryLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final category in <SiteAttachmentCategory?>[
                null,
                ...SiteAttachmentCategory.values,
              ])
                DropdownMenuItem(
                  value: category,
                  child: Text(
                    category.label(l10n),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          // A dropdown, not a segmented control: three segments at phone
          // width cannot hold "Default (Large)" in every language.
          DropdownButtonFormField<_SizeChoice>(
            initialValue: _size,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.media_siteAttachment_sizeLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final (choice, label) in [
                (
                  _SizeChoice.followCategory,
                  l10n.media_siteAttachment_sizeDefault(
                    defaultSize.label(l10n),
                  ),
                ),
                (_SizeChoice.large, AttachmentDisplaySize.large.label(l10n)),
                (_SizeChoice.tile, AttachmentDisplaySize.tile.label(l10n)),
              ])
                DropdownMenuItem(
                  value: choice,
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _size = value);
            },
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
                child: Text(l10n.common_action_save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
