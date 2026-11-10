import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The standing reminder to analyse a blend before diving it. A safety note,
/// so it stays on the page rather than inside the calculator's info sheet.
class BlenderAnalyseNote extends StatelessWidget {
  const BlenderAnalyseNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.warning_amber,
              size: 20,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.gasCalculators_blender_analyseNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
