import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'responsive_breakpoints.dart';

/// Mode for the detail pane in master-detail layout.
enum DetailPaneMode {
  /// Viewing item details (default)
  view,

  /// Editing an existing item
  edit,

  /// Creating a new item
  create,
}

/// A responsive master-detail layout widget.
///
/// On desktop (>=800px): Shows a split view with master (list) on the left
/// and detail/summary on the right.
///
/// On mobile (<800px): Shows only the master pane, with navigation to
/// detail pages handled by the caller.
///
/// Supports multiple modes via URL query params:
/// - `?selected=id` - View mode (detail)
/// - `?selected=id&mode=edit` - Edit mode
/// - `?mode=new` - Create mode
///
/// Example usage:
/// ```dart
/// MasterDetailScaffold(
///   sectionId: 'dives',
///   masterBuilder: (context, onSelect, selectedId) => DiveListContent(
///     onItemSelected: onSelect,
///     selectedId: selectedId,
///   ),
///   detailBuilder: (context, id) => DiveDetailContent(diveId: id),
///   summaryBuilder: (context) => DiveSummaryWidget(),
///   editBuilder: (context, id, onSaved, onCancel) => DiveEditContent(...),
///   createBuilder: (context, onSaved, onCancel) => DiveEditContent(...),
/// )
/// ```
class MasterDetailScaffold extends ConsumerStatefulWidget {
  /// Section identifier used for URL query params (e.g., 'dives', 'sites')
  final String sectionId;

  /// Builder for the master (list) pane.
  ///
  /// Receives:
  /// - [onItemSelected]: Callback to select an item (pass null to deselect)
  /// - [selectedId]: Currently selected item ID (null if none)
  final Widget Function(
    BuildContext context,
    void Function(String?) onItemSelected,
    String? selectedId,
  ) masterBuilder;

  /// Builder for the detail pane when an item is selected (view mode).
  final Widget Function(BuildContext context, String itemId) detailBuilder;

  /// Builder for the summary view when no item is selected.
  final Widget Function(BuildContext context) summaryBuilder;

  /// Builder for the edit pane when editing an existing item.
  /// If null, edit mode will navigate to the full page.
  ///
  /// Receives:
  /// - [itemId]: The ID of the item being edited
  /// - [onSaved]: Callback when save completes (pass the saved item ID)
  /// - [onCancel]: Callback when user cancels editing
  final Widget Function(
    BuildContext context,
    String itemId,
    void Function(String savedId) onSaved,
    VoidCallback onCancel,
  )? editBuilder;

  /// Builder for creating a new item.
  /// If null, create mode will navigate to the full page.
  ///
  /// Receives:
  /// - [onSaved]: Callback when save completes (pass the new item ID)
  /// - [onCancel]: Callback when user cancels creation
  final Widget Function(
    BuildContext context,
    void Function(String savedId) onSaved,
    VoidCallback onCancel,
  )? createBuilder;

  /// Floating action button for the master pane.
  final Widget? floatingActionButton;

  /// Fixed width of the master pane in pixels (default 440).
  final double masterWidth;

  /// Route path to navigate to on mobile when an item is selected.
  /// Defaults to '/$sectionId/:id'
  final String Function(String id)? mobileDetailRoute;

  /// Route path for mobile edit page. Defaults to '/$sectionId/:id/edit'
  final String Function(String id)? mobileEditRoute;

  /// Route path for mobile create page. Defaults to '/$sectionId/new'
  final String? mobileCreateRoute;

  const MasterDetailScaffold({
    super.key,
    required this.sectionId,
    required this.masterBuilder,
    required this.detailBuilder,
    required this.summaryBuilder,
    this.editBuilder,
    this.createBuilder,
    this.floatingActionButton,
    this.masterWidth = 440,
    this.mobileDetailRoute,
    this.mobileEditRoute,
    this.mobileCreateRoute,
  });

  @override
  ConsumerState<MasterDetailScaffold> createState() =>
      _MasterDetailScaffoldState();
}

class _MasterDetailScaffoldState extends ConsumerState<MasterDetailScaffold> {
  /// Get the currently selected item ID from URL query params
  String? get _selectedId {
    final state = GoRouterState.of(context);
    return state.uri.queryParameters['selected'];
  }

  /// Get the current mode from URL query params
  DetailPaneMode get _mode {
    final state = GoRouterState.of(context);
    final modeParam = state.uri.queryParameters['mode'];
    switch (modeParam) {
      case 'edit':
        return DetailPaneMode.edit;
      case 'new':
        return DetailPaneMode.create;
      default:
        return DetailPaneMode.view;
    }
  }

  /// Navigate to view mode for an item
  void _onItemSelected(String? itemId) {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;

    if (ResponsiveBreakpoints.isDesktop(context)) {
      // Desktop: Update URL with query param
      if (itemId != null) {
        router.go('$currentPath?selected=$itemId');
      } else {
        // Clear selection
        router.go(currentPath);
      }
    } else {
      // Mobile: Navigate to detail page
      if (itemId != null) {
        final route = widget.mobileDetailRoute?.call(itemId) ??
            '/${widget.sectionId}/$itemId';
        router.go(route);
      }
    }
  }

  /// Navigate to create mode
  void _onCreate() {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;

    if (ResponsiveBreakpoints.isDesktop(context) &&
        widget.createBuilder != null) {
      // Desktop with create builder: Use query params
      router.go('$currentPath?mode=new');
    } else {
      // Mobile or no create builder: Navigate to full page
      final route = widget.mobileCreateRoute ?? '/${widget.sectionId}/new';
      router.go(route);
    }
  }

  /// Handle save from edit/create mode - go back to view mode
  void _onSaved(String savedId) {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;
    router.go('$currentPath?selected=$savedId');
  }

  /// Handle cancel from edit/create mode - go back to previous state
  void _onCancel() {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;
    final selectedId = _selectedId;

    if (selectedId != null) {
      // Was editing - go back to view mode
      router.go('$currentPath?selected=$selectedId');
    } else {
      // Was creating - go back to summary
      router.go(currentPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final selectedId = _selectedId;
    final mode = _mode;

    if (!isDesktop) {
      // Mobile: Just show the master pane with Scaffold
      return Scaffold(
        body: widget.masterBuilder(context, _onItemSelected, null),
        floatingActionButton: widget.floatingActionButton != null
            ? _wrapFabForCreate(widget.floatingActionButton!)
            : null,
      );
    }

    // Desktop: Split view with fixed-width master pane
    return Scaffold(
      body: Row(
        children: [
          // Master pane (list) with fixed width
          SizedBox(
            width: widget.masterWidth,
            child: _MasterPane(
              floatingActionButton: widget.floatingActionButton != null
                  ? _wrapFabForCreate(widget.floatingActionButton!)
                  : null,
              child: widget.masterBuilder(context, _onItemSelected, selectedId),
            ),
          ),
          // Vertical divider
          const VerticalDivider(width: 1, thickness: 1),
          // Detail pane
          Expanded(
            child: _DetailPane(
              selectedId: selectedId,
              mode: mode,
              detailBuilder: widget.detailBuilder,
              summaryBuilder: widget.summaryBuilder,
              editBuilder: widget.editBuilder,
              createBuilder: widget.createBuilder,
              onClose: () => _onItemSelected(null),
              onSaved: _onSaved,
              onCancel: _onCancel,
            ),
          ),
        ],
      ),
    );
  }

  /// Wrap the FAB to use our create handler instead of direct navigation
  Widget _wrapFabForCreate(Widget fab) {
    if (fab is FloatingActionButton) {
      return FloatingActionButton(
        onPressed: _onCreate,
        tooltip: fab.tooltip,
        backgroundColor: fab.backgroundColor,
        foregroundColor: fab.foregroundColor,
        child: fab.child,
      );
    }
    if (fab is FloatingActionButton) {
      return fab;
    }
    // For FloatingActionButton.extended, wrap in a GestureDetector
    return GestureDetector(
      onTap: _onCreate,
      child: AbsorbPointer(child: fab),
    );
  }
}

/// Container for the master (list) pane with optional FAB.
class _MasterPane extends StatelessWidget {
  final Widget child;
  final Widget? floatingActionButton;

  const _MasterPane({
    required this.child,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (floatingActionButton != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: floatingActionButton!,
          ),
      ],
    );
  }
}

/// Container for the detail pane with animated transitions.
class _DetailPane extends StatelessWidget {
  final String? selectedId;
  final DetailPaneMode mode;
  final Widget Function(BuildContext context, String itemId) detailBuilder;
  final Widget Function(BuildContext context) summaryBuilder;
  final Widget Function(
    BuildContext context,
    String itemId,
    void Function(String savedId) onSaved,
    VoidCallback onCancel,
  )? editBuilder;
  final Widget Function(
    BuildContext context,
    void Function(String savedId) onSaved,
    VoidCallback onCancel,
  )? createBuilder;
  final VoidCallback onClose;
  final void Function(String savedId) onSaved;
  final VoidCallback onCancel;

  const _DetailPane({
    required this.selectedId,
    required this.mode,
    required this.detailBuilder,
    required this.summaryBuilder,
    required this.onClose,
    required this.onSaved,
    required this.onCancel,
    this.editBuilder,
    this.createBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Create mode
    if (mode == DetailPaneMode.create && createBuilder != null) {
      return KeyedSubtree(
        key: const ValueKey('create'),
        child: createBuilder!(context, onSaved, onCancel),
      );
    }

    // Edit mode with selected item
    if (mode == DetailPaneMode.edit &&
        selectedId != null &&
        editBuilder != null) {
      return KeyedSubtree(
        key: ValueKey('edit_$selectedId'),
        child: editBuilder!(context, selectedId!, onSaved, onCancel),
      );
    }

    // View mode with selected item
    if (selectedId != null) {
      return KeyedSubtree(
        key: ValueKey('detail_$selectedId'),
        child: detailBuilder(context, selectedId!),
      );
    }

    // No selection - show summary
    return KeyedSubtree(
      key: const ValueKey('summary'),
      child: summaryBuilder(context),
    );
  }
}
