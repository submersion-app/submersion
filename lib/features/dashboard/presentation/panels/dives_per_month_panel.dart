import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A bar per month for the last twelve months, empty months included.
class DivesPerMonthPanel extends ConsumerWidget {
  const DivesPerMonthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final months = ref.watch(homeMonthlyDivesProvider);
    final total = (months.value ?? const <MonthCount>[]).fold(
      0,
      (a, m) => a + m.count,
    );
    return HomePanel(
      title: l10n.dashboard_panel_divesPerMonth,
      semanticsValue: '$total',
      onTap: () => context.push('/insights'),
      child: HomePanelAsync<List<MonthCount>>(
        value: months,
        isEmpty: (m) => m.every((c) => c.count == 0),
        emptyText: l10n.dashboard_panel_noDives,
        builder: (m) => HomeBars(
          [for (final c in m) c.count.toDouble()],
          labels: [
            for (final c in m)
              DateFormat.MMM(
                locale,
              ).format(DateTime(c.year, c.month)).characters.first,
          ],
        ),
      ),
    );
  }
}
