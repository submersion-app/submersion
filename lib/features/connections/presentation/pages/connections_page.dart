import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_empty_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_filter_action.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_filter_bar.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_card.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_panel.dart';
import 'package:submersion/features/connections/presentation/widgets/year_range_slider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key, this.args = const ConnectionsRouteArgs()});

  /// The `/connections` query parameters, applied once after the first frame.
  final ConnectionsRouteArgs args;

  static const compactBudget = 80;
  static const wideBudget = 160;
  static const maxBudget = 400;

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late final ConnectionsLayoutController _layout = ConnectionsLayoutController(
    vsync: this,
  );
  int? _budgetOverride;
  ConnectionGraph? _laidOut;
  NodeRef? _laidOutFocus;
  bool _focusWarned = false;

  /// True until a deep link's arguments have been written to the view
  /// provider. Riverpod forbids provider writes inside initState, so the
  /// write waits for the first frame; deferring the first graph watch until
  /// then avoids loading the whole web only to replace it with the ego graph.
  late bool _deepLinkPending = !widget.args.isEmpty;

  @override
  void initState() {
    super.initState();
    if (!_deepLinkPending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDeepLink();
      if (mounted) setState(() => _deepLinkPending = false);
    });
  }

  void _applyDeepLink() {
    if (!mounted) return;
    ref.read(connectionsViewProvider.notifier).update(widget.args.apply);
    final focus = NodeRef.parse(widget.args.focus);
    if (focus != null) {
      ref.read(connectionsSelectionProvider.notifier).state = NodeSelection(
        focus,
      );
    }
  }

  void _warnFocusMissing() {
    if (!mounted) return;
    // The reset always runs: a focus can vanish more than once in one page
    // lifetime (a deep link, then a buddy deleted while the page is open).
    ref
        .read(connectionsViewProvider.notifier)
        .update((s) => s.copyWith(clearFocus: true));
    if (_focusWarned) return;
    _focusWarned = true;
    // initState has no Scaffold above it yet; the snackbar waits a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.connections_focusMissing)),
      );
    });
  }

  @override
  void dispose() {
    _layout.dispose();
    super.dispose();
  }

  void _syncLayout(ConnectionGraph graph, NodeRef? focus) {
    if (identical(_laidOut, graph) && _laidOutFocus == focus) return;
    _laidOut = graph;
    _laidOutFocus = focus;
    _layout.setGraph(
      graph,
      mode: focus == null ? GraphLayoutMode.web : GraphLayoutMode.ego,
      focus: focus,
    );
  }

  /// Raises the node budget to [ConnectionsPage.maxBudget]. Only a graph
  /// larger than the ceiling asks first, because only then can the layout
  /// get slow.
  Future<void> _showAll(int total) async {
    if (total > ConnectionsPage.maxBudget) {
      final l10n = context.l10n;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.connections_showAll_confirmTitle),
          content: Text(l10n.connections_showAll_confirmBody(total)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.connections_showAll),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (mounted) {
      setState(() => _budgetOverride = ConnectionsPage.maxBudget);
    }
  }

  /// The canvas's accessible summary: counts, then the selection by name.
  String _semanticsLabel(ConnectionGraph graph, GraphSelection? selection) {
    final l10n = context.l10n;
    final summary = l10n.connections_semantics_summary(
      graph.nodes.length,
      graph.edges.length,
    );
    final String? selected = switch (selection) {
      null => null,
      NodeSelection(:final ref) => graph.nodeFor(ref)?.label,
      EdgeSelection(:final a, :final b) =>
        '${graph.nodeFor(a)?.label ?? a.id}, ${graph.nodeFor(b)?.label ?? b.id}',
    };
    if (selected == null) return summary;
    return '$summary. ${l10n.connections_semantics_selected(selected)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_deepLinkPending) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.connections_title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= ResponsiveBreakpoints.masterDetail;
    final budget =
        _budgetOverride ??
        (wide ? ConnectionsPage.wideBudget : ConnectionsPage.compactBudget);
    final graphAsync = ref.watch(connectionGraphProvider(budget));
    final view = ref.watch(connectionsViewProvider);
    final focus = view.mode == ConnectionsMode.around ? view.focus : null;
    final selection = ref.watch(connectionsSelectionProvider);
    final colors = ConnectionKindColors.of(context);

    ref.listen(connectionGraphProvider(budget), (_, next) {
      if (next.hasError && next.error is FocusNotFoundException) {
        _warnFocusMissing();
      }
    });

    final body = graphAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => e is FocusNotFoundException
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.connections_error_load),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(connectionGraphProvider(budget)),
                    child: Text(l10n.common_action_retry),
                  ),
                ],
              ),
            ),
      data: (graph) {
        _syncLayout(graph, focus);
        final kinds = graph.nodes.map((n) => n.ref.kind).toSet();
        final Widget centre;
        if (graph.isEmpty) {
          final span = ref.watch(connectionsYearSpanProvider).value;
          centre = ConnectionsEmptyState(
            view: view,
            hasAnyDives: span != null,
            hasActiveFilter: ref
                .watch(connectionsFilterProvider)
                .hasActiveFilters,
          );
        } else {
          final canvas = ConnectionsCanvas(
            graph: graph,
            controller: _layout,
            colors: colors,
            selection: selection,
            semanticsLabel: _semanticsLabel(graph, selection),
            onSelect: (s) =>
                ref.read(connectionsSelectionProvider.notifier).state = s,
            onFocus: (node) {
              ref
                  .read(connectionsViewProvider.notifier)
                  .update((s) => s.centreOn(node));
              ref.read(connectionsSelectionProvider.notifier).state =
                  NodeSelection(node);
            },
          );
          centre = Stack(
            children: [
              Positioned.fill(child: canvas),
              if (!wide)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ConnectionsLegend(
                        kinds: kinds,
                        colors: colors,
                        showTitle: false,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                top: 12,
                child: HiddenNodesChip(
                  count: graph.hiddenNodeCount,
                  onShowAll: budget >= ConnectionsPage.maxBudget
                      ? null
                      : () => _showAll(
                          graph.nodes.length + graph.hiddenNodeCount,
                        ),
                ),
              ),
              if (!wide && selection != null)
                SelectionCard(
                  graph: graph,
                  selection: selection,
                  onClose: () =>
                      ref.read(connectionsSelectionProvider.notifier).state =
                          null,
                ),
            ],
          );
        }
        if (wide) {
          return Row(
            children: [
              Expanded(child: centre),
              SelectionPanel(
                graph: graph,
                selection: selection,
                children: [
                  ConnectionsFilterBar(graph: graphAsync),
                  const YearRangeSlider(),
                  const SizedBox(height: 12),
                  ConnectionsLegend(kinds: kinds, colors: colors),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            ConnectionsFilterBar(graph: graphAsync),
            const YearRangeSlider(),
            Expanded(child: centre),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connections_title),
        actions: [
          if (focus != null)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: l10n.connections_tooltip_showWholeWeb,
              onPressed: () {
                ref
                    .read(connectionsViewProvider.notifier)
                    .update((s) => s.withMode(ConnectionsMode.map));
                ref.read(connectionsSelectionProvider.notifier).state = null;
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.connections_tooltip_relayout,
              onPressed: _layout.relayout,
            ),
          const ConnectionsFilterAction(),
        ],
      ),
      body: body,
    );
  }
}
