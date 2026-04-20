import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_primary_provider.dart';

/// Applies a Flutter `ReorderableListView` reorder event to a movable-items
/// list while keeping a non-draggable divider at [dividerIndex].
///
/// `oldIndex` and `newIndex` are indices in the flat list that the
/// ReorderableListView sees — i.e., `movable` with a divider inserted at
/// [dividerIndex]. Returns the new order of `movable` (length unchanged).
///
/// If the user attempts to drag the divider itself, returns `movable` unchanged.
List<String> applyReorderPreservingDivider({
  required List<String> movable,
  required int dividerIndex,
  required int oldIndex,
  required int newIndex,
}) {
  // No-op if the user tried to drag the divider itself.
  if (oldIndex == dividerIndex) return movable;

  // Translate flat indices (which include the divider) into movable indices.
  int flatToMovable(int flatIndex) {
    return flatIndex > dividerIndex ? flatIndex - 1 : flatIndex;
  }

  final oldMovable = flatToMovable(oldIndex);

  // Flutter convention: when newIndex > oldIndex, the caller expects the item
  // to land at newIndex - 1 after removal. We mirror that here post-translation.
  int targetFlat = newIndex;
  if (newIndex > oldIndex) targetFlat -= 1;
  int newMovable = flatToMovable(targetFlat);

  if (newMovable < 0) newMovable = 0;
  if (newMovable > movable.length) newMovable = movable.length;

  final copy = List<String>.from(movable);
  final item = copy.removeAt(oldMovable);
  copy.insert(newMovable.clamp(0, copy.length), item);
  return copy;
}

class NavCustomizationPage extends ConsumerStatefulWidget {
  const NavCustomizationPage({super.key});

  @override
  ConsumerState<NavCustomizationPage> createState() =>
      _NavCustomizationPageState();
}

class _NavCustomizationPageState extends ConsumerState<NavCustomizationPage> {
  // Divider sits between primary (first 3 movable) and overflow.
  static const _dividerIndex = 3;

  // INVARIANT: this page is the sole writer to navPrimaryIdsProvider while mounted.
  // We hold a local mirror for drag responsiveness and only reconcile on reset.
  // Ordered movable ids local to the page. Initialized from provider on first
  // build; mutated optimistically during drags, then committed via notifier.
  List<String>? _local;

  List<String> _currentOrder(List<String> fromProvider) {
    // Build the ordered list = primary (3) then overflow in canonical order.
    final primarySet = fromProvider.toSet();
    final overflow = movableNavIds
        .where((id) => !primarySet.contains(id))
        .toList(growable: false);
    return [...fromProvider, ...overflow];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Reconcile local mirror when the provider emits a different primary id
    // list than what we're displaying. This handles the cold-start race where
    // NavPrimaryIdsNotifier starts with defaults synchronously and emits the
    // stored customization once the async _load() completes; without this,
    // _local would stay frozen on defaults until the user interacted.
    ref.listen<List<String>>(navPrimaryIdsProvider, (previous, next) {
      if (previous == next) return;
      final currentPrimary = _local?.take(3).toList();
      if (currentPrimary != null && listEquals(currentPrimary, next)) {
        return; // already in sync (e.g., mid-drag we just committed)
      }
      setState(() {
        _local = _currentOrder(next);
      });
    });

    final primaryIds = ref.watch(navPrimaryIdsProvider);
    final destinationsById = {
      for (final d in ref.watch(navDestinationsProvider)) d.id: d,
    };

    _local ??= _currentOrder(primaryIds);

    final listIsDefault = listEquals(primaryIds, kDefaultPrimaryIds);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_navCustomization_title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.settings_navCustomization_description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          // Pinned Home row (outside the reorderable list).
          _pinnedTile(context, destinationsById['dashboard']!),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _local!.length + 1, // +1 for divider
              itemBuilder: (context, flatIndex) {
                if (flatIndex == _dividerIndex) {
                  return _buildDivider(context);
                }
                final movableIndex = flatIndex < _dividerIndex
                    ? flatIndex
                    : flatIndex - 1;
                final id = _local![movableIndex];
                final destination = destinationsById[id]!;
                return _buildMovableTile(
                  context: context,
                  key: ValueKey('nav-item-$id'),
                  index: flatIndex,
                  destination: destination,
                );
              },
              onReorder: _commitReorder,
            ),
          ),
          const Divider(height: 1),
          _pinnedTile(context, destinationsById['more']!),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton.icon(
                icon: const Icon(Icons.restore),
                label: Text(l10n.settings_navCustomization_resetButton),
                onPressed: listIsDefault
                    ? null
                    : () async {
                        await ref
                            .read(navPrimaryIdsNotifierProvider.notifier)
                            .resetToDefaults();
                        setState(() => _local = null);
                      },
              ),
            ),
          ),
        ],
      ),
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
            onPressed: index == _local!.length ? null : () => _moveDown(index),
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
    final target = index == _dividerIndex + 1 ? _dividerIndex - 1 : index - 1;
    _commitReorder(index, target);
  }

  void _moveDown(int index) {
    // When stepping across the divider, skip over it to the slot below.
    final target = index == _dividerIndex - 1 ? _dividerIndex + 2 : index + 2;
    _commitReorder(index, target);
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
    if (identical(newList, previous)) return; // no-op reorder
    setState(() => _local = newList);
    try {
      await ref
          .read(navPrimaryIdsNotifierProvider.notifier)
          .setPrimaryIds(newList.take(3).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _local = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.settings_navCustomization_saveError),
        ),
      );
    }
  }
}
