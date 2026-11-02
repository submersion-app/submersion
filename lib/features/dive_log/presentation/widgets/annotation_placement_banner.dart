import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The strip above the profile while an annotation is being placed (#4109):
/// what to do, and a way out that adds nothing. [moving] is for an existing
/// annotation's new spot.
class AnnotationPlacementBanner extends StatelessWidget {
  const AnnotationPlacementBanner({
    super.key,
    required this.moving,
    required this.onCancel,
  });

  final bool moving;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
                moving
                    ? l10n.diveLog_annotation_banner_move
                    : l10n.diveLog_annotation_banner_place,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: Text(l10n.diveLog_annotation_banner_cancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pin that starts placing an annotation (#4109), lit while the chart is
/// in placement mode. Shared by the Dive Profile card and the fullscreen
/// profile.
class AnnotationPinButton extends StatelessWidget {
  const AnnotationPinButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(active ? Icons.push_pin : Icons.push_pin_outlined),
      tooltip: context.l10n.diveLog_annotation_add,
      visualDensity: VisualDensity.compact,
      isSelected: active,
      style: IconButton.styleFrom(
        backgroundColor: active ? colors.secondaryContainer : null,
        foregroundColor: active ? colors.onSecondaryContainer : null,
      ),
      onPressed: onPressed,
    );
  }
}
