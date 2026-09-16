import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The profile a review row goes to (issue #1893), shown under the row's
/// subtitle when one import writes to several profiles.
class ImportTargetChip extends StatelessWidget {
  const ImportTargetChip({super.key, required this.target});

  final ImportTarget target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            target.isNew ? Icons.person_add_alt : Icons.person_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              target.isNew
                  ? context.l10n.universalImport_divers_newLabel(target.name)
                  : target.name,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
