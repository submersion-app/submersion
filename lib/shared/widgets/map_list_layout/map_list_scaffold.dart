import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/collapsible_list_pane.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// A scaffold for map pages that shows list + map split on desktop.
///
/// On desktop (>=1100px): Shows collapsible list pane on left, map on right.
/// On mobile (<1100px): Shows only the map (existing behavior).
class MapListScaffold extends ConsumerWidget {
  /// Bottom offset for info card on mobile to clear FAB.
  /// Calculated as: FAB height (56) + margin (16) + spacing (8) = 80
  static const double _mobileInfoCardBottomOffset = 80;

  final String sectionKey;
  final String title;
  final Widget listPane;
  final Widget mapPane;
  final Widget? infoCard;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final double listWidth;

  const MapListScaffold({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.listPane,
    required this.mapPane,
    this.infoCard,
    this.floatingActionButton,
    this.actions,
    this.onBackPressed,
    this.listWidth = 440,
  });

  /// Builds the leading back button for the AppBar if onBackPressed is provided.
  Widget? _buildLeadingButton(BuildContext context) {
    if (onBackPressed == null) return null;
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.common_action_back,
      onPressed: onBackPressed,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
    final selectionState = ref.watch(mapListSelectionProvider(sectionKey));
    final colorScheme = Theme.of(context).colorScheme;

    if (!isDesktop) {
      // Mobile: Show only map with info card overlay
      return Scaffold(
        appBar: AppBar(
          title: Semantics(header: true, child: Text(title)),
          leading: _buildLeadingButton(context),
          actions: actions,
        ),
        body: Semantics(
          label: context.l10n.accessibility_label_mapViewTitle(title),
          child: Stack(
            children: [
              mapPane,
              if (infoCard != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: _mobileInfoCardBottomOffset,
                  child: infoCard!,
                ),
            ],
          ),
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    // Desktop: Show list + map split
    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: Text(title)),
        leading: _buildLeadingButton(context),
        actions: [
          // Expand button when collapsed
          if (selectionState.isCollapsed)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: context.l10n.accessibility_label_showList,
              onPressed: () => ref
                  .read(mapListSelectionProvider(sectionKey).notifier)
                  .toggleCollapse(),
            ),
          ...?actions,
        ],
      ),
      body: FocusTraversalGroup(
        child: Row(
          children: [
            // Collapsible list pane
            Semantics(
              label: context.l10n.accessibility_label_listPane(title),
              child: CollapsibleListPane(
                isCollapsed: selectionState.isCollapsed,
                onToggle: () => ref
                    .read(mapListSelectionProvider(sectionKey).notifier)
                    .toggleCollapse(),
                width: listWidth,
                child: listPane,
              ),
            ),
            // Vertical divider
            if (!selectionState.isCollapsed)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
            // Map pane
            Expanded(
              child: Semantics(
                label: context.l10n.accessibility_label_mapPane(title),
                child: Stack(
                  children: [
                    mapPane,
                    // Info card at bottom center
                    if (infoCard != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: infoCard!,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
