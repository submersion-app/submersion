import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A cell per day for the last twelve months (six on a phone, where a
/// year of cells is too small to read), shaded by dives that day.
class ActivityCalendarPanel extends ConsumerWidget {
  const ActivityCalendarPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final phone = homeWidthTierOf(context) == HomeWidthTier.phone;
    final months = phone ? 6 : 12;
    final now = clock.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = homeWindowStart(now, months: months);
    final days = ref.watch(homeActivityDaysProvider);
    final shown = {
      for (final e in (days.value ?? const <DateTime, int>{}).entries)
        if (!e.key.isBefore(from)) e.key: e.value,
    };
    final dives = shown.values.fold(0, (a, b) => a + b);
    final summary = l10n.dashboard_panel_activitySummary(dives, shown.length);
    return HomePanel(
      title: l10n.dashboard_panel_activity(months),
      trailing: days.hasValue ? summary : null,
      // Said only once loaded: "0 dives" while loading would be untrue.
      semanticsValue: days.hasValue ? summary : '',
      onTap: () => context.push('/dives'),
      child: HomePanelAsync<Map<DateTime, int>>(
        value: days,
        isEmpty: (_) => false,
        emptyText: '',
        builder: (_) => HomeDayGrid(counts: shown, from: from, to: to),
      ),
    );
  }
}
