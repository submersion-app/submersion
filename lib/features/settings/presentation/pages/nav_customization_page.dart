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
    final primaryIds = ref.watch(navPrimaryIdsProvider);
    final destinationsById = {
      for (final d in ref.watch(navDestinationsProvider)) d.id: d,
    };

    _local ??= _currentOrder(primaryIds);

    final listIsDefault =
        primaryIds.toList().toString() ==
        kDefaultPrimaryIds.toList().toString();

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
              onReorder: (oldIndex, newIndex) {
                final newList = applyReorderPreservingDivider(
                  movable: _local!,
                  dividerIndex: _dividerIndex,
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                );
                setState(() => _local = newList);
                // Commit the top 3 as the new primary ids.
                ref
                    .read(navPrimaryIdsNotifierProvider.notifier)
                    .setPrimaryIds(newList.take(3).toList());
              },
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
            onPressed: index == 0
                ? null
                : () => _onReorderByButton(index, index - 1),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: l10n.settings_navCustomization_moveDownLabel(
              destination.label(l10n),
            ),
            onPressed: index >= _local!.length
                ? null
                : () => _onReorderByButton(index, index + 2),
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

  void _onReorderByButton(int oldIndex, int newIndex) {
    final newList = applyReorderPreservingDivider(
      movable: _local!,
      dividerIndex: _dividerIndex,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    setState(() => _local = newList);
    ref
        .read(navPrimaryIdsNotifierProvider.notifier)
        .setPrimaryIds(newList.take(3).toList());
  }
}
