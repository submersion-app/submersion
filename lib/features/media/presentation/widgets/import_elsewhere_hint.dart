import 'package:flutter/material.dart';

/// One line in a picker opened from a sitting, saying where to add what
/// the sitting cannot hold (issue #4527, media library decisions 2 and 5).
class ImportElsewhereHint extends StatelessWidget {
  const ImportElsewhereHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(Icons.info_outline, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
