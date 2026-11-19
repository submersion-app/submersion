import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three-way size choice; [followCategory] stores a null override.
enum _SizeChoice { followCategory, large, tile }

_SizeChoice _choiceOf(AttachmentDisplaySize? size) => switch (size) {
  null => _SizeChoice.followCategory,
  AttachmentDisplaySize.large => _SizeChoice.large,
  AttachmentDisplaySize.tile => _SizeChoice.tile,
};

AttachmentDisplaySize? _overrideOf(_SizeChoice choice) => switch (choice) {
  _SizeChoice.followCategory => null,
  _SizeChoice.large => AttachmentDisplaySize.large,
  _SizeChoice.tile => AttachmentDisplaySize.tile,
};

/// A site attachment's category and display size (issue #1039): the Edit
/// details sheet's fields, and the details page's (issue #4527, phase 2).
///
/// [size] is the stored override; null follows the category, whose default
/// the choice names. A null callback draws its field disabled, read only.
class AttachmentDetailsFields extends StatelessWidget {
  const AttachmentDetailsFields({
    super.key,
    required this.category,
    required this.size,
    this.onCategory,
    this.onSize,
  });

  final SiteAttachmentCategory? category;
  final AttachmentDisplaySize? size;
  final ValueChanged<SiteAttachmentCategory?>? onCategory;
  final ValueChanged<AttachmentDisplaySize?>? onSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final defaultSize =
        category?.defaultDisplaySize ?? AttachmentDisplaySize.tile;
    final onSize = this.onSize;
    final choice = _choiceOf(size);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A value set from outside (a sitting cancelled) shows: the field
        // takes a changed initialValue as its value, and keeps its State,
        // so a keyboard keeps its place after a pick.
        DropdownButtonFormField<SiteAttachmentCategory?>(
          initialValue: category,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.media_siteAttachment_categoryLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final option in <SiteAttachmentCategory?>[
              null,
              ...SiteAttachmentCategory.values,
            ])
              DropdownMenuItem(
                value: option,
                child: Text(
                  option.label(l10n),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onCategory,
        ),
        const SizedBox(height: 16),
        // A dropdown, not a segmented control: three segments at phone
        // width cannot hold "Default (Large)" in every language.
        DropdownButtonFormField<_SizeChoice>(
          initialValue: choice,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.media_siteAttachment_sizeLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final (option, label) in [
              (
                _SizeChoice.followCategory,
                l10n.media_siteAttachment_sizeDefault(defaultSize.label(l10n)),
              ),
              (_SizeChoice.large, AttachmentDisplaySize.large.label(l10n)),
              (_SizeChoice.tile, AttachmentDisplaySize.tile.label(l10n)),
            ])
              DropdownMenuItem(
                value: option,
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onSize == null
              ? null
              : (value) {
                  if (value != null) onSize(_overrideOf(value));
                },
        ),
      ],
    );
  }
}
