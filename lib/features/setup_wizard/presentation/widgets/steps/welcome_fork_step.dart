import 'package:flutter/material.dart';

import 'package:submersion/features/setup_wizard/presentation/widgets/wizard_surface_style.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// First-run fork: start fresh, bring existing data, or skip setup.
class WelcomeForkStep extends StatelessWidget {
  final VoidCallback onStartFresh;
  final VoidCallback onExistingData;
  final VoidCallback onSkipSetup;

  const WelcomeForkStep({
    super.key,
    required this.onStartFresh,
    required this.onExistingData,
    required this.onSkipSetup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 96,
                  height: 96,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.setup_welcome_title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_welcome_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _ForkCard(
            icon: Icons.add_circle_outline,
            title: l10n.setup_welcome_startFresh_title,
            subtitle: l10n.setup_welcome_startFresh_subtitle,
            onTap: onStartFresh,
          ),
          const SizedBox(height: 12),
          _ForkCard(
            icon: Icons.cloud_download_outlined,
            title: l10n.setup_welcome_existingData_title,
            subtitle: l10n.setup_welcome_existingData_subtitle,
            onTap: onExistingData,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onSkipSetup,
            child: Text(l10n.setup_welcome_skipSetup),
          ),
        ],
      ),
    );
  }
}

class _ForkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ForkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: WizardSurfaceStyle.optionFill(theme),
      shape: WizardSurfaceStyle.optionShape(theme),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
