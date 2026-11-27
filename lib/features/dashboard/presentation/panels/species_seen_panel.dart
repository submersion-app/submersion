import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The species seen most over the diver's recent dives, with their total.
/// Shown only once the diver has logged a sighting.
class SpeciesSeenPanel extends ConsumerWidget {
  const SpeciesSeenPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final species = ref.watch(homeRecentSpeciesProvider).value ?? const [];
    if (species.isEmpty) return const SizedBox.shrink();
    final total = ref.watch(homeSpeciesCountProvider).value;
    final top = species.first.diveCount;
    return HomePanel(
      title: l10n.dashboard_panel_speciesSeen,
      trailing: total == null ? null : l10n.dashboard_panel_speciesTotal(total),
      semanticsValue: species.map((s) => s.name).join(', '),
      onTap: () => context.push('/species'),
      fit: HomePanelFit.clip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final SpeciesSighting s in species)
            HomeBarRow(
              label: s.name,
              value: l10n.dashboard_panel_onDives(s.diveCount),
              fraction: top == 0 ? 0 : s.diveCount / top,
            ),
        ],
      ),
    );
  }
}
