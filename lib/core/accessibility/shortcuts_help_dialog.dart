import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/shortcut_registry.dart';

/// Shows the keyboard shortcuts help dialog.
void showShortcutsHelpDialog(BuildContext context) {
  showDialog(context: context, builder: (_) => const ShortcutsHelpDialog());
}

/// A dialog displaying all registered keyboard shortcuts grouped by category.
///
/// Reads from [ShortcutCatalog.instance] to stay in sync with actual
/// registered shortcuts. Shows platform-appropriate modifier keys
/// (Cmd on macOS, Ctrl on Windows/Linux).
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = defaultTargetPlatform;
    final grouped = ShortcutCatalog.instance.byCategory;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.keyboard, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Keyboard Shortcuts',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Shortcut list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in grouped.entries) ...[
                      _CategorySection(
                        category: entry.key,
                        shortcuts: entry.value,
                        platform: platform,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.shortcuts,
    required this.platform,
  });

  final String category;
  final List<ShortcutEntry> shortcuts;
  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final shortcut in shortcuts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: _ShortcutKeyChip(
                      label: shortcut.displayKey(platform),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shortcut.label,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShortcutKeyChip extends StatelessWidget {
  const _ShortcutKeyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
