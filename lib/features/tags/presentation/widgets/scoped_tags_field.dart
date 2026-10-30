import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A Tags field for an edit form (issues #1942, #1970): the tag input plus a
/// Browse button, both limited to [scope]'s tags. A tag created here applies
/// to [scope]; a name another scope already uses widens that tag instead of
/// creating a second one.
class ScopedTagsField extends StatelessWidget {
  const ScopedTagsField({
    super.key,
    required this.scope,
    required this.label,
    required this.selectedTags,
    required this.onTagsChanged,
    this.enabled = true,
    this.browseKey,
  });

  final TagScope scope;
  final String label;
  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onTagsChanged;

  /// False when the stored tags could not be read. Editing then would save
  /// a set built without them, dropping them.
  final bool enabled;

  /// The Browse button's key, for tests.
  final Key? browseKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sell_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            // The same picker the dive and site pages open, listing the
            // diver's tags of this scope most used first.
            TextButton.icon(
              key: browseKey,
              onPressed: enabled
                  ? () => showTagPickerSheet(
                      context,
                      selected: selectedTags,
                      onPicked: onTagsChanged,
                      scope: scope,
                    )
                  : null,
              icon: const Icon(Icons.label_outline, size: 18),
              label: Text(l10n.tags_action_browse),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TagInputWidget(
          selectedTags: selectedTags,
          onTagsChanged: onTagsChanged,
          enabled: enabled,
          scope: scope,
        ),
      ],
    );
  }
}
