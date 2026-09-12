import 'package:flutter/material.dart';

/// A small icon followed by a one-line secondary label, for a card's stat line.
///
/// Built to sit in a [Wrap] with its siblings: the pair stays together and
/// moves to its own line when the card is too narrow for both, and a label
/// still wider than the card ellipsizes instead of overflowing it.
class CardIconLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  /// Tint for both the icon and the label. Defaults to the theme's secondary
  /// text color ([ColorScheme.onSurfaceVariant]).
  final Color? color;

  const CardIconLabel({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = this.color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
