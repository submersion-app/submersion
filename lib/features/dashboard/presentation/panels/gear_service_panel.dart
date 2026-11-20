import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/equipment_service_navigation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The gear nearest its service: a bar per item showing how far through
/// its interval it is, with the time or dives left. Overdue comes first.
class GearServicePanel extends ConsumerWidget {
  const GearServicePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bars = ref.watch(homeGearServiceProvider);
    final list = bars.value ?? const <GearServiceBar>[];
    final max = homeWidthTierOf(context) == HomeWidthTier.phone ? 3 : 5;
    final anyOverdue = list.any(
      (b) => b.status.severity == ServiceClockSeverity.overdue,
    );
    return HomePanel(
      title: l10n.dashboard_panel_gearService,
      semanticsValue: list.isEmpty
          ? l10n.dashboard_panel_noGear
          : '${list.first.itemName} ${gearRemainingText(l10n, list.first.status)}',
      onTap: bars.hasValue && list.isEmpty
          ? () => context.push('/equipment/new')
          : () => openEquipmentWithServiceDue(
              context,
              ref,
              anyOverdue ? ServiceDueFilter.overdue : ServiceDueFilter.dueSoon,
            ),
      fit: HomePanelFit.clip,
      child: HomePanelAsync<List<GearServiceBar>>(
        value: bars,
        isEmpty: (b) => b.isEmpty,
        emptyText: l10n.dashboard_panel_noGear,
        builder: (b) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final bar in b.take(max))
              HomeBarRow(
                label: bar.itemName,
                value: gearRemainingText(l10n, bar.status),
                fraction: bar.fraction,
                tone: switch (bar.status.severity) {
                  ServiceClockSeverity.overdue => HomeBarTone.alert,
                  ServiceClockSeverity.dueSoon => HomeBarTone.warn,
                  _ => HomeBarTone.ok,
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// What is left on a service clock, in the measure that runs out first:
/// days to the due date, else dives, else hours.
String gearRemainingText(AppLocalizations l10n, ServiceClockStatus s) {
  if (s.severity == ServiceClockSeverity.overdue) {
    return l10n.dashboard_panel_overdue;
  }
  final days = s.daysUntilDue;
  if (days != null) return l10n.dashboard_panel_daysLeft(days);
  final dives = s.divesRemaining;
  if (dives != null) return l10n.dashboard_panel_divesLeft(dives);
  final hours = s.hoursRemaining;
  if (hours != null) return l10n.dashboard_panel_hoursLeft(hours.round());
  return '';
}
