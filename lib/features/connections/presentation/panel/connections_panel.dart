import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/presentation/panel/details_tab.dart';
import 'package:submersion/features/connections/presentation/panel/filter_tab.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The View, Filter and Details tabs: the fixed right panel on wide
/// layouts, the draggable sheet's body on phones.
class ConnectionsPanel extends ConsumerStatefulWidget {
  const ConnectionsPanel({
    super.key,
    required this.viewTab,
    required this.graph,
    this.scrollController,
    this.compact = false,
  });

  final Widget viewTab;
  final ConnectionGraph graph;

  /// The sheet's controller on phones, so dragging the content drags the
  /// sheet. Null on wide layouts.
  final ScrollController? scrollController;
  final bool compact;

  static const int viewIndex = 0;
  static const int filterIndex = 1;
  static const int detailsIndex = 2;

  @override
  ConsumerState<ConnectionsPanel> createState() => _ConnectionsPanelState();
}

class _ConnectionsPanelState extends ConsumerState<ConnectionsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  /// The tab to return to when the selection clears.
  int _beforeDetails = ConnectionsPanel.viewIndex;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onSelection(GraphSelection? previous, GraphSelection? next) {
    if (next != null && previous == null) {
      if (_tabs.index != ConnectionsPanel.detailsIndex) {
        _beforeDetails = _tabs.index;
      }
      _tabs.animateTo(ConnectionsPanel.detailsIndex);
    } else if (next == null && previous != null) {
      _tabs.animateTo(_beforeDetails);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GraphSelection?>(connectionsSelectionProvider, _onSelection);
    ref.watch(connectionsFilterProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filterCount = activeDiveFilterChips(
      context,
      ref,
      connectionsFilterProvider,
    ).length;
    final content = switch (_tabs.index) {
      ConnectionsPanel.filterIndex => const FilterTab(),
      ConnectionsPanel.detailsIndex => DetailsTab(graph: widget.graph),
      _ => widget.viewTab,
    };
    return Material(
      key: const ValueKey('connections-panel'),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          if (widget.compact)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(
                key: const ValueKey('connections-tab-view'),
                text: l10n.connections_tab_view,
              ),
              Tab(
                key: const ValueKey('connections-tab-filter'),
                text: filterCount == 0
                    ? l10n.connections_tab_filter
                    : l10n.connections_tab_filterCount(filterCount),
              ),
              Tab(
                key: const ValueKey('connections-tab-details'),
                text: l10n.connections_tab_details,
              ),
            ],
          ),
          Padding(padding: const EdgeInsets.all(16), child: content),
        ],
      ),
    );
  }
}
