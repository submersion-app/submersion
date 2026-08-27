import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/setup_wizard/data/setup_apply_service.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Feature-discovery destinations offered on the finish screen, in display
/// order. Public so a router test can assert each one resolves to a real
/// route (a bad link 404s to the "Page Not Found" screen).
const kSetupFinishFeatureRoutes = <String>[
  '/dive-computers/discover', // dive computer download
  '/transfer', // file import
  '/statistics', // statistics
  '/sites', // dive sites map
  '/equipment', // gear / service tracking
];

/// Final step: feature discovery plus the apply-and-go action.
class FinishStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  const FinishStep({super.key, required this.mode});

  @override
  ConsumerState<FinishStep> createState() => _FinishStepState();
}

class _FinishStepState extends ConsumerState<FinishStep> {
  bool _applying = false;

  Future<void> _complete({String route = '/dashboard'}) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final draft = ref.read(setupWizardProvider(widget.mode));
      final service = ref.read(setupApplyServiceProvider);
      if (widget.mode == SetupWizardMode.firstRun) {
        await service.applyFirstRun(draft);
      } else {
        await service.applySettingsMode(draft);
      }
      if (!mounted) return;
      if (widget.mode == SetupWizardMode.firstRun || route != '/dashboard') {
        context.go(route);
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setup_finish_error(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final features = <(IconData, String, String)>[
      (
        Icons.watch,
        l10n.setup_finish_feature_diveComputer,
        kSetupFinishFeatureRoutes[0],
      ),
      (
        Icons.file_upload,
        l10n.setup_finish_feature_import,
        kSetupFinishFeatureRoutes[1],
      ),
      (
        Icons.query_stats,
        l10n.setup_finish_feature_statistics,
        kSetupFinishFeatureRoutes[2],
      ),
      (
        Icons.map,
        l10n.setup_finish_feature_sites,
        kSetupFinishFeatureRoutes[3],
      ),
      (
        Icons.build,
        l10n.setup_finish_feature_gear,
        kSetupFinishFeatureRoutes[4],
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            l10n.setup_finish_title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_finish_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          for (final (icon, label, route) in features)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: theme.colorScheme.primary),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: _applying ? null : () => _complete(route: route),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _applying ? null : _complete,
            icon: _applying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(
              _applying ? l10n.setup_finish_applying : l10n.setup_finish_start,
            ),
          ),
        ],
      ),
    );
  }
}
