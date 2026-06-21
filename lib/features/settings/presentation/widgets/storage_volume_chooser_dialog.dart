import 'package:flutter/material.dart';

import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the user pick which app-specific external volume (internal storage or
/// SD card) holds the database. Pops with the chosen [ExternalVolumeOption], or
/// null if dismissed.
class StorageVolumeChooserDialog extends StatelessWidget {
  const StorageVolumeChooserDialog({super.key, required this.options});

  final List<ExternalVolumeOption> options;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(context.l10n.db_location_choose_volume),
      children: [
        for (final option in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option),
            child: Text(
              option.isInternal
                  ? context.l10n.db_location_internal
                  : context.l10n.db_location_sd_card,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(
            context.l10n.db_location_external_note,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
