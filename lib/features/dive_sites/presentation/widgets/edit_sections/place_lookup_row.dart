import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Looks up country, region, city and body of water from the site's
/// coordinates (issue #1187). It sits with the fields it fills rather than
/// with the coordinates, because the Location section rests collapsed
/// (issue #4084).
class PlaceLookupRow extends StatelessWidget {
  const PlaceLookupRow({
    super.key,
    required this.isBusy,
    required this.onLookup,
  });

  /// A lookup is running, or the position is still being read.
  final bool isBusy;

  /// Null while the coordinates do not parse, which disables the button and
  /// says where to add them.
  final VoidCallback? onLookup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: isBusy ? null : onLookup,
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore, size: 16),
            label: Text(l10n.diveSites_edit_gps_lookupFromCoordinates),
          ),
          if (onLookup == null && !isBusy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.diveSites_edit_gps_lookupNeedsCoordinates,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
