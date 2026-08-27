import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet that lets the user choose which computer's profile to use
/// as the starting point when opening the profile editor on a multi-computer
/// dive.
class ComputerSourceSelectionSheet extends StatelessWidget {
  final List<DiveDataSource> readings;

  const ComputerSourceSelectionSheet({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_computerSheet_title,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.diveLog_computerSheet_description,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...readings.map(
              (reading) => ListTile(
                leading: Icon(
                  Icons.computer,
                  color: reading.isPrimary
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  resolveSourceName(
                    reading,
                    SourceNameLabels(
                      unknownComputer:
                          context.l10n.diveLog_sources_unknownComputer,
                      manualEntry: context.l10n.diveLog_sources_manualEntry,
                      importedFile: context.l10n.diveLog_sources_importedFile,
                      editedSuffix: context.l10n.diveLog_sources_editedSuffix,
                    ),
                  ),
                ),
                subtitle: reading.isPrimary
                    ? Text(
                        context.l10n.diveLog_computerSource_badge_primary,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(reading),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
