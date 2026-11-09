import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The Gallery tab's toolbar: how many photos are picked, with Select All and
/// Clear buttons.
///
/// A button that has nothing to do is disabled rather than removed, so the
/// toolbar keeps the same layout for every selection (#2059).
class GallerySelectionToolbar extends StatelessWidget {
  /// Every photo picked, including picks the album filter hides.
  final int selectedCount;

  /// Whether a photo on screen is still unpicked, so Select All has work.
  final bool canSelectAll;

  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  const GallerySelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.canSelectAll,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            context.l10n.media_photoPicker_selectedCount(selectedCount),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(
            onPressed: canSelectAll ? onSelectAll : null,
            child: Text(context.l10n.media_photoPicker_selectAllButton),
          ),
          TextButton(
            onPressed: selectedCount > 0 ? onClearSelection : null,
            child: Text(context.l10n.media_photoPicker_clearSelectionButton),
          ),
        ],
      ),
    );
  }
}
