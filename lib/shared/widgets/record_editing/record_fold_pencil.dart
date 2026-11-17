import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// What a folded section's header row carries while its record is unlocked
/// and its card is not open (issue #4527): the dot when the card has unsaved
/// changes, then the pencil that opens it.
///
/// In a layout whose header rows fold and unfold their sections, the row
/// keeps doing that, and the pencil alone opens the editor. Open, the card's
/// own header carries the dot.
class RecordFoldPencil extends StatelessWidget {
  const RecordFoldPencil({
    super.key,
    required this.title,
    required this.isChanged,
    required this.onOpen,
  });

  /// The card's title, which the pencil's tooltip names.
  final String title;

  /// Whether the card has unsaved changes.
  final bool isChanged;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isChanged) const RecordChangedDot(),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: Theme.of(context).colorScheme.primary,
          tooltip: context.l10n.recordEdit_editCardTooltip(title),
          onPressed: onOpen,
        ),
      ],
    );
  }
}
