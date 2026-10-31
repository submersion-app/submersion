import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/equipment/gear_report_row.dart';
import 'package:submersion/features/insights/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gear by dive count, under the Insights filter, which is what makes usage
/// by year or by trip work: the diver sets a date range or a trip.
class MostUsedGearSection extends ConsumerStatefulWidget {
  const MostUsedGearSection({super.key});

  @override
  ConsumerState<MostUsedGearSection> createState() =>
      _MostUsedGearSectionState();
}

class _MostUsedGearSectionState extends ConsumerState<MostUsedGearSection> {
  bool _expanded = false;

  /// The repository row with its hours on the end of the subtitle. A row
  /// with no recorded time says nothing about hours rather than "0 hours".
  RankingItem _withHours(AppLocalizations l10n, RankingItem item) {
    final hours = item.value?.round() ?? 0;
    if (hours <= 0) return item;
    final text = l10n.insights_equipment_mostUsedGear_hours(hours);
    return RankingItem(
      id: item.id,
      name: item.name,
      count: item.count,
      value: item.value,
      subtitle: item.subtitle == null ? text : '${item.subtitle} • $text',
      date: item.date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gearAsync = ref.watch(mostUsedGearProvider);

    return StatSectionCard(
      title: l10n.insights_equipment_mostUsedGear_title,
      subtitle: l10n.insights_equipment_mostUsedGear_subtitle,
      child: gearAsync.when(
        data: (data) => Column(
          children: [
            RankingList(
              items: [
                for (final item in showAllSlice(data, expanded: _expanded))
                  _withHours(l10n, item),
              ],
              countLabel: l10n.insights_ranking_countLabel_dives,
              onItemTap: (item) => context.push('/equipment/${item.id}'),
            ),
            GearReportShowAll(
              itemCount: data.length,
              expanded: _expanded,
              onChanged: (value) => setState(() => _expanded = value),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_equipment_mostUsedGear_error,
        ),
      ),
    );
  }
}
