import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_canvas.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/panel/connections_panel.dart';
import 'package:submersion/features/connections/presentation/panel/view_tab.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_empty_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key, this.args = const ConnectionsRouteArgs()});

  final ConnectionsRouteArgs args;

  static const compactBudget = 80;
  static const wideBudget = 160;
  static const maxBudget = 400;
  static const double panelWidth = 340;

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late final ConnectionsLayoutController _layout = ConnectionsLayoutController(
    vsync: this,
  );
  final DraggableScrollableController _sheet = DraggableScrollableController();
  int? _budgetOverride;
  ConnectionGraph? _laidOut;
  NodeRef? _laidOutFocus;
  bool _focusWarned = false;

  /// False until the first graph is laid out; that one never animates.
  bool _hadGraph = false;

  /// True until a deep link has been written to the view. Riverpod forbids
  /// provider writes inside initState, so the write waits for the first
  /// frame, and the first graph watch waits with it (no wasted load).
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
    // The reset always runs: a centre can vanish more than once in one page
    // lifetime (a deep link, then an entity deleted while the page is open).
    ref
        .read(connectionsViewProvider.notifier)
        .update((s) => s.copyWith(clearFocus: true));
    ref.read(connectionsSelectionProvider.notifier).state = null;
    if (_focusWarned) return;
    _focusWarned = true;
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
    _sheet.dispose();
    super.dispose();
  }

  void _syncLayout(
    ConnectionGraph graph,
    NodeRef? focus, {
    required bool animate,
  }) {
    if (identical(_laidOut, graph) && _laidOutFocus == focus) return;
    _laidOut = graph;
    _laidOutFocus = focus;
    _layout.setGraph(
      graph,
      mode: focus == null ? GraphLayoutMode.web : GraphLayoutMode.ego,
      focus: focus,
      animate: animate,
    );
    _hadGraph = true;
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

  /// Clears a selection the newly loaded graph no longer contains, so a
  /// view change never leaves the canvas dimmed around a missing node or the
  /// Details tab describing an entity that is not on the map.
  void _dropStaleSelection(ConnectionGraph graph) {
    final selection = ref.read(connectionsSelectionProvider);
    final present = switch (selection) {
      null => true,
      NodeSelection(:final ref) => graph.nodeFor(ref) != null,
      EdgeSelection(:final a, :final b) =>
        graph.nodeFor(a) != null && graph.nodeFor(b) != null,
    };
    if (!present) ref.read(connectionsSelectionProvider.notifier).state = null;
  }

  void _onSelection(GraphSelection? previous, GraphSelection? next) {
    if (next == null || previous != null || !_sheet.isAttached) return;
    if (_sheet.size < 0.5) {
      _sheet.animateTo(
        0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
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
    final wide =
        MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.masterDetail;
    final budget =
        _budgetOverride ??
        (wide ? ConnectionsPage.wideBudget : ConnectionsPage.compactBudget);
    final graphAsync = ref.watch(connectionGraphProvider(budget));
    final view = ref.watch(connectionsViewProvider);
    final selection = ref.watch(connectionsSelectionProvider);
    final hasActiveFilter = ref
        .watch(connectionsFilterProvider)
        .hasActiveFilters;
    final colors = ConnectionKindColors.of(context);
    final focus = view.mode == ConnectionsMode.around ? view.focus : null;

    ref.listen(connectionGraphProvider(budget), (_, next) {
      if (next.hasError && next.error is FocusNotFoundException) {
        _warnFocusMissing();
      }
      if (!next.isLoading && next.hasValue) _dropStaleSelection(next.value!);
    });
    ref.listen<GraphSelection?>(connectionsSelectionProvider, _onSelection);

    final graph = graphAsync.value ?? ConnectionGraph.empty;
    final Widget canvasArea;
    if (!graphAsync.hasValue && graphAsync.hasError) {
      canvasArea = graphAsync.error is FocusNotFoundException
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
            );
    } else if (!graphAsync.hasValue) {
      canvasArea = const Center(child: CircularProgressIndicator());
    } else if (view.isAroundWithoutFocus || graph.isEmpty) {
      // Around mode with no centre prompts for one even while the previous
      // map is still held for the reload.
      canvasArea = ConnectionsEmptyState(
        view: view,
        hasAnyDives: ref.watch(connectionsYearSpanProvider).value != null,
        hasActiveFilter: hasActiveFilter,
      );
    } else {
      final animate = _hadGraph && !MediaQuery.disableAnimationsOf(context);
      _syncLayout(graph, focus, animate: animate);
      final kinds = graph.nodes.map((n) => n.ref.kind).toSet();
      canvasArea = Stack(
        children: [
          Positioned.fill(
            child: ConnectionsCanvas(
              graph: graph,
              controller: _layout,
              colors: colors,
              selection: selection,
              semanticsLabel: _semanticsLabel(graph, selection),
              animate: animate,
              onSelect: (s) =>
                  ref.read(connectionsSelectionProvider.notifier).state = s,
              onFocus: (node) {
                ref
                    .read(connectionsViewProvider.notifier)
                    .update((s) => s.centreOn(node));
                ref.read(connectionsSelectionProvider.notifier).state =
                    NodeSelection(node);
              },
            ),
          ),
          if (!wide)
            Positioned(
              left: 12,
              top: 12,
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
                  : () => _showAll(graph.nodes.length + graph.hiddenNodeCount),
            ),
          ),
          if (graphAsync.isLoading)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Semantics(
                label: l10n.connections_loading,
                child: const LinearProgressIndicator(
                  key: ValueKey('connections-reload-progress'),
                  minHeight: 2,
                ),
              ),
            ),
        ],
      );
    }

    Widget panel({ScrollController? scrollController, bool compact = false}) =>
        ConnectionsPanel(
          viewTab: ViewTab(graph: graph),
          graph: graph,
          scrollController: scrollController,
          compact: compact,
        );

    final body = wide
        ? Row(
            children: [
              Expanded(child: canvasArea),
              SizedBox(width: ConnectionsPage.panelWidth, child: panel()),
            ],
          )
        : Stack(
            children: [
              Positioned.fill(child: canvasArea),
              DraggableScrollableSheet(
                key: const ValueKey('connections-sheet'),
                controller: _sheet,
                initialChildSize: 0.22,
                minChildSize: 0.12,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [0.22, 0.5],
                builder: (context, scrollController) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: panel(
                    scrollController: scrollController,
                    compact: true,
                  ),
                ),
              ),
            ],
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
        ],
      ),
      body: body,
    );
  }
}
