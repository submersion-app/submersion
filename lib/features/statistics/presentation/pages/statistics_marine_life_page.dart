import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsMarineLifePage extends ConsumerWidget {
  final bool embedded;

  const StatisticsMarineLifePage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(context, ref),
          const SizedBox(height: 16),
          _buildSeeAllSpeciesCard(context),
          const SizedBox(height: 16),
          _buildMostCommonSection(context, ref),
          const SizedBox(height: 16),
          _buildBestSitesSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_marineLife_appBar_title),
      ),
      body: content,
    );
  }

  Widget _buildOverviewSection(BuildContext context, WidgetRef ref) {
    final speciesCountAsync = ref.watch(uniqueSpeciesCountProvider);

    return speciesCountAsync.when(
      data: (count) => Semantics(
        label: statLabel(
          name: context.l10n.statistics_marineLife_speciesSpotted,
          value: count.toString(),
        ),
        child: Row(
          children: [
            Expanded(
              child: StatValueCard(
                icon: MdiIcons.fish,
                label: context.l10n.statistics_marineLife_speciesSpotted,
                value: count.toString(),
                iconColor: Colors.teal,
              ),
            ),
          ],
        ),
      ),
      loading: () => const Card(
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// Entry point to the Species page. Carries no count on purpose: the card
  /// above it is scoped by the Statistics filter and the Species page is
  /// not, so two different numbers side by side would read as a bug.
  Widget _buildSeeAllSpeciesCard(BuildContext context) {
    return Card(
      child: ListTile(
        key: const ValueKey('see_all_species'),
        leading: const Icon(MdiIcons.fish, color: Colors.teal),
        title: Text(context.l10n.statistics_marineLife_seeAllSpecies_title),
        subtitle: Text(
          context.l10n.statistics_marineLife_seeAllSpecies_subtitle,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/species'),
      ),
    );
  }

  Widget _buildMostCommonSection(BuildContext context, WidgetRef ref) {
    final sightingsAsync = ref.watch(mostCommonSightingsProvider);

    return StatSectionCard(
      title: context.l10n.statistics_marineLife_mostCommon_title,
      subtitle: context.l10n.statistics_marineLife_mostCommon_subtitle,
      child: sightingsAsync.when(
        data: (rawData) {
          final data = rawData
              .map((item) => _localized(item, context.l10n))
              .toList();
          final summary = data.isNotEmpty
              ? context.l10n.statistics_marineLife_mostCommon_summary(
                  data.length,
                  data.first.name,
                  data.first.count,
                )
              : context.l10n.statistics_marineLife_mostCommon_empty;
          return Semantics(
            label: summary,
            child: RankingList(
              items: data,
              countLabel: context.l10n.statistics_ranking_countLabel_sightings,
              maxItems: 10,
              onItemTap: (item) => context.push('/species/${item.id}'),
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_marineLife_mostCommon_error,
        ),
      ),
    );
  }

  Widget _buildBestSitesSection(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(bestSitesForMarineLifeProvider);

    return StatSectionCard(
      title: context.l10n.statistics_marineLife_bestSites_title,
      subtitle: context.l10n.statistics_marineLife_bestSites_subtitle,
      child: sitesAsync.when(
        data: (data) {
          final summary = data.isNotEmpty
              ? context.l10n.statistics_marineLife_bestSites_summary(
                  data.length,
                  data.first.name,
                  data.first.count,
                )
              : context.l10n.statistics_marineLife_bestSites_empty;
          return Semantics(
            label: summary,
            child: RankingList(
              items: data,
              countLabel: context.l10n.statistics_ranking_countLabel_species,
              maxItems: 10,
              onItemTap: (item) => context.push('/sites/${item.id}'),
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_marineLife_bestSites_error,
        ),
      ),
    );
  }

  /// The query returns the stored English `common_name`; every other species
  /// surface renders the localized name, so this tab must too.
  RankingItem _localized(RankingItem item, AppLocalizations l10n) {
    return RankingItem(
      id: item.id,
      name: localizedSpeciesName(l10n, item.id, item.name),
      count: item.count,
      value: item.value,
      subtitle: item.subtitle,
      date: item.date,
    );
  }
}
