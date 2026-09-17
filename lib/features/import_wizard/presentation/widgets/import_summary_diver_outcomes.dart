import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Summary step's "By profile" section (issue #1893): what one import
/// wrote to each diver profile, and how to see the ones that are not
/// active. Carries the error when a later profile's import failed, so what
/// did land stays visible.
class ImportSummaryDiverOutcomes extends StatelessWidget {
  const ImportSummaryDiverOutcomes({
    super.key,
    required this.outcomes,
    this.errorMessage,
  });

  final List<DiverImportOutcome> outcomes;
  final String? errorMessage;

  /// Whether [outcomes] tell the user more than the counts above: dives
  /// went to two or more profiles, or to one the app is not showing.
  static bool isWorthShowing(List<DiverImportOutcome> outcomes) =>
      outcomes.length > 1 || outcomes.any((o) => !o.isActive);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      key: const Key('import_summary_by_profile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errorMessage case final message?) ...[
          Container(
            key: const Key('import_summary_partial_error'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isWorthShowing(outcomes)) ...[
          Text(
            l10n.universalImport_summary_byProfileTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final outcome in outcomes)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                outcome.isNew ? Icons.person_add_alt : Icons.person_outline,
              ),
              title: Text(outcome.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (outcome.isNew)
                    Text(l10n.universalImport_summary_newProfile, style: muted),
                  Text(
                    l10n.universalImport_summary_fileImported(
                      outcome.diveIds.length,
                    ),
                    style: muted,
                  ),
                  if (!outcome.isActive)
                    Text(
                      l10n.universalImport_summary_switchToSee(outcome.name),
                      style: muted,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
