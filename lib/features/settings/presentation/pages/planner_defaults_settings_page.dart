import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/planner_contingency_defaults_section.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_dpv_team_defaults_section.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_gas_defaults_section.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_rates_defaults_section.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Global defaults for the dive planner's Setup accordion (issue #3552,
/// follow-up to v304-307): Rates, Gas, Contingency, and DPV Team values a
/// new plan starts from unless overridden per plan.
///
/// Its own page under Settings > Safety rather than living on the
/// Decompression page these sections were first added to: Contingency and
/// DPV Team policy are not decompression settings, and Rates/Gas only
/// partly are, so folding all of them into "Decompression" stretched that
/// page's own scope past what the name promises.
class PlannerDefaultsSettingsContent extends StatelessWidget {
  const PlannerDefaultsSettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    Widget subtitle(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            l10n.settings_decompression_header_plannerRates,
          ),
          const SizedBox(height: 4),
          subtitle(l10n.settings_decompression_header_plannerRates_subtitle),
          const SizedBox(height: 8),
          const PlannerRatesDefaultsSection(),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            l10n.settings_decompression_header_plannerGas,
          ),
          const SizedBox(height: 4),
          subtitle(l10n.settings_decompression_header_plannerGas_subtitle),
          const SizedBox(height: 8),
          const PlannerGasDefaultsSection(),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            l10n.settings_decompression_header_plannerContingency,
          ),
          const SizedBox(height: 4),
          subtitle(
            l10n.settings_decompression_header_plannerContingency_subtitle,
          ),
          const SizedBox(height: 8),
          const PlannerContingencyDefaultsSection(),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            l10n.settings_decompression_header_plannerDpvTeam,
          ),
          const SizedBox(height: 4),
          subtitle(l10n.settings_decompression_header_plannerDpvTeam_subtitle),
          const SizedBox(height: 8),
          const PlannerDpvTeamDefaultsSection(),
        ],
      ),
    );
  }
}

/// On a phone it is pushed as `/settings/safety/planner-defaults` and gets
/// the usual implied back arrow. In the desktop settings pane nothing is
/// pushed, so the pane passes [onBack] to return to the Safety hub.
class PlannerDefaultsSettingsPage extends StatelessWidget {
  final VoidCallback? onBack;

  const PlannerDefaultsSettingsPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_plannerDefaults_title),
        leading: onBack == null ? null : BackButton(onPressed: onBack),
      ),
      body: const PlannerDefaultsSettingsContent(),
    );
  }
}
