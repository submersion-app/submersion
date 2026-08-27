import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/wizard_surface_style.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Chooses which existing-data source to load from.
class ExistingChoiceStep extends ConsumerWidget {
  final SetupWizardMode mode;
  final VoidCallback onChosen;

  const ExistingChoiceStep({
    super.key,
    required this.mode,
    required this.onChosen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    // Keeps the autoDispose family instance alive while this step shows.
    ref.watch(setupWizardProvider(mode));

    void choose(ExistingDataSource source) {
      // Read at tap time: a build-time capture could outlive the notifier.
      ref.read(setupWizardProvider(mode).notifier).chooseSource(source);
      onChosen();
    }

    Widget card(
      IconData icon,
      String title,
      String subtitle,
      ExistingDataSource source,
    ) {
      return Card(
        elevation: 0,
        color: WizardSurfaceStyle.optionFill(theme),
        shape: WizardSurfaceStyle.optionShape(theme),
        child: ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => choose(source),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_existing_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_existing_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          card(
            Icons.restore,
            l10n.setup_existing_restore_title,
            l10n.setup_existing_restore_subtitle,
            ExistingDataSource.restoreBackup,
          ),
          card(
            Icons.cloud_sync,
            l10n.setup_existing_sync_title,
            l10n.setup_existing_sync_subtitle,
            ExistingDataSource.cloudSync,
          ),
          card(
            Icons.folder_open,
            l10n.setup_existing_folder_title,
            l10n.setup_existing_folder_subtitle,
            ExistingDataSource.openFolder,
          ),
        ],
      ),
    );
  }
}
