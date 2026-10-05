import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The standout facts of the map in view, as a scrolling row of tiles over
/// the canvas. A tile selects what it names; the Groups tile colours the map
/// by group instead.
class InsightStrip extends ConsumerWidget {
  const InsightStrip({
    super.key,
    required this.graph,
    required this.tiles,
    required this.onSelect,
    required this.onGroups,
  });

  final ConnectionGraph graph;
  final List<InsightTile> tiles;
  final ValueChanged<GraphSelection> onSelect;
  final VoidCallback onGroups;

  /// The strip's height at the default text size.
  static const double height = 76;

  /// The strip's height at the reader's text size; canvas overlays and the
  /// camera fit start below this.
  static double heightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(height).clamp(height, height * 3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);
    // Sized to its tiles, so the band beside them stays the canvas's own
    // (a full-width list would swallow pans and taps there).
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        height: heightOf(context),
        child: ListView.separated(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: tiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final t = tiles[i];
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Card(
                key: ValueKey('insight-${t.kind.name}'),
                margin: const EdgeInsets.symmetric(vertical: 2),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    final target = t.target;
                    if (t.kind == InsightKind.groups) {
                      onGroups();
                    } else if (target != null) {
                      onSelect(target);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icon(t.kind),
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _title(l10n, t.kind),
                                style: theme.textTheme.labelSmall,
                              ),
                              Text(
                                _value(l10n, units, t),
                                // Two lines, so long names wrap rather than
                                // cut the count or date off the end.
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static IconData _icon(InsightKind k) => switch (k) {
    InsightKind.mostConnected => Icons.hub_outlined,
    InsightKind.strongestPair => Icons.link,
    InsightKind.closest => Icons.near_me_outlined,
    InsightKind.newest => Icons.fiber_new_outlined,
    InsightKind.driftingApart => Icons.trending_down,
    InsightKind.groups => Icons.workspaces_outlined,
  };

  static String _title(AppLocalizations l10n, InsightKind k) => switch (k) {
    InsightKind.mostConnected => l10n.connections_summary_mostConnected,
    InsightKind.strongestPair => l10n.connections_summary_strongestPair,
    InsightKind.closest => l10n.connections_summary_closest,
    InsightKind.newest => l10n.connections_insight_newest,
    InsightKind.driftingApart => l10n.connections_insight_drifting,
    InsightKind.groups => l10n.connections_insight_groups,
  };

  String _name(NodeRef ref) => graph.nodeFor(ref)?.label ?? ref.id;

  String _pair(AppLocalizations l10n, ConnectionEdge e) =>
      l10n.connections_insight_pair(_name(e.source), _name(e.target));

  /// The tile's second line. A tile with a [InsightTile.node] (most
  /// connected, or a centre edge in Around mode) names that entity; the
  /// other edge tiles name both ends.
  String _value(AppLocalizations l10n, UnitFormatter units, InsightTile t) {
    final e = t.edge;
    final who = t.node?.label ?? (e == null ? '' : _pair(l10n, e));
    return switch (t.kind) {
      InsightKind.mostConnected => who,
      InsightKind.strongestPair => l10n.connections_summary_pairValue(
        e!.weight,
        _name(e.source),
        _name(e.target),
      ),
      InsightKind.closest => l10n.connections_insight_closestValue(
        who,
        l10n.connections_selection_divesTogether(e!.weight),
      ),
      InsightKind.newest => l10n.connections_insight_since(
        who,
        units.formatMonthYear(e!.firstDiveAt),
      ),
      InsightKind.driftingApart => l10n.connections_insight_last(
        who,
        units.formatMonthYear(e!.lastDiveAt),
      ),
      InsightKind.groups => l10n.connections_insight_groupsValue(t.value),
    };
  }
}
