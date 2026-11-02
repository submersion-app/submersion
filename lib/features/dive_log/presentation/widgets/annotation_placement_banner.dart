import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The strip above the profile while an annotation is being placed (#4109):
/// what to do, and a way out that adds nothing.
class AnnotationPlacementBanner extends StatelessWidget {
  const AnnotationPlacementBanner({
    super.key,
    required this.text,
    required this.onCancel,
  });

  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.push_pin, size: 18, color: colors.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: Text(context.l10n.diveLog_annotation_banner_cancel),
            ),
          ],
        ),
      ),
    );
  }
}
