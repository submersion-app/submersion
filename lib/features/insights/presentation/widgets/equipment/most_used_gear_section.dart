import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
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

  /// The row's brand, its type in the viewer's language, and its hours. A row
  /// with no recorded time says nothing about hours rather than "0 hours".
  RankingItem _described(AppLocalizations l10n, RankingItem item) {
    final hours = item.value?.round() ?? 0;
    final subtitle = [
      ?item.subtitle,
      if (item.kind case final kind?)
        EquipmentType.values.asNameMap()[kind]?.localizedName(l10n) ?? kind,
      if (hours > 0) l10n.insights_equipment_mostUsedGear_hours(hours),
    ].join(' • ');
    return RankingItem(
      id: item.id,
      name: item.name,
      count: item.count,
      value: item.value,
      subtitle: subtitle.isEmpty ? null : subtitle,
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
                  _described(l10n, item),
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
