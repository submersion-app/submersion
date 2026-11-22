import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest dive's depth profile as a static chart, with its site and
/// numbers above. One tap opens the dive and its full, interactive chart.
class LatestProfilePanel extends ConsumerWidget {
  const LatestProfilePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final latest = ref.watch(homeLatestProfileProvider);
    final dive = latest.value?.dive;
    final runtime = dive?.measuredRuntime;
    final summary = dive == null
        ? null
        // Numbers first: a long site name elides, never the numbers. A
        // dive with no site or name adds no empty part and no stray dot.
        : [
            units.formatDepth(dive.maxDepth),
            if (runtime != null) "${runtime.inMinutes}'",
            if (dive.waterTemp != null) units.formatTemperature(dive.waterTemp),
            dive.site?.name ?? dive.name ?? '',
          ].where((part) => part.isNotEmpty).join(' · ');
    return HomePanel(
      title: l10n.dashboard_panel_latestProfile,
      trailing: summary,
      semanticsValue: summary ?? '',
      onTap: dive == null ? null : () => context.push('/dives/${dive.id}'),
      child: HomePanelAsync(
        value: latest,
        isEmpty: (v) => v == null || v.points.length < 2,
        emptyText: l10n.dashboard_recentDives_noProfileData,
        // Against the sample times: a profile whose samples are unevenly
        // spaced keeps its true shape.
        builder: (v) => HomeSparkline(
          [for (final p in v!.points) p.$2],
          xs: [for (final p in v.points) p.$1],
          invert: true,
          fill: true,
        ),
      ),
    );
  }
}
