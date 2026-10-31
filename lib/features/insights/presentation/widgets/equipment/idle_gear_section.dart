import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/reports/idle_gear.dart';
import 'package:submersion/features/insights/presentation/providers/equipment_report_insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/equipment/gear_report_row.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gear the diver owns and has not dived lately, across all dives.
class IdleGearSection extends ConsumerStatefulWidget {
  const IdleGearSection({super.key});

  @override
  ConsumerState<IdleGearSection> createState() => _IdleGearSectionState();
}

class _IdleGearSectionState extends ConsumerState<IdleGearSection> {
  bool _expanded = false;

  String _periodLabel(AppLocalizations l10n, IdlePeriod period) =>
      switch (period) {
        IdlePeriod.sixMonths => l10n.insights_equipment_idle_over6Months,
        IdlePeriod.oneYear => l10n.insights_equipment_idle_over1Year,
        IdlePeriod.twoYears => l10n.insights_equipment_idle_over2Years,
      };

  String _sinceText(AppLocalizations l10n, IdleRow row) {
    final since = row.since;
    if (since == null) return l10n.insights_equipment_idle_neverDived;
    return [
      if (since.years > 0) l10n.insights_equipment_idle_years(since.years),
      if (since.months > 0) l10n.insights_equipment_idle_months(since.months),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = ref.watch(idlePeriodProvider);
    final idleAsync = ref.watch(idleGearProvider);

    return StatSectionCard(
      title: l10n.insights_equipment_idle_title,
      subtitle: l10n.insights_equipment_idle_subtitle,
      trailing: DropdownButton<IdlePeriod>(
        key: const ValueKey('idle-period'),
        value: period,
        underline: const SizedBox.shrink(),
        items: [
          for (final p in IdlePeriod.values)
            DropdownMenuItem(value: p, child: Text(_periodLabel(l10n, p))),
        ],
        onChanged: (p) {
          if (p != null) ref.read(idlePeriodProvider.notifier).state = p;
        },
      ),
      child: idleAsync.when(
        data: (rows) => rows.isEmpty
            ? StatEmptyState(
                icon: Icons.check_circle_outline,
                message: l10n.insights_equipment_idle_empty,
              )
            : Column(
                children: [
                  for (final row in showAllSlice(rows, expanded: _expanded))
                    GearReportRow(
                      title: row.item.name,
                      trailing: _sinceText(l10n, row),
                      onTap: () => context.push('/equipment/${row.item.id}'),
                    ),
                  GearReportShowAll(
                    itemCount: rows.length,
                    expanded: _expanded,
                    onChanged: (value) => setState(() => _expanded = value),
                  ),
                ],
              ),
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        // A failed load is not a locker with nothing idle.
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_equipment_idle_error,
        ),
      ),
    );
  }
}
