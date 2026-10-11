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
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/connections/presentation/pages/connections_graph_stack.dart';
import 'package:submersion/features/connections/presentation/pages/connections_table_area.dart';
import 'package:submersion/features/connections/presentation/views/view_mode_button.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
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
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';

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

  ConnectionsLayout? _laidOutLayout;
  double? _laidOutSpacing;

  /// The canvas graph for the last source, keyed like [_localize], so the
  /// layout sees the same instance on a rebuild.
  ConnectionGraph? _canvasFrom;
  bool _canvasHide = false;
  NodeRef? _canvasKeep;
  ConnectionGraph? _canvasGraph;

  ConnectionGraph _canvasGraphFor(
    ConnectionGraph graph, {
    required bool hide,
    NodeRef? keep,
  }) {
    if (identical(graph, _canvasFrom) &&
        hide == _canvasHide &&
        keep == _canvasKeep) {
      return _canvasGraph!;
    }
    _canvasFrom = graph;
    _canvasHide = hide;
    _canvasKeep = keep;
    return _canvasGraph = hide ? graph.withoutUnconnected(keep: keep) : graph;
  }

  void _syncLayout(
    ConnectionGraph graph,
    NodeRef? focus, {
    required ConnectionsLayout layout,
    required double spacing,
    required bool animate,
    GraphGroups? groups,
  }) {
    if (identical(_laidOut, graph) &&
        _laidOutFocus == focus &&
        _laidOutLayout == layout &&
        _laidOutSpacing == spacing) {
      return;
    }
    _laidOut = graph;
    _laidOutFocus = focus;
    _laidOutLayout = layout;
    _laidOutSpacing = spacing;
    _layout.setGraph(
      graph,
      layout: layout,
      focus: focus,
      spacing: spacing,
      animate: animate,
      groups: groups,
    );
    _hadGraph = true;
  }

  /// Raises the node budget to [ConnectionsPage.maxBudget]. Only a graph
  /// larger than the ceiling asks first, because only then can the layout
  /// get slow.
  Future<void> _showAll(int total) async {
    if (total > ConnectionsPage.maxBudget &&
        !await confirmShowAll(context, total)) {
      return;
    }
    if (mounted) {
      setState(() => _budgetOverride = ConnectionsPage.maxBudget);
    }
  }

  /// Shares the map in view as an image: the layout as it stands, in the
  /// current highlight mode, captioned with the map's name and range.
  Future<void> _share(
    ConnectionGraph graph,
    ConnectionGraph drawn,
    ConnectionsViewState view,
    ConnectionsDisplay display,
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
    final l10n = context.l10n;
    final names = kindNames(l10n);
    return shareConnectionsImage(
      context,
      anchorContext: button,
      // The image draws what the canvas draws, so node sizes match it.
      render: () => ConnectionsShareRenderer.renderWithAssets(
        graph: drawn,
        frame: frame,
        highlight: view.highlight,
        groups: groups,
        caption: caption,
        fontFamily: fontFamily,
        direction: direction,
        labels: display.labels,
        nodeSize: display.nodeSize,
        edges: display.edges,
        kindNames: names,
      ),
    );
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
    final display = ref.watch(connectionsDisplayProvider);
    final layoutChoice = display.layoutFor(
      around: view.mode == ConnectionsMode.around,
    );

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
    final canvasGraph = _canvasGraphFor(
      graph,
      hide: display.hideUnconnected,
      keep: focus,
    );
    if (showCanvas) {
      // Groups first: the clusters layout reuses them. Hiding unconnected
      // nodes never changes them, since a node with no edge is in no group.
      _story(graph, focus);
      if (display.view == ConnectionsViewKind.graph) {
        _syncLayout(
          canvasGraph,
          focus,
          layout: layoutChoice,
          spacing: display.spacing,
          animate: animate,
          groups: _groups,
        );
      }
    }
    final VoidCallback? showAll = budget >= ConnectionsPage.maxBudget
        ? null
        : () => _showAll(graph.nodes.length + graph.hiddenNodeCount);
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
      if (display.view != ConnectionsViewKind.graph) {
        return ConnectionsTableArea(
          view: display.view,
          graph: graph,
          colors: colors,
          selection: selection,
          onSelect: (s) =>
              ref.read(connectionsSelectionProvider.notifier).state = s,
          onShowAll: showAll,
          bottomInset: bottomInset,
          playPill: playPill,
          loading: graphAsync.isLoading,
        );
      }
      return ConnectionsGraphStack(
        graph: graph,
        canvasGraph: canvasGraph,
        controller: _layout,
        colors: colors,
        selection: selection,
        animate: animate,
        bottomInset: bottomInset,
        stripHeight: stripHeight,
        belowStrip: belowStrip,
        highlight: view.highlight,
        groups: _groups,
        insights: _insights,
        wide: wide,
        display: display,
        onSelect: (s) =>
            ref.read(connectionsSelectionProvider.notifier).state = s,
        onFocus: (node) {
          ref
              .read(connectionsViewProvider.notifier)
              .update((s) => s.centreOn(node));
          ref.read(connectionsSelectionProvider.notifier).state = NodeSelection(
            node,
          );
        },
        onGroups: () => ref
            .read(connectionsViewProvider.notifier)
            .update((s) => s.withHighlight(HighlightMode.groups)),
        onShowAll: showAll,
        reloadFailed: reloadFailed,
        onRetry: () => ref.invalidate(connectionGraphProvider(budget)),
        playPill: playPill,
        loading: graphAsync.isLoading,
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
          const ViewModeButton(),
          // A Builder gives the button its own context for the iPad popover.
          if (display.view == ConnectionsViewKind.graph)
            Builder(
              builder: (button) => IconButton(
                key: const ValueKey('connections-share'),
                icon: const Icon(Icons.ios_share),
                tooltip: l10n.connections_share_tooltip,
                onPressed: showCanvas
                    ? () => _share(graph, canvasGraph, view, display, button)
                    : null,
              ),
            ),
          if (display.view == ConnectionsViewKind.graph)
            ListenableBuilder(
              listenable: _layout.canRelayout,
              builder: (context, _) => _layout.canRelayout.value
                  ? IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: l10n.connections_tooltip_relayout,
                      onPressed: _layout.relayout,
                    )
                  : const SizedBox.shrink(),
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
            ),
        ],
      ),
      body: body,
    );
  }
}
