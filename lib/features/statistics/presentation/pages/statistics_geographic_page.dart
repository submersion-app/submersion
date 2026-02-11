import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsGeographicPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsGeographicPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountriesSection(context, ref),
          const SizedBox(height: 16),
          _buildRegionsSection(context, ref),
          const SizedBox(height: 16),
          _buildTripsSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_geographic_appBar_title),
      ),
      body: content,
    );
  }

  Widget _buildCountriesSection(BuildContext context, WidgetRef ref) {
    final countriesAsync = ref.watch(countriesVisitedProvider);

    return StatSectionCard(
      title: context.l10n.statistics_geographic_countries_title,
      subtitle: context.l10n.statistics_geographic_countries_subtitle,
      child: countriesAsync.when(
        data: (data) {
          final summary = data.isNotEmpty
              ? context.l10n.statistics_geographic_countries_summary(
                  data.length,
                  data.first.name,
                  data.first.count,
                )
              : context.l10n.statistics_geographic_countries_empty;
          return Semantics(
            label: summary,
            child: RankingList(
              items: data,
              countLabel: context.l10n.statistics_ranking_countLabel_dives,
              maxItems: 10,
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_geographic_countries_error,
        ),
      ),
    );
  }

  Widget _buildRegionsSection(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(regionsExploredProvider);

    return StatSectionCard(
      title: context.l10n.statistics_geographic_regions_title,
      subtitle: context.l10n.statistics_geographic_regions_subtitle,
      child: regionsAsync.when(
        data: (data) {
          final summary = data.isNotEmpty
              ? context.l10n.statistics_geographic_regions_summary(
                  data.length,
                  data.first.name,
                  data.first.count,
                )
              : context.l10n.statistics_geographic_regions_empty;
          return Semantics(
            label: summary,
            child: RankingList(
              items: data,
              countLabel: context.l10n.statistics_ranking_countLabel_dives,
              maxItems: 10,
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_geographic_regions_error,
        ),
      ),
    );
  }

  Widget _buildTripsSection(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(divesPerTripProvider);

    return StatSectionCard(
      title: context.l10n.statistics_geographic_trips_title,
      subtitle: context.l10n.statistics_geographic_trips_subtitle,
      child: tripsAsync.when(
        data: (data) {
          final summary = data.isNotEmpty
              ? context.l10n.statistics_geographic_trips_summary(
                  data.length,
                  data.first.name,
                  data.first.count,
                )
              : context.l10n.statistics_geographic_trips_empty;
          return Semantics(
            label: summary,
            child: RankingList(
              items: data,
              countLabel: context.l10n.statistics_ranking_countLabel_dives,
              maxItems: 10,
              onItemTap: (item) => context.push('/trips/${item.id}'),
            ),
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_geographic_trips_error,
        ),
      ),
    );
  }
}
