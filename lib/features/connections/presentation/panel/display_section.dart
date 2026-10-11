import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String layoutLabel(AppLocalizations l10n, ConnectionsLayout layout) =>
    switch (layout) {
      ConnectionsLayout.web => l10n.connections_layout_web,
      ConnectionsLayout.radial => l10n.connections_layout_radial,
      ConnectionsLayout.circle => l10n.connections_layout_circle,
      ConnectionsLayout.columns => l10n.connections_layout_columns,
      ConnectionsLayout.clusters => l10n.connections_layout_clusters,
      ConnectionsLayout.timeline => l10n.connections_layout_timeline,
    };

/// How the graph is drawn: layout, labels, node size, lines, unconnected
/// nodes and spacing. Shown in the View tab while the Graph view is on.
class DisplaySection extends ConsumerStatefulWidget {
  const DisplaySection({super.key});

  @override
  ConsumerState<DisplaySection> createState() => _DisplaySectionState();
}

class _DisplaySectionState extends ConsumerState<DisplaySection> {
  /// The spacing while its slider is being dragged; written on release so
  /// the map lays out once, not on every tick.
  double? _dragSpacing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final display = ref.watch(connectionsDisplayProvider);
    final around = ref.watch(
      connectionsViewProvider.select((v) => v.mode == ConnectionsMode.around),
    );
    final notifier = ref.read(connectionsDisplayProvider.notifier);
    final current = display.layoutFor(around: around);
    final offered = around
        ? ConnectionsLayout.forAround
        : ConnectionsLayout.forMap;
    return Column(
      key: const ValueKey('connections-display'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.connections_display_title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(l10n.connections_layout_title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final layout in offered)
              ChoiceChip(
                key: ValueKey('layout-${layout.name}'),
                label: Text(layoutLabel(l10n, layout)),
                selected: layout == current,
                onSelected: (_) => notifier.update(
                  (d) => d.withLayout(layout, around: around),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Segments<LabelMode>(
          title: l10n.connections_labels_title,
          options: {
            LabelMode.auto: l10n.connections_labels_auto,
            LabelMode.all: l10n.connections_labels_all,
            LabelMode.off: l10n.connections_labels_off,
          },
          selected: display.labels,
          onChanged: (v) => notifier.update((d) => d.copyWith(labels: v)),
        ),
        const SizedBox(height: 12),
        _Segments<NodeSizeMode>(
          title: l10n.connections_nodeSize_title,
          options: {
            NodeSizeMode.byDives: l10n.connections_nodeSize_byDives,
            NodeSizeMode.uniform: l10n.connections_nodeSize_uniform,
          },
          selected: display.nodeSize,
          onChanged: (v) => notifier.update((d) => d.copyWith(nodeSize: v)),
        ),
        const SizedBox(height: 12),
        _Segments<EdgeMode>(
          title: l10n.connections_edges_title,
          options: {
            EdgeMode.weighted: l10n.connections_edges_weighted,
            EdgeMode.thin: l10n.connections_edges_thin,
            EdgeMode.selectedOnly: l10n.connections_edges_selectedOnly,
          },
          selected: display.edges,
          onChanged: (v) => notifier.update((d) => d.copyWith(edges: v)),
        ),
        SwitchListTile(
          key: const ValueKey('hide-unconnected'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.connections_hideUnconnected),
          value: display.hideUnconnected,
          onChanged: (v) =>
              notifier.update((d) => d.copyWith(hideUnconnected: v)),
        ),
        Text(l10n.connections_spacing_title, style: theme.textTheme.labelLarge),
        Row(
          children: [
            Text(
              l10n.connections_spacing_tight,
              style: theme.textTheme.bodySmall,
            ),
            Expanded(
              child: Slider(
                key: const ValueKey('spacing-slider'),
                min: ConnectionsDisplay.minSpacing,
                max: ConnectionsDisplay.maxSpacing,
                divisions: 14,
                value: _dragSpacing ?? display.spacing,
                onChanged: (v) => setState(() => _dragSpacing = v),
                onChangeEnd: (v) {
                  setState(() => _dragSpacing = null);
                  notifier.update((d) => d.copyWith(spacing: v));
                },
              ),
            ),
            Text(
              l10n.connections_spacing_spread,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Segments<T> extends StatelessWidget {
  const _Segments({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final MapEntry(:key, :value) in options.entries)
              ButtonSegment(value: key, label: Text(value)),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.single),
        ),
      ],
    );
  }
}
