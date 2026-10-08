import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/widgets/highlight_key.dart';
import 'package:submersion/features/connections/presentation/widgets/kind_dot.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String kindLabel(AppLocalizations l10n, ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy => l10n.connections_kind_buddy,
  ConnectionKind.site => l10n.connections_kind_site,
  ConnectionKind.trip => l10n.connections_kind_trip,
  ConnectionKind.diveCenter => l10n.connections_kind_diveCenter,
  ConnectionKind.equipment => l10n.connections_kind_equipment,
  ConnectionKind.species => l10n.connections_kind_species,
  ConnectionKind.tag => l10n.connections_kind_tag,
  ConnectionKind.diveType => l10n.connections_kind_diveType,
  ConnectionKind.diveComputer => l10n.connections_kind_diveComputer,
  ConnectionKind.course => l10n.connections_kind_course,
};

/// One entity's kind ("Buddy"), where [kindLabel] names the group.
String kindNameOne(AppLocalizations l10n, ConnectionKind kind) =>
    switch (kind) {
      ConnectionKind.buddy => l10n.connections_kindOne_buddy,
      ConnectionKind.site => l10n.connections_kindOne_site,
      ConnectionKind.trip => l10n.connections_kindOne_trip,
      ConnectionKind.diveCenter => l10n.connections_kindOne_diveCenter,
      ConnectionKind.equipment => l10n.connections_kindOne_equipment,
      ConnectionKind.species => l10n.connections_kindOne_species,
      ConnectionKind.tag => l10n.connections_kindOne_tag,
      ConnectionKind.diveType => l10n.connections_kindOne_diveType,
      ConnectionKind.diveComputer => l10n.connections_kindOne_diveComputer,
      ConnectionKind.course => l10n.connections_kindOne_course,
    };

/// One swatch per kind in view, or the group swatches in Groups mode, with
/// the edge fade added in Recency mode. [showTitle] is false on the compact
/// overlay.
class ConnectionsLegend extends StatelessWidget {
  const ConnectionsLegend({
    super.key,
    required this.kinds,
    required this.colors,
    this.showTitle = true,
    this.highlight = HighlightMode.byKind,
    this.groupCount = 0,
  });

  final Set<ConnectionKind> kinds;
  final ConnectionKindColors colors;
  final bool showTitle;
  final HighlightMode highlight;
  final int groupCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle)
          Text(
            context.l10n.connections_legend_title,
            style: theme.textTheme.labelLarge,
          ),
        if (highlight == HighlightMode.groups)
          HighlightKey(mode: highlight, groupCount: groupCount)
        else
          for (final k in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KindDot(color: colors.colorFor(k), size: 12),
                  const SizedBox(width: 6),
                  Text(
                    kindLabel(context.l10n, k),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        if (highlight == HighlightMode.recency)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: HighlightKey(mode: HighlightMode.recency),
          ),
      ],
    );
  }
}
