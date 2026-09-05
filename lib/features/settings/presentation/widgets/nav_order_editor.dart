import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_order_provider.dart';

/// Which navigation surface an editor is arranging.
///
/// The two orders are stored separately, so a phone bottom bar and a desktop
/// rail can be arranged independently on the same account.
enum NavOrderScope {
  /// Phone: the first [kPhonePrimarySlotCount] rows are bottom-bar slots and
  /// the rest is the More menu, which is why this scope shows a divider.
  phone,

  /// Wide screens: one flat rail with no overflow, so no divider.
  desktop,
}

/// Applies a Flutter `ReorderableListView` reorder event to a movable-items
/// list while keeping a non-draggable divider at [dividerIndex].
///
/// `oldIndex` and `newIndex` are indices in the flat list that the
/// ReorderableListView sees, i.e. `movable` with a divider inserted at
/// [dividerIndex]. Pass a null [dividerIndex] when the list has no divider, in
/// which case flat indices and movable indices are the same thing. Returns the
/// new order of `movable` (length unchanged).
///
/// If the user attempts to drag the divider itself, returns `movable` unchanged.
List<String> applyReorderPreservingDivider({
  required List<String> movable,
  required int? dividerIndex,
  required int oldIndex,
  required int newIndex,
}) {
  if (dividerIndex == null) {
    return _moveItem(movable, from: oldIndex, to: newIndex);
  }

  // No-op if the user tried to drag the divider itself.
  if (oldIndex == dividerIndex) return movable;

  // Translate flat indices (which include the divider) into movable indices.
  int flatToMovable(int flatIndex) {
    return flatIndex > dividerIndex ? flatIndex - 1 : flatIndex;
  }

  // onReorderItem already adjusts newIndex for the removed item, so both
  // indices translate straight into movable-index space.
  return _moveItem(
    movable,
    from: flatToMovable(oldIndex),
    to: flatToMovable(newIndex),
  );
}

List<String> _moveItem(
  List<String> items, {
  required int from,
  required int to,
}) {
  if (from < 0 || from >= items.length) return items;
  final copy = List<String>.from(items);
  final item = copy.removeAt(from);
  copy.insert(to.clamp(0, copy.length), item);
  return copy;
}

/// Reorderable list for one navigation surface, with the pinned rows that
/// bracket it and a reset control.
///
/// Give each instance a key tied to its [scope] so switching surfaces rebuilds
/// the local mirror from the right provider instead of carrying the old order
/// across.
class NavOrderEditor extends ConsumerStatefulWidget {
  const NavOrderEditor({super.key, required this.scope});

  final NavOrderScope scope;

  @override
  ConsumerState<NavOrderEditor> createState() => _NavOrderEditorState();
}

class _NavOrderEditorState extends ConsumerState<NavOrderEditor> {
  // INVARIANT: this editor is the sole writer to its provider while mounted.
  // We hold a local mirror for drag responsiveness and reconcile from the
  // provider only when it diverges.
  List<String>? _local;

  bool get _isPhone => widget.scope == NavOrderScope.phone;

  StateNotifierProvider<NavOrderNotifier, List<String>> get _orderProvider =>
      _isPhone ? navPhoneOrderNotifierProvider : navRailOrderNotifierProvider;

  /// Flat index of the non-draggable divider row, or null when the surface has
  /// no overflow to divide off.
  int? get _dividerIndex => _isPhone ? kPhonePrimarySlotCount : null;

  /// Number of rows the ReorderableListView shows, divider included.
  int get _flatCount => _local!.length + (_dividerIndex == null ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Reconcile the local mirror when the provider emits a different order
    // than the one on screen. This covers the cold-start race where the
    // notifier starts on the canonical order synchronously and emits the
    // stored customization once its async load completes; without this,
    // _local would stay frozen on defaults until the user interacted.
    ref.listen<List<String>>(_orderProvider, (previous, next) {
      if (listEquals(_local, next)) return;
      setState(() => _local = List<String>.from(next));
    });

    final order = ref.watch(_orderProvider);
    final destinationsById = {
      for (final d in ref.watch(navDestinationsProvider)) d.id: d,
    };

    _local ??= List<String>.from(order);

    final dividerIndex = _dividerIndex;
    // Judged against the mirror, not the provider, so the button tracks the
    // list the user is looking at during an optimistic drag rather than the
    // last value that finished persisting.
    final listIsDefault = listEquals(_local, kDefaultNavOrder);

    return Column(
      children: [
        // Pinned Home row (outside the reorderable list).
        _pinnedTile(context, destinationsById['dashboard']!),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: _flatCount,
            itemBuilder: (context, flatIndex) {
              if (flatIndex == dividerIndex) return _buildDivider(context);
              final movableIndex =
                  dividerIndex == null || flatIndex < dividerIndex
                  ? flatIndex
                  : flatIndex - 1;
              final id = _local![movableIndex];
              return _buildMovableTile(
                context: context,
                key: ValueKey('nav-item-$id'),
                index: flatIndex,
                destination: destinationsById[id]!,
              );
            },
            onReorderItem: _commitReorder,
          ),
        ),
        const Divider(height: 1),
        // Only phone has a More control to pin below the list.
        if (_isPhone) _pinnedTile(context, destinationsById['more']!),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              icon: const Icon(Icons.restore),
              label: Text(l10n.settings_navCustomization_resetButton),
              onPressed: listIsDefault ? null : _reset,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pinnedTile(BuildContext context, NavDestination destination) {
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(destination.icon),
      title: Text(destination.label(l10n)),
      trailing: Tooltip(
        message: l10n.settings_navCustomization_pinnedTooltip,
        child: const Icon(Icons.lock_outline),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('nav-divider'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        l10n.settings_navCustomization_dividerLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMovableTile({
    required BuildContext context,
    required Key key,
    required int index,
    required NavDestination destination,
  }) {
    final l10n = context.l10n;
    return ListTile(
      key: key,
      leading: Icon(destination.icon),
      title: Text(destination.label(l10n)),
      subtitle: destination.subtitle != null
          ? Text(destination.subtitle!(l10n))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: l10n.settings_navCustomization_moveUpLabel(
              destination.label(l10n),
            ),
            onPressed: index == 0 ? null : () => _moveUp(index),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: l10n.settings_navCustomization_moveDownLabel(
              destination.label(l10n),
            ),
            onPressed: index == _flatCount - 1 ? null : () => _moveDown(index),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }

  void _moveUp(int index) {
    // When stepping across the divider, skip over it to the slot above.
    final divider = _dividerIndex;
    final target = (divider != null && index == divider + 1)
        ? divider - 1
        : index - 1;
    _commitReorder(index, target);
  }

  void _moveDown(int index) {
    // applyReorderPreservingDivider expects onReorderItem-style indices
    // (already adjusted for the removed item), so the slot below is index + 1;
    // stepping across the divider lands at dividerIndex + 1.
    final divider = _dividerIndex;
    final target = (divider != null && index == divider - 1)
        ? divider + 1
        : index + 1;
    _commitReorder(index, target);
  }

  Future<void> _reset() async {
    final previous = _local;
    try {
      await ref.read(_orderProvider.notifier).resetToDefaults();
      if (!mounted) return;
      setState(() => _local = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _local = previous);
      _showSaveError();
    }
  }

  /// Shared reorder commit path for both the drag handle and the move-up /
  /// move-down buttons. Optimistically updates the local mirror, writes
  /// through to the notifier, and rolls back with a SnackBar on failure.
  Future<void> _commitReorder(int oldIndex, int newIndex) async {
    final previous = _local!;
    final newList = applyReorderPreservingDivider(
      movable: previous,
      dividerIndex: _dividerIndex,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (listEquals(newList, previous)) return; // no-op reorder
    setState(() => _local = newList);
    try {
      await ref.read(_orderProvider.notifier).setOrder(newList);
    } catch (_) {
      if (!mounted) return;
      setState(() => _local = previous);
      _showSaveError();
    }
  }

  void _showSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settings_navCustomization_saveError)),
    );
  }
}
