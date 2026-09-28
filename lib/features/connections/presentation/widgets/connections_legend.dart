import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
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

/// One swatch per kind in view. [showTitle] is false on the compact overlay.
class ConnectionsLegend extends StatelessWidget {
  const ConnectionsLegend({
    super.key,
    required this.kinds,
    required this.colors,
    this.showTitle = true,
  });

  final Set<ConnectionKind> kinds;
  final ConnectionKindColors colors;
  final bool showTitle;

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
        for (final k in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.colorFor(k),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  kindLabel(context.l10n, k),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
