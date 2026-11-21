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
      // Said only once loaded: a total of 0 while loading would be untrue.
      semanticsValue: months.hasValue ? '$total' : '',
      onTap: () => context.push('/insights'),
      child: HomePanelAsync<List<MonthCount>>(
        value: months,
        isEmpty: (m) => m.every((c) => c.count == 0),
        emptyText: l10n.dashboard_panel_noDives,
        builder: (m) => HomeBars(
          [for (final c in m) c.count.toDouble()],
          // The narrow standalone month (CLDR's one-letter form): the first
          // character of the short name is the same for several months in
          // some languages (1月, 10月, 11月 and 12月 in Chinese).
          labels: [
            for (final c in m)
              DateFormat('LLLLL', locale).format(DateTime(c.year, c.month)),
          ],
        ),
      ),
    );
  }
}
