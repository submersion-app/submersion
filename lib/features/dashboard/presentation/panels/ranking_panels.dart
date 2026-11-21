import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Up to three names with dive counts, each with a bar against the first.
Widget _ranking(List<(String, int)> rows) {
  final top = rows.isEmpty ? 1 : rows.first.$2;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (name, count) in rows.take(3))
        HomeBarRow(
          label: name,
          value: '$count',
          fraction: top == 0 ? 0 : count / top,
        ),
    ],
  );
}

/// The diver's three most-dived sites.
class TopSitesPanel extends ConsumerWidget {
  const TopSitesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(diveStatisticsProvider);
    final first = stats.value?.topSites.firstOrNull;
    return HomePanel(
      title: l10n.dashboard_panel_topSites,
      semanticsValue: first == null
          ? ''
          : '${first.siteName} ${first.diveCount}',
      onTap: () => context.push('/sites'),
      fit: HomePanelFit.clip,
      child: HomePanelAsync<DiveStatistics>(
        value: stats,
        isEmpty: (s) => s.topSites.isEmpty,
        emptyText: l10n.dashboard_panel_noDives,
        builder: (s) => _ranking([
          for (final site in s.topSites) (site.siteName, site.diveCount),
        ]),
      ),
    );
  }
}

/// The diver's three most frequent buddies.
class TopBuddiesPanel extends ConsumerWidget {
  const TopBuddiesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final buddies = ref.watch(homeTopBuddiesProvider);
    final first = buddies.value?.firstOrNull;
    return HomePanel(
      title: l10n.dashboard_panel_topBuddies,
      semanticsValue: first == null ? '' : '${first.name} ${first.count}',
      onTap: () => context.push('/buddies'),
      fit: HomePanelFit.clip,
      child: HomePanelAsync<List<RankingItem>>(
        value: buddies,
        isEmpty: (b) => b.isEmpty,
        emptyText: l10n.dashboard_panel_noBuddies,
        builder: (b) => _ranking([for (final r in b) (r.name, r.count)]),
      ),
    );
  }
}
