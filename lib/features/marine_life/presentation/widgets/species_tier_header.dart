import 'package:flutter/material.dart';

/// The title of one section of a site's species: Spotted here, Expected
/// species or Recorded nearby (issue #5128).
///
/// One style for all three, in full-strength text a step above the
/// category labels beneath it, so each section reads as a section. [count],
/// when given, is the number of species under it, at the trailing edge.
class SpeciesTierHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  /// The species the section lists; null (or zero) draws no count.
  final int? count;

  const SpeciesTierHeader({
    super.key,
    required this.icon,
    required this.title,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = this.count;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (count != null && count > 0)
          Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
