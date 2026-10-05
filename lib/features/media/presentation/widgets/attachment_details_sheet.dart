import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_filename.dart';
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

/// Name, category and size for one site attachment.
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
  late final AttachmentFilename _name = AttachmentFilename.split(
    widget.item.originalFilename,
  );
  late final TextEditingController _stem = TextEditingController(
    text: _name.stem,
  );
  late SiteAttachmentCategory? _category = widget.item.siteCategory;
  late _SizeChoice _size = switch (widget.item.displaySizeOverride) {
    null => _SizeChoice.followCategory,
    AttachmentDisplaySize.large => _SizeChoice.large,
    AttachmentDisplaySize.tile => _SizeChoice.tile,
  };
  bool _saving = false;

  @override
  void dispose() {
    _stem.dispose();
    super.dispose();
  }

  AttachmentDisplaySize? get _override => switch (_size) {
    _SizeChoice.followCategory => null,
    _SizeChoice.large => AttachmentDisplaySize.large,
    _SizeChoice.tile => AttachmentDisplaySize.tile,
  };

  String? _nameError(BuildContext context) => switch (attachmentNameError(
    widget.item,
    _stem.text,
  )) {
    null => null,
    AttachmentNameError.blank => context.l10n.media_siteAttachment_nameRequired,
    AttachmentNameError.forbiddenCharacter =>
      context.l10n.media_siteAttachment_nameForbidden,
  };

  Future<void> _save() async {
    final edit = diffAttachmentDetails(
      widget.item,
      stem: _stem.text,
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
    final nameError = _nameError(context);
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
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stem,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.media_siteAttachment_nameLabel,
              suffixText: _name.extension.isEmpty
                  ? null
                  : '.${_name.extension}',
              errorText: nameError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SiteAttachmentCategory?>(
            initialValue: _category,
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
                  child: Text(category.label(l10n)),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.media_siteAttachment_sizeLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<_SizeChoice>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _SizeChoice.followCategory,
                label: Text(
                  l10n.media_siteAttachment_sizeDefault(
                    defaultSize.label(l10n),
                  ),
                ),
              ),
              ButtonSegment(
                value: _SizeChoice.large,
                label: Text(AttachmentDisplaySize.large.label(l10n)),
              ),
              ButtonSegment(
                value: _SizeChoice.tile,
                label: Text(AttachmentDisplaySize.tile.label(l10n)),
              ),
            ],
            selected: {_size},
            onSelectionChanged: (s) => setState(() => _size = s.single),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.common_action_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving || nameError != null ? null : _save,
                child: Text(l10n.common_action_save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
