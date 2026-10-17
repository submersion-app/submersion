import 'dart:async';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/ascent_rate_thresholds_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/ccr_ppo2_limit_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/gradient_factor_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/gtr_reserve_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/ppo2_limit_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';

/// Reference URLs for the CNS calculation methods, opened from the CNS method
/// picker dialog's "Sources" section.
const _cnsSourceNoaaUrl = 'https://www.omao.noaa.gov/noaa-diving-program';
const _cnsSourceShearwaterUrl =
    'https://shearwater.com/blogs/community/shearwater-and-the-cns-oxygen-clock';
const _cnsSourceTheoreticalDiverUrl =
    'https://thetheoreticaldiver.org/wordpress/index.php/2019/08/15/calculating-oxygen-cns-toxicity/';
const _cnsSourceSubsurfaceUrl =
    'https://github.com/subsurface/subsurface/commit/a0912b38bd';

/// The Decompression settings: gradient factors, oxygen toxicity,
/// data sources, narcosis, ICD warnings, ascent planning and rates.
class DecompressionSettingsContent extends ConsumerWidget {
  const DecompressionSettingsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_decompression_header_gradientFactors,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timeline),
              title: Text(context.l10n.settings_decompression_currentSettings),
              subtitle: Text(
                context.l10n.settings_decompression_gfValue(
                  settings.gfLow,
                  settings.gfHigh,
                ),
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _showGradientFactorPicker(context, ref, settings),
            ),
          ),
          const SizedBox(height: 16),
          buildSettingsInfoCard(
            context,
            context.l10n.settings_decompression_aboutTitle,
            context.l10n.settings_decompression_aboutContent,
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_decompression_header_oxygenToxicity,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.percent),
                  title: Text(
                    context.l10n.settings_decompression_cnsMethodTitle,
                  ),
                  subtitle: Text(
                    _cnsMethodLabel(context, settings.cnsCalculationMethod),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showCnsMethodPicker(context, ref, settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: Text(
                    context.l10n.settings_decompression_ppO2LimitsTitle,
                  ),
                  subtitle: Text(
                    context.l10n.settings_decompression_ppO2LimitsSubtitle(
                      formatRoundedForInput(settings.ppO2MaxWorking, 1),
                      formatRoundedForInput(settings.ppO2MaxDeco, 1),
                    ),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showPpO2LimitPicker(context, ref, settings),
                ),
                const Divider(height: 1),
                const CcrPpO2LimitTile(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_decompression_header_dataSources,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              context.l10n.settings_decompression_header_dataSources_subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildSourceDropdownTile(
                  context,
                  title: context.l10n.settings_decompression_ndlSource,
                  value: settings.defaultNdlSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultNdlSource(source),
                ),
                const Divider(height: 1),
                // No Ceiling Source tile: the ceiling line always renders the
                // exact calculated curve (issue #755). The Computer/Calculated
                // choice remains meaningful for the deco stop schedule below.
                _buildSourceDropdownTile(
                  context,
                  title: context.l10n.settings_decompression_decoStopSource,
                  value: settings.defaultDecoStopSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultDecoStopSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  title: context.l10n.settings_decompression_ttsSource,
                  value: settings.defaultTtsSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultTtsSource(source),
                ),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  title: context.l10n.settings_decompression_gtrSource,
                  value: settings.defaultGtrSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultGtrSource(source),
                ),
                const Divider(height: 1),
                _buildGtrReserveTile(context, ref, settings),
                const Divider(height: 1),
                _buildSourceDropdownTile(
                  context,
                  title: context.l10n.settings_decompression_cnsSource,
                  value: settings.defaultCnsSource,
                  onChanged: (source) => ref
                      .read(settingsProvider.notifier)
                      .setDefaultCnsSource(source),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_decompression_header_narcosis,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.air),
                  title: Text(context.l10n.settings_decompression_o2Narcotic),
                  subtitle: Text(
                    context.l10n.settings_decompression_o2Narcotic_subtitle,
                  ),
                  value: settings.o2Narcotic,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setO2Narcotic(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.vertical_align_bottom),
                  title: Text(context.l10n.settings_decompression_endLimit),
                  subtitle: Text(
                    context.l10n.settings_decompression_endLimit_subtitle,
                  ),
                  trailing: Text(
                    UnitFormatter(
                      settings,
                    ).formatDepth(settings.endLimit, decimals: 0),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _showEndLimitDialog(context, ref, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_decompression_header_icd,
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.compare_arrows),
              title: Text(context.l10n.settings_decompression_icdWarnings),
              subtitle: Text(
                context.l10n.settings_decompression_icdWarnings_subtitle,
              ),
              value: settings.icdWarningsEnabled,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setIcdWarningsEnabled(value);
              },
            ),
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_decompression_header_ascent,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              context.l10n.settings_decompression_header_ascent_subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_vert),
              title: LabelWithControl(
                label: Text(context.l10n.settings_decompression_ascentGasLabel),
                control: DropdownButton<AscentGasSet>(
                  value: settings.ascentGasSet,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: AscentGasSet.allCarried,
                      child: Text(
                        context
                            .l10n
                            .settings_decompression_ascentGas_allCarried,
                      ),
                    ),
                    DropdownMenuItem(
                      value: AscentGasSet.decoStageOnly,
                      child: Text(
                        context.l10n.settings_decompression_ascentGas_decoStage,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setAscentGasSet(value);
                    }
                  },
                ),
              ),
              dense: true,
            ),
          ),
          const SizedBox(height: 24),
          const AscentRateSection(),
        ],
      ),
    );
  }

  Widget _buildSourceDropdownTile(
    BuildContext context, {
    required String title,
    required MetricDataSource value,
    required ValueChanged<MetricDataSource> onChanged,
  }) {
    return ListTile(
      title: LabelWithControl(
        label: Text(title),
        control: DropdownButton<MetricDataSource>(
          value: value,
          underline: const SizedBox.shrink(),
          items: [
            DropdownMenuItem(
              value: MetricDataSource.calculated,
              child: Text(context.l10n.settings_decompression_sourceCalculated),
            ),
            DropdownMenuItem(
              value: MetricDataSource.computer,
              child: Text(context.l10n.settings_decompression_sourceComputer),
            ),
          ],
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
      dense: true,
    );
  }

  /// Reserve pressure the calculated GTR counts down to, shown and edited in
  /// the diver's pressure unit, stored in bar.
  Widget _buildGtrReserveTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final units = UnitFormatter(settings);
    return ListTile(
      dense: true,
      title: Text(context.l10n.settings_decompression_gtrReserve),
      subtitle: Text(context.l10n.settings_decompression_gtrReserve_subtitle),
      trailing: Text(units.formatPressure(settings.gtrReservePressure)),
      onTap: () => _showGtrReserveDialog(context, ref, settings),
    );
  }

  Future<void> _showGtrReserveDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final units = UnitFormatter(settings);
    final entered = await showDialog<double>(
      context: context,
      builder: (_) => GtrReserveDialog(
        initialValue: units.convertPressure(settings.gtrReservePressure),
        unitSymbol: units.pressureSymbol,
      ),
    );
    if (entered == null || !entered.isFinite || entered <= 0) return;
    await ref
        .read(settingsProvider.notifier)
        .setGtrReservePressure(units.pressureToBar(entered));
  }

  String _cnsMethodLabel(BuildContext context, CnsCalculationMethod method) {
    switch (method) {
      case CnsCalculationMethod.classic:
        return context.l10n.settings_decompression_cnsMethodClassic;
      case CnsCalculationMethod.shearwater:
        return context.l10n.settings_decompression_cnsMethodShearwater;
      case CnsCalculationMethod.subsurface:
        return context.l10n.settings_decompression_cnsMethodSubsurface;
    }
  }

  String _cnsMethodDescription(
    BuildContext context,
    CnsCalculationMethod method,
  ) {
    switch (method) {
      case CnsCalculationMethod.classic:
        return context.l10n.settings_decompression_cnsMethodClassicDesc;
      case CnsCalculationMethod.shearwater:
        return context.l10n.settings_decompression_cnsMethodShearwaterDesc;
      case CnsCalculationMethod.subsurface:
        return context.l10n.settings_decompression_cnsMethodSubsurfaceDesc;
    }
  }

  Widget _buildCnsSourceLink(BuildContext context, String label, String url) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => _launchCnsSource(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.open_in_new, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchCnsSource(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    var didLaunch = false;

    if (await canLaunchUrl(uri)) {
      try {
        didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        didLaunch = false;
      }
    }

    if (!didLaunch && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settings_linkOpenFailed)),
      );
    }
  }

  Widget _buildCnsMethodOption(
    BuildContext context,
    BuildContext dialogContext,
    WidgetRef ref,
    AppSettings settings,
    CnsCalculationMethod method,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = settings.cnsCalculationMethod == method;
    // Foregrounds must pair with the fill: on primaryContainer only
    // onPrimaryContainer is guaranteed to read (#2959).
    final labelColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final descriptionColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: _cnsMethodLabel(context, method),
        child: InkWell(
          onTap: () {
            ref.read(settingsProvider.notifier).setCnsCalculationMethod(method);
            Navigator.of(dialogContext).pop();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cnsMethodLabel(context, method),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      Text(
                        _cnsMethodDescription(context, method),
                        style: textTheme.bodySmall?.copyWith(
                          color: descriptionColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCnsMethodPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_decompression_cnsMethodTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final method in CnsCalculationMethod.values)
                _buildCnsMethodOption(
                  context,
                  dialogContext,
                  ref,
                  settings,
                  method,
                ),
              const SizedBox(height: 8),
              const Divider(),
              ExpansionTile(
                title: Text(
                  context.l10n.settings_decompression_cnsMethodAboutTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.settings_decompression_cnsMethodAboutBody,
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.settings_decompression_cnsMethodSourcesTitle,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildCnsSourceLink(
                    context,
                    context.l10n.settings_decompression_cnsMethodSourceNoaa,
                    _cnsSourceNoaaUrl,
                  ),
                  _buildCnsSourceLink(
                    context,
                    context
                        .l10n
                        .settings_decompression_cnsMethodSourceShearwater,
                    _cnsSourceShearwaterUrl,
                  ),
                  _buildCnsSourceLink(
                    context,
                    context
                        .l10n
                        .settings_decompression_cnsMethodSourceTheoreticalDiver,
                    _cnsSourceTheoreticalDiverUrl,
                  ),
                  _buildCnsSourceLink(
                    context,
                    context
                        .l10n
                        .settings_decompression_cnsMethodSourceSubsurface,
                    _cnsSourceSubsurfaceUrl,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.settings_decompression_cnsMethodDisclaimer,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_action_close),
          ),
        ],
      ),
    );
  }

  void _showGradientFactorPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => GradientFactorDialog(
        initialGfLow: settings.gfLow,
        initialGfHigh: settings.gfHigh,
        onSave: (low, high) {
          ref.read(settingsProvider.notifier).setGradientFactors(low, high);
        },
      ),
    );
  }

  void _showPpO2LimitPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => PpO2LimitDialog(
        initialWorking: settings.ppO2MaxWorking,
        initialMax: settings.ppO2MaxDeco,
        onSave: (working, max) {
          ref.read(settingsProvider.notifier).setPpO2Limits(working, max);
        },
      ),
    );
  }

  void _showEndLimitDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final units = UnitFormatter(settings);
    var currentValue = settings.endLimit;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.l10n.settings_decompression_endLimit_dialog_title,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                units.formatDepth(currentValue, decimals: 0),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Slider(
                value: currentValue,
                min: 20.0,
                max: 50.0,
                divisions: 30,
                label: units.formatDepth(currentValue, decimals: 0),
                onChanged: (value) {
                  setDialogState(() => currentValue = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setEndLimit(currentValue);
                Navigator.pop(dialogContext);
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings > Safety > Decompression as a page of its own.
///
/// On a phone it is pushed as `/settings/safety/decompression` and gets the
/// usual implied back arrow. In the desktop settings pane nothing is pushed,
/// so the pane passes [onBack] to return to the Safety hub.
class DecompressionSettingsPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DecompressionSettingsPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_decompression_title),
        leading: onBack == null ? null : BackButton(onPressed: onBack),
      ),
      body: const DecompressionSettingsContent(),
    );
  }
}
