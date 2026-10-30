import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One section's items for [SectionListEditor]. Items are already in their
/// desired display order; the editor only reorders by id, never compares
/// items for equality.
class SectionGroup<T> {
  final String id;
  final String title;
  final List<T> items;

  const SectionGroup({
    required this.id,
    required this.title,
    required this.items,
  });
}

/// Payload for an in-flight item drag: the item's id and the section it is
/// currently in (null for the unsectioned bucket), so the drop target knows
/// what it is moving without re-deriving it from [SectionListEditor.sections].
class _ItemDrag {
  final String itemId;
  final String? sectionId;
  const _ItemDrag(this.itemId, this.sectionId);
}

enum _DeleteChoice { deleteItems, move }

/// Shared editor for a list of items grouped under manageable sections
/// (issue #3360): a section can be created empty, renamed, reordered and
/// deleted with an explicit items-too-or-move-elsewhere choice, and an item
/// can be moved within or across sections. Used by the trip checklist, the
/// checklist template editor and the pre-dive template editor so this
/// drag/arrow/delete-dialog logic exists exactly once.
///
/// Stateless with respect to the list itself: [sections] and
/// [unsectionedItems] are rendered as given, and every mutation goes back
/// out through a callback. The caller decides whether that callback persists
/// immediately (a live trip's repository calls) or only updates in-memory
/// draft state (a template editor's save-at-the-end flow) -- the editor does
/// not know or care which.
class SectionListEditor<T> extends StatefulWidget {
  final List<SectionGroup<T>> sections;
  final List<T> unsectionedItems;
  final String Function(T item) itemId;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String addSectionLabel;
  final String newSectionTitle;
  final String noSectionLabel;

  /// Suppresses every section-management affordance (drag, arrows, rename
  /// field, delete icon, add-section button): a built-in template's sections
  /// are shared across every diver and must render read-only, the same way
  /// its items already withhold their own edit/delete controls.
  final bool readOnly;
  final Future<void> Function(String title) onAddSection;
  final Future<void> Function(String sectionId, String title) onRenameSection;
  final Future<void> Function(List<String> orderedSectionIds) onReorderSections;
  final Future<void> Function(String sectionId, {String? moveItemsToSectionId})
  onDeleteSection;
  final Future<void> Function(
    String itemId,
    String? targetSectionId,
    List<String> orderedIds,
  )
  onMoveItem;
  final Future<void> Function(T item) onDeleteItem;

  const SectionListEditor({
    super.key,
    required this.sections,
    this.unsectionedItems = const [],
    required this.itemId,
    required this.itemBuilder,
    required this.addSectionLabel,
    required this.newSectionTitle,
    required this.noSectionLabel,
    this.readOnly = false,
    required this.onAddSection,
    required this.onRenameSection,
    required this.onReorderSections,
    required this.onDeleteSection,
    required this.onMoveItem,
    required this.onDeleteItem,
  });

  @override
  State<SectionListEditor<T>> createState() => _SectionListEditorState<T>();
}

class _SectionListEditorState<T> extends State<SectionListEditor<T>> {
  final Map<String, TextEditingController> _titleControllers = {};
  final Map<String, FocusNode> _titleFocusNodes = {};

  @override
  void didUpdateWidget(SectionListEditor<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.sections.map((s) => s.id).toSet();
    for (final id in _titleControllers.keys.toList()) {
      if (!currentIds.contains(id)) {
        _titleControllers.remove(id)?.dispose();
        _titleFocusNodes.remove(id)?.dispose();
      }
    }
    for (final section in widget.sections) {
      final controller = _titleControllers[section.id];
      final focusNode = _titleFocusNodes[section.id];
      if (controller != null &&
          focusNode != null &&
          !focusNode.hasFocus &&
          controller.text != section.title) {
        controller.text = section.title;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    for (final f in _titleFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(SectionGroup<T> section) =>
      _titleControllers.putIfAbsent(
        section.id,
        () => TextEditingController(text: section.title),
      );

  // The listener captures only the id: the SectionGroup it was created from
  // goes stale after the first rename, and comparing against that stale
  // title would drop a rename back to it.
  FocusNode _focusNodeFor(SectionGroup<T> section) =>
      _titleFocusNodes.putIfAbsent(section.id, () {
        final sectionId = section.id;
        final node = FocusNode();
        node.addListener(() {
          if (!node.hasFocus) _commitRename(sectionId);
        });
        return node;
      });

  /// The single commit path for a title edit, run when the field loses
  /// focus. Submitting the field only unfocuses it, so Enter followed by the
  /// resulting blur cannot send the same rename twice.
  void _commitRename(String sectionId) {
    if (!mounted) return;
    final controller = _titleControllers[sectionId];
    final section = widget.sections.where((s) => s.id == sectionId).firstOrNull;
    if (controller == null || section == null) return;
    final trimmed = controller.text.trim();
    if (trimmed.isEmpty || trimmed == section.title) {
      controller.text = section.title;
      return;
    }
    widget.onRenameSection(section.id, trimmed);
  }

  List<String> _orderedIdsAfterMoving(
    String itemId,
    String? targetSectionId,
    String? beforeItemId,
  ) {
    List<String> idsOf(List<T> items) => [
      for (final item in items)
        if (widget.itemId(item) != itemId) widget.itemId(item),
    ];
    // Each bucket without the moved item; the target bucket then gets it
    // back before beforeItemId (or at its end), all as new lists.
    List<String> withMoved(List<String> bucket) {
      final at = beforeItemId == null ? -1 : bucket.indexOf(beforeItemId);
      final insertAt = at < 0 ? bucket.length : at;
      return [...bucket.take(insertAt), itemId, ...bucket.skip(insertAt)];
    }

    return [
      for (final s in widget.sections)
        ...(s.id == targetSectionId
            ? withMoved(idsOf(s.items))
            : idsOf(s.items)),
      ...(targetSectionId == null
          ? withMoved(idsOf(widget.unsectionedItems))
          : idsOf(widget.unsectionedItems)),
    ];
  }

  T? _findItem(String itemId, String? sectionId) {
    final bucket = sectionId == null
        ? widget.unsectionedItems
        : widget.sections.where((s) => s.id == sectionId).firstOrNull?.items;
    if (bucket == null) return null;
    for (final item in bucket) {
      if (widget.itemId(item) == itemId) return item;
    }
    return null;
  }

  Future<void> _moveItem(
    T item,
    String? currentSectionId,
    String? targetSectionId,
    String? beforeItemId,
  ) async {
    final id = widget.itemId(item);
    if (currentSectionId == targetSectionId && beforeItemId == id) return;
    final orderedIds = _orderedIdsAfterMoving(
      id,
      targetSectionId,
      beforeItemId,
    );
    await widget.onMoveItem(id, targetSectionId, orderedIds);
  }

  void _nudgeItem(List<T> bucket, String? sectionId, T item, int direction) {
    final idx = bucket.indexOf(item);
    final targetIdx = idx + direction;
    if (idx < 0 || targetIdx < 0 || targetIdx >= bucket.length) return;
    final String? beforeId;
    if (direction < 0) {
      beforeId = widget.itemId(bucket[targetIdx]);
    } else {
      beforeId = targetIdx + 1 < bucket.length
          ? widget.itemId(bucket[targetIdx + 1])
          : null;
    }
    _moveItem(item, sectionId, sectionId, beforeId);
  }

  Future<void> _reorderSection(String draggedId, String targetId) async {
    if (draggedId == targetId) return;
    final ids = [for (final s in widget.sections) s.id];
    final fromIdx = ids.indexOf(draggedId);
    final toIdx = ids.indexOf(targetId);
    if (fromIdx < 0 || toIdx < 0) return;
    // The dragged id takes the target's index, shifting the rest: the same
    // result as removeAt(fromIdx) then insert(toIdx), built as a new list.
    final without = [
      for (final id in ids)
        if (id != draggedId) id,
    ];
    await widget.onReorderSections([
      ...without.take(toIdx),
      draggedId,
      ...without.skip(toIdx),
    ]);
  }

  void _nudgeSection(SectionGroup<T> section, int direction) {
    final idx = widget.sections.indexOf(section);
    final targetIdx = idx + direction;
    if (idx < 0 || targetIdx < 0 || targetIdx >= widget.sections.length) {
      return;
    }
    _reorderSection(section.id, widget.sections[targetIdx].id);
  }

  Future<void> _confirmDeleteSection(SectionGroup<T> section) async {
    if (widget.sections.length <= 1) return;
    final l10n = context.l10n;
    final idx = widget.sections.indexOf(section);
    final adjacent = idx > 0
        ? widget.sections[idx - 1]
        : (idx < widget.sections.length - 1 ? widget.sections[idx + 1] : null);

    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sectionEditor_delete_title(section.title)),
        content: Text(l10n.sectionEditor_delete_content(section.items.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          if (adjacent != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteChoice.move),
              child: Text(l10n.sectionEditor_delete_moveTo(adjacent.title)),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DeleteChoice.deleteItems),
            child: Text(l10n.sectionEditor_delete_deleteItems),
          ),
        ],
      ),
    );
    if (choice == _DeleteChoice.move && adjacent != null) {
      await widget.onDeleteSection(
        section.id,
        moveItemsToSectionId: adjacent.id,
      );
    } else if (choice == _DeleteChoice.deleteItems) {
      await widget.onDeleteSection(section.id);
    }
  }

  Future<void> _addSection() => widget.onAddSection(widget.newSectionTitle);

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) return _buildReadOnly(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in widget.sections) _buildSection(section),
        if (widget.unsectionedItems.isNotEmpty)
          _buildUnsectionedGroup(widget.unsectionedItems),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(widget.addSectionLabel),
          onPressed: _addSection,
        ),
      ],
    );
  }

  Widget _buildReadOnly(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in widget.sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
            child: Text(
              section.title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          for (final item in section.items) widget.itemBuilder(context, item),
        ],
        if (widget.unsectionedItems.isNotEmpty)
          for (final item in widget.unsectionedItems)
            widget.itemBuilder(context, item),
      ],
    );
  }

  Widget _buildSection(SectionGroup<T> section) {
    final idx = widget.sections.indexOf(section);
    final canDelete = widget.sections.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DragTarget<_ItemDrag>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) {
          final dragged = details.data;
          if (dragged.sectionId == section.id) return;
          final item = _findItem(dragged.itemId, dragged.sectionId);
          if (item == null) return;
          _moveItem(item, dragged.sectionId, section.id, null);
        },
        builder: (context, candidateItems, rejectedItems) {
          return DragTarget<String>(
            onWillAcceptWithDetails: (details) => details.data != section.id,
            onAcceptWithDetails: (details) =>
                _reorderSection(details.data, section.id),
            builder: (context, candidateSections, rejectedSections) {
              final highlighted =
                  candidateItems.isNotEmpty || candidateSections.isNotEmpty;
              final theme = Theme.of(context);
              return Card(
                color: highlighted
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllerFor(section),
                              focusNode: _focusNodeFor(section),
                              onSubmitted: (_) =>
                                  _titleFocusNodes[section.id]?.unfocus(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).deleteButtonTooltip,
                            onPressed: canDelete
                                ? () => _confirmDeleteSection(section)
                                : null,
                          ),
                          _ReorderArrows(
                            canMoveUp: idx > 0,
                            canMoveDown: idx < widget.sections.length - 1,
                            onMoveUp: () => _nudgeSection(section, -1),
                            onMoveDown: () => _nudgeSection(section, 1),
                          ),
                          Draggable<String>(
                            data: section.id,
                            feedback: Material(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(section.title),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                      for (final item in section.items)
                        _buildItemRow(item, section.items, section.id),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUnsectionedGroup(List<T> items) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.noSectionLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final item in items) _buildItemRow(item, items, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(T item, List<T> bucket, String? sectionId) {
    final id = widget.itemId(item);
    final idx = bucket.indexOf(item);
    return DragTarget<_ItemDrag>(
      onWillAcceptWithDetails: (details) => details.data.itemId != id,
      onAcceptWithDetails: (details) {
        final dragged = details.data;
        final draggedItem = _findItem(dragged.itemId, dragged.sectionId);
        if (draggedItem == null) return;
        _moveItem(draggedItem, dragged.sectionId, sectionId, id);
      },
      builder: (context, candidate, rejected) {
        return Container(
          color: candidate.isNotEmpty
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: Row(
            children: [
              Expanded(child: widget.itemBuilder(context, item)),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () => widget.onDeleteItem(item),
              ),
              _ReorderArrows(
                canMoveUp: idx > 0,
                canMoveDown: idx < bucket.length - 1,
                onMoveUp: () => _nudgeItem(bucket, sectionId, item, -1),
                onMoveDown: () => _nudgeItem(bucket, sectionId, item, 1),
              ),
              Draggable<_ItemDrag>(
                data: _ItemDrag(id, sectionId),
                feedback: Material(
                  elevation: 4,
                  child: SizedBox(
                    width: 240,
                    child: widget.itemBuilder(context, item),
                  ),
                ),
                childWhenDragging: const Opacity(
                  opacity: 0.3,
                  child: Icon(Icons.drag_handle),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Up/down nudge buttons, laid out side by side so they sit in a row's
/// trailing area alongside a delete button and drag handle (matching
/// NavOrderEditor's reorder-row convention) rather than stacked.
class _ReorderArrows extends StatelessWidget {
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _ReorderArrows({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = WidgetsLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          tooltip: localizations.reorderItemUp,
          visualDensity: VisualDensity.compact,
          onPressed: canMoveUp ? onMoveUp : null,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          tooltip: localizations.reorderItemDown,
          visualDensity: VisualDensity.compact,
          onPressed: canMoveDown ? onMoveDown : null,
        ),
      ],
    );
  }
}
