import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The trip a reviewed dive will be saved in (issue #3022): the Trips icon
/// and the trip's name, under the row's subtitle. Read-only; the diver
/// changes the trip on the dive after the import.
class ImportTripLine extends StatelessWidget {
  const ImportTripLine({super.key, required this.tripName});

  final String tripName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: context.l10n.universalImport_review_tripLabel(tripName),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_outlined, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tripName,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
