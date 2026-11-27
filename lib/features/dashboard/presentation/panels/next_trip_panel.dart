import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The next trip: its name, dates, countdown and checklist progress. Shown
/// only when a trip is coming up; the page leaves it out otherwise.
class NextTripPanel extends ConsumerWidget {
  const NextTripPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(dashboardGaugesProvider).value?.nextTrip;
    if (trip == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final checklist = ref.watch(homeTripChecklistProvider).value;
    final mine = checklist != null && checklist.trip.id == trip.id
        ? checklist
        : null;
    final countdown = l10n.dashboard_panel_inDays(trip.daysUntilStart);
    return HomePanel(
      title: l10n.dashboard_key_nextTrip,
      trailing: countdown,
      semanticsValue: '${trip.name}, $countdown',
      onTap: () => context.push('/trips/${trip.id}'),
      fit: HomePanelFit.clip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trip.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${units.formatDate(trip.startDate)} - ${units.formatDate(trip.endDate)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (mine != null && mine.total > 0) ...[
            const SizedBox(height: 8),
            HomeBarRow(
              label: l10n.dashboard_panel_tripChecklist,
              value: '${mine.done} / ${mine.total}',
              fraction: mine.done / mine.total,
            ),
          ],
        ],
      ),
    );
  }
}
