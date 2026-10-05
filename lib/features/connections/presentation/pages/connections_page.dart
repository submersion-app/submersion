import 'package:flutter/material.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/connections/presentation/connection_labels.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/graph_insights.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
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
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_action.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_caption.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_renderer.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_empty_state.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/connections/presentation/widgets/hidden_nodes_chip.dart';
import 'package:submersion/features/connections/presentation/widgets/insight_strip.dart';
import 'package:submersion/features/connections/presentation/widgets/year_play_pill.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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

  /// The last graph shown, held while a different budget loads (a new family
  /// key has no previous value of its own), so the canvas never unmounts.
  ConnectionGraph? _lastGraph;

  /// The last graph localized, keyed by source graph and localizations, so
  /// a rebuild hands the layout the same instance (it relays out on a new
  /// one).
  ConnectionGraph? _localizedFrom;
  AppLocalizations? _localizedIn;
  ConnectionGraph? _localized;

  ConnectionGraph _localize(ConnectionGraph source, AppLocalizations l10n) {
    if (identical(source, _localizedFrom) && identical(l10n, _localizedIn)) {
      return _localized!;
    }
    _localizedFrom = source;
    _localizedIn = l10n;
    return _localized = localizeGraph(source, l10n);
  }

  /// Groups and insights for the last graph and focus, so a rebuild reuses
  /// them (label propagation runs once per laid-out graph).
  ConnectionGraph? _storyFrom;
  NodeRef? _storyFocus;
  GraphGroups _groups = GraphGroups.empty;
  List<InsightTile> _insights = const [];

  void _story(ConnectionGraph graph, NodeRef? focus) {
    if (identical(graph, _storyFrom) && focus == _storyFocus) return;
    _storyFrom = graph;
    _storyFocus = focus;
    _groups = LabelPropagation.communities(graph);
    _insights = GraphInsights.of(graph, focus: focus, groups: _groups);
  }

  /// The phone sheet's height as a fraction of the body; the canvas fits
  /// the graph into the space above it.
  double _sheetExtent = _sheetInitial;
  static const double _sheetInitial = 0.22;

  /// True until a deep link has been written to the view. Riverpod forbids
  /// provider writes inside initState, so the write waits for the first
  /// frame, and the first graph watch waits with it (no wasted load).
  late bool _deepLinkPending = !widget.args.isEmpty;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetMoved);
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

  void _onSheetMoved() {
    if (!mounted || !_sheet.isAttached) return;
    final size = _sheet.size;
    if ((size - _sheetExtent).abs() > 0.001) {
      setState(() => _sheetExtent = size);
    }
  }

  @override
  void dispose() {
    _sheet.removeListener(_onSheetMoved);
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

  /// Shares the map in view as an image: the layout as it stands, in the
  /// current highlight mode, captioned with the map's name and range.
  Future<void> _share(
    ConnectionGraph graph,
    ConnectionsViewState view,
    BuildContext button,
  ) {
    final caption = ConnectionsShareCaption.of(
      l10n: context.l10n,
      units: UnitFormatter(ref.read(settingsProvider)),
      view: view,
      graph: graph,
      filter: ref.read(connectionsFilterProvider),
      span: ref.read(connectionsYearSpanProvider).value,
      savedMapNames: {
        for (final m in ref.read(savedConnectionMapsProvider).value ?? const [])
          m.id: m.name,
      },
    );
    // The image is the map at rest, never nodes caught mid-move.
    final frame = _layout.settleNow();
    final groups = _groups;
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final direction = Directionality.of(context);
    return shareConnectionsImage(
      context,
      anchorContext: button,
      render: () => ConnectionsShareRenderer.renderWithAssets(
        graph: graph,
        frame: frame,
        highlight: view.highlight,
        groups: groups,
        caption: caption,
        fontFamily: fontFamily,
        direction: direction,
      ),
    );
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
      EdgeSelection(:final a, :final b) => graph.edges.any(
        (e) => e.touches(a) && e.touches(b),
      ),
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
      // Year play steps to the next year only once this one has loaded.
      final play = ref.read(yearPlayProvider.notifier);
      if (next.isLoading) {
        play.loadStarted();
      } else {
        play.loadSettled(failed: next.hasError);
      }
    });
    ref.listen<GraphSelection?>(connectionsSelectionProvider, _onSelection);
    // Year play lives as long as the page, not only while the pill shows:
    // an empty year swaps the canvas out, and play must carry on past it.
    ref.listen<int?>(yearPlayProvider, (_, _) {});
    // A saved map edited or deleted elsewhere (sync, another device) must
    // not leave its card selected over a stale drawing.
    ref.listen(savedConnectionMapsProvider, (_, next) {
      final maps = next.value;
      if (maps == null) return;
      ref
          .read(connectionsViewProvider.notifier)
          .update((s) => s.withSavedMaps({for (final m in maps) m.id: m.spec}));
    });

    // A reload keeps the previous value; a new budget key has none, so the
    // page holds the last graph itself while any load is running.
    final held = graphAsync.value ?? (graphAsync.isLoading ? _lastGraph : null);
    if (graphAsync.hasValue) _lastGraph = graphAsync.value;
    // Built-in species and dive types read in the diver's language.
    final graph = held == null ? ConnectionGraph.empty : _localize(held, l10n);
    final showCanvas =
        held != null && !view.isAroundWithoutFocus && !graph.isEmpty;
    final animate = _hadGraph && !MediaQuery.disableAnimationsOf(context);
    if (showCanvas) {
      _syncLayout(graph, focus, animate: animate);
      _story(graph, focus);
    }
    final reloadFailed =
        held != null &&
        graphAsync.hasError &&
        graphAsync.error is! FocusNotFoundException;

    Widget canvasArea(double bottomInset) {
      // The strip sits 8 px down and grows with the reader's text size;
      // overlays start below it, or at the top when it has nothing to say.
      final stripHeight = _insights.isEmpty
          ? 0.0
          : InsightStrip.heightOf(context) + 8;
      final belowStrip = stripHeight + (_insights.isEmpty ? 12 : 8);
      // Shown over the canvas and over an empty played year alike.
      final playPill = Positioned(
        left: 12,
        bottom: bottomInset + 12,
        child: const YearPlayPill(),
      );
      if (held == null && graphAsync.hasError) {
        return graphAsync.error is FocusNotFoundException
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
      }
      if (held == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!showCanvas) {
        // Around mode with no centre prompts for one even while the
        // previous map is still held for the reload.
        final empty = ConnectionsEmptyState(
          view: view,
          hasAnyDives: ref.watch(connectionsYearSpanProvider).value != null,
          hasActiveFilter: hasActiveFilter,
        );
        if (view.isAroundWithoutFocus) return empty;
        // A played year can be empty; the pill stays so play can be paused.
        return Stack(
          children: [
            Positioned.fill(child: empty),
            playPill,
          ],
        );
      }
      final kinds = graph.nodes.map((n) => n.ref.kind).toSet();
      return Stack(
        children: [
          Positioned.fill(
            child: ConnectionsCanvas(
              graph: graph,
              controller: _layout,
              colors: colors,
              selection: selection,
              semanticsLabel: _semanticsLabel(graph, selection),
              animate: animate,
              bottomInset: bottomInset,
              topInset: stripHeight,
              highlight: view.highlight,
              groupOf: _groups.groupOf,
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
          Positioned(
            key: const ValueKey('connections-insights'),
            left: 0,
            right: 0,
            top: 8,
            child: InsightStrip(
              graph: graph,
              tiles: _insights,
              onSelect: (s) =>
                  ref.read(connectionsSelectionProvider.notifier).state = s,
              onGroups: () => ref
                  .read(connectionsViewProvider.notifier)
                  .update((s) => s.withHighlight(HighlightMode.groups)),
            ),
          ),
          if (!wide)
            Positioned(
              left: 12,
              top: belowStrip,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ConnectionsLegend(
                    kinds: kinds,
                    colors: colors,
                    showTitle: false,
                    highlight: view.highlight,
                    groupCount: _groups.count,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: belowStrip,
            child: HiddenNodesChip(
              count: graph.hiddenNodeCount,
              onShowAll: budget >= ConnectionsPage.maxBudget
                  ? null
                  : () => _showAll(graph.nodes.length + graph.hiddenNodeCount),
            ),
          ),
          if (reloadFailed)
            Positioned(
              left: 12,
              right: 12,
              top: belowStrip + 44,
              child: Card(
                key: const ValueKey('connections-reload-error'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.connections_error_load)),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(connectionGraphProvider(budget)),
                        child: Text(l10n.common_action_retry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          playPill,
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
          viewTab: ViewTab(graph: graph, groupCount: _groups.count),
          graph: graph,
          scrollController: scrollController,
          compact: compact,
        );

    final body = wide
        ? Row(
            children: [
              Expanded(child: canvasArea(0)),
              SizedBox(width: ConnectionsPage.panelWidth, child: panel()),
            ],
          )
        : LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: canvasArea(_sheetExtent * constraints.maxHeight),
                ),
                DraggableScrollableSheet(
                  key: const ValueKey('connections-sheet'),
                  controller: _sheet,
                  initialChildSize: _sheetInitial,
                  minChildSize: 0.12,
                  maxChildSize: 0.85,
                  snap: true,
                  snapSizes: const [_sheetInitial, 0.5],
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
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connections_title),
        actions: [
          // A Builder gives the button its own context for the iPad popover.
          Builder(
            builder: (button) => IconButton(
              key: const ValueKey('connections-share'),
              icon: const Icon(Icons.ios_share),
              tooltip: l10n.connections_share_tooltip,
              onPressed: showCanvas ? () => _share(graph, view, button) : null,
            ),
          ),
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
