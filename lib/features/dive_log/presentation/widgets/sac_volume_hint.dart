import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Explains why SAC is shown per pressure unit when the diver asked for
/// volume per minute: no cylinder on the dive has a volume (issue #386).
///
/// Dive-computer downloads carry transmitter pressure but not cylinder size,
/// so without this note the L/min preference looked broken on every imported
/// dive. Tapping the hint (when [onTap] is given) opens the dive editor, where
/// the cylinder volume lives.
class SacVolumeHint extends StatelessWidget {
  const SacVolumeHint({super.key, required this.volumeSymbol, this.onTap});

  /// The diver's volume unit symbol (e.g. "L" or "cuft").
  final String volumeSymbol;

  /// Opens the place the volume can be entered; null renders a plain note.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.diveLog_detail_sacVolumeHint(volumeSymbol),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.edit_outlined, size: 16, color: muted),
            ],
          ],
        ),
      ),
    );
  }
}
