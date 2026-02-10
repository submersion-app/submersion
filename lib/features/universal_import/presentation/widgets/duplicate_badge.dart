import 'package:flutter/material.dart';

/// Badge indicating an entity is a potential duplicate.
///
/// Used in import entity cards and dive cards to show match confidence.
/// Displays with a warning color for probable matches and a softer
/// color for possible matches.
class DuplicateBadge extends StatelessWidget {
  const DuplicateBadge({super.key, this.label, this.isProbable = true});

  /// Label text (defaults to "Duplicate" or "Possible duplicate").
  final String? label;

  /// Whether the match is probable (>= 0.7) vs possible (>= 0.5).
  final bool isProbable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = isProbable ? colorScheme.error : colorScheme.tertiary;
    final displayLabel = label ?? (isProbable ? 'Duplicate' : 'Possible match');

    return Semantics(
      label: isProbable ? 'Probable duplicate' : 'Possible duplicate',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                isProbable
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                size: 14,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 12,
                color: badgeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
