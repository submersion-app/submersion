import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/formatters/distribution_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A distribution's top three segments as labelled bars with their share.
class _SharesPanel extends StatelessWidget {
  final String title;
  final AsyncValue<List<DistributionSegment>> value;
  final String Function(DistributionSegment) label;

  /// A segment's own colour where it means something; null keeps the
  /// theme's primary colour.
  final Color? Function(DistributionSegment)? colorOf;

  const _SharesPanel({
    required this.title,
    required this.value,
    required this.label,
    this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = [...?value.value]..sort((a, b) => b.count.compareTo(a.count));
    final shown = top.take(3).toList();
    return HomePanel(
      title: title,
      semanticsValue: [
        for (final s in shown) '${label(s)} ${s.percentage.round()}%',
      ].join(', '),
      onTap: () => context.push('/insights'),
      fit: HomePanelFit.clip,
      child: HomePanelAsync<List<DistributionSegment>>(
        value: value,
        isEmpty: (s) => s.isEmpty,
        emptyText: l10n.dashboard_panel_noDives,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in shown)
              HomeBarRow(
                label: label(s),
                value: '${s.percentage.round()}%',
                fraction: s.percentage / 100,
                color: colorOf?.call(s),
              ),
          ],
        ),
      ),
    );
  }
}

/// Share of dives on air, nitrox and trimix. A dive breathing two mixes
/// counts under both, as in Insights.
class GasMixPanel extends ConsumerWidget {
  const GasMixPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SharesPanel(
    title: context.l10n.dashboard_panel_gasMix,
    value: ref.watch(homeGasMixProvider),
    // The query names each gas by an English key; the row and its colour
    // both look it up.
    label: (s) => switch (s.label) {
      'Air' => context.l10n.insights_focus_gas_air,
      'Nitrox' => context.l10n.insights_focus_gas_nitrox,
      'Trimix' => context.l10n.insights_focus_gas_trimix,
      final other => other,
    },
    colorOf: (s) => gasMixColor(s.label),
  );
}

/// A gas mix row's colour, as the dive profile draws that gas: the
/// distribution names each row Air, Nitrox or Trimix.
Color? gasMixColor(String gasType) => switch (gasType) {
  'Air' => GasColors.air,
  'Nitrox' => GasColors.nitrox,
  'Trimix' => GasColors.trimix,
  _ => null,
};

/// Share of dives by type, the top three.
class DiveTypesPanel extends ConsumerWidget {
  const DiveTypesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typesById = watchDiveTypesById(ref);
    return _SharesPanel(
      title: l10n.dashboard_panel_diveTypes,
      value: ref.watch(homeDiveTypesProvider),
      label: (s) => diveTypeDistributionLabel(
        s.key ?? s.label,
        l10n,
        typesById: typesById,
      ),
    );
  }
}
