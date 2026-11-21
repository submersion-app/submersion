import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest dives as a table: site, date, depth and runtime, with the
/// date dropped on a phone. Each row opens its dive.
class RecentDivesPanel extends ConsumerWidget {
  const RecentDivesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final dives = ref.watch(recentDivesProvider);
    final phone = homeWidthTierOf(context) == HomeWidthTier.phone;
    final muted = theme.colorScheme.onSurfaceVariant;
    final head = theme.textTheme.labelSmall?.copyWith(
      color: muted,
      fontSize: 9,
      letterSpacing: 0.8,
    );
    final cell = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget row(List<String> values, TextStyle? style, {VoidCallback? onTap}) {
      final children = <Widget>[
        Expanded(
          flex: 3,
          child: Text(
            values[0],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        for (final v in values.skip(1))
          Expanded(
            flex: 2,
            child: Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
      ];
      final line = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: children),
      );
      return onTap == null ? line : InkWell(onTap: onTap, child: line);
    }

    List<String> cells(Dive d) {
      final runtime = d.measuredRuntime;
      return [
        d.site?.name ?? d.name ?? '',
        if (!phone) units.formatDate(d.effectiveEntryTime),
        units.formatDepth(d.maxDepth),
        runtime == null ? '--' : "${runtime.inMinutes}'",
      ];
    }

    return HomePanel(
      title: l10n.dashboard_panel_recentDives,
      semanticsValue: [
        for (final d in dives.value ?? const <Dive>[])
          if ((d.site?.name ?? d.name ?? '').isNotEmpty)
            d.site?.name ?? d.name ?? '',
      ].join(', '),
      onTap: () => context.push('/dives'),
      fit: HomePanelFit.clip,
      child: HomePanelAsync<List<Dive>>(
        value: dives,
        isEmpty: (d) => d.isEmpty,
        emptyText: l10n.dashboard_recentDives_empty,
        builder: (list) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row([
              l10n.dashboard_panel_colSite.toUpperCase(),
              if (!phone) l10n.dashboard_panel_colDate.toUpperCase(),
              l10n.dashboard_panel_colDepth.toUpperCase(),
              l10n.dashboard_panel_colTime.toUpperCase(),
            ], head),
            for (final d in list) ...[
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              // One button per dive, read as "Dive 412 at Salt Pier" as the
              // dive list and buddy pages read their rows.
              Semantics(
                container: true,
                button: true,
                excludeSemantics: true,
                label: switch (d.diveNumber) {
                  final number? => l10n.diveLog_listPage_semanticsDiveAtSite(
                    number,
                    d.site?.name ?? d.name ?? '',
                  ),
                  null => d.site?.name ?? d.name ?? '',
                },
                onTap: () => context.push('/dives/${d.id}'),
                child: row(
                  cells(d),
                  cell,
                  onTap: () => context.push('/dives/${d.id}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
