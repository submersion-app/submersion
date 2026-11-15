import 'package:flutter/material.dart';

/// The inset every card on a built-in site's page pads to, the same as on
/// the diver's own site page.
const kCataloguePageCardPadding = EdgeInsets.all(12);

/// One titled card of a built-in site's page: an icon, a title, and what
/// the card holds beneath them.
class CataloguePageCard extends StatelessWidget {
  const CataloguePageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// Tints the card and its title as a warning, as the Hazards card is on
  /// the diver's own site page.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = warning
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Card(
      color: warning
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: kCataloguePageCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: warning ? accent : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One short fact about a built-in site: a type, an entry, a depth.
class CatalogueFactChip extends StatelessWidget {
  const CatalogueFactChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(text, style: theme.textTheme.labelMedium),
      ),
    );
  }
}
