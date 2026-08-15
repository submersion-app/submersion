import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_merge_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_state.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// Owns the bulk-selection state machine for this page.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  static const _uuid = Uuid();

  @override
  void dispose() {
    _searchController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(tagStatisticsProvider);
    final visibleIds = _visibleStats(
      statsAsync.valueOrNull ?? const [],
    ).map((s) => s.tag.id).toList();

    // Drop checked tags that the search query hid, so a bulk delete can never
    // reach a tag that is not on screen. pruneTo is a no-op when nothing
    // changed, which keeps this off a rebuild loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? _buildSelectionAppBar(statsAsync.valueOrNull ?? const [])
              : AppBar(
                  title: Text(context.l10n.tags_manage_title),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                  ],
                ),
          floatingActionButton: selection.isActive
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showCreateDialog(),
                  tooltip: context.l10n.tags_manage_createTitle,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.tags_manage_createTitle),
                ),
          body: Column(
            children: [
              // Search stays visible during selection: narrowing the list
              // mid-selection is a supported move, and the selection prunes
              // to whatever remains.
              _buildSearchBar(),
              Expanded(
                child: statsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                  data: (stats) => _buildTagList(stats),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: context.l10n.tags_manage_searchHint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  /// Tags matching the current search query.
  ///
  /// Shared by the list and by the pruning in [build], so the selection can
  /// never hold a tag the query has hidden.
  List<TagStatistic> _visibleStats(List<TagStatistic> stats) {
    if (_searchQuery.isEmpty) return stats;
    final query = _searchQuery.toLowerCase();
    return stats
        .where((stat) => stat.tag.name.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildTagList(List<TagStatistic> stats) {
    final filtered = _visibleStats(stats);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          context.l10n.tags_manage_emptyState,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final stat = filtered[index];
        return _buildTagRow(stat);
      },
    );
  }

  Widget _buildTagRow(TagStatistic stat) {
    final tag = stat.tag;
    final isSelected = _selectedIds.contains(tag.id);

    return ListTile(
      leading: SelectionLeading(
        isSelectionMode: _isSelectionMode,
        isChecked: isSelected,
        onChanged: (_) => _toggleSelection(tag.id),
        child: CircleAvatar(radius: 16, backgroundColor: tag.color),
      ),
      title: Text(tag.name),
      trailing: Text(
        context.l10n.tags_manage_diveCount(stat.diveCount),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      selected: isSelected,
      onTap: _isSelectionMode
          ? () => _toggleSelection(tag.id)
          : () => _showEditDialog(tag),
    );
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    String selectedColor = TagColors.predefined.first;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.tags_manage_createTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.tags_manage_nameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(context.l10n.tags_manage_colorLabel),
              const SizedBox(height: 8),
              TagColorPicker(
                selectedColor: selectedColor,
                onColorSelected: (color) =>
                    setDialogState(() => selectedColor = color),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final newTag = Tag.create(
                    id: _uuid.v4(),
                    name: name,
                    colorHex: selectedColor,
                  );
                  ref.read(tagListNotifierProvider.notifier).addTag(newTag);
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(context.l10n.common_action_save),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Tag tag) {
    final controller = TextEditingController(text: tag.name);
    String selectedColor = tag.colorHex ?? TagColors.predefined.first;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.tags_manage_editTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.tags_manage_nameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(context.l10n.tags_manage_colorLabel),
              const SizedBox(height: 8),
              TagColorPicker(
                selectedColor: selectedColor,
                onColorSelected: (color) =>
                    setDialogState(() => selectedColor = color),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  ref
                      .read(tagListNotifierProvider.notifier)
                      .updateTag(
                        tag.copyWith(
                          name: name,
                          colorHex: selectedColor,
                          updatedAt: DateTime.now(),
                        ),
                      );
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(context.l10n.common_action_save),
            ),
          ],
        ),
      ),
    );
  }

  // -- Selection mode --

  /// Tag-specific extras. Select-all, deselect-all and delete are supplied by
  /// SelectionAppBar -- this page had neither select-all nor deselect-all
  /// before, and gains both from the shared bar.
  List<BulkAction> _bulkActions(List<TagStatistic> stats) {
    return [
      BulkAction(
        id: 'merge',
        // Canonical merge glyph. This page used Icons.merge while sites and
        // buddies used Icons.merge_type for the same concept.
        icon: Icons.merge_type,
        label: context.l10n.tags_manage_mergeAction,
        minCount: 2,
        onInvoke: () => _showMergeSheet(context),
      ),
    ];
  }

  SelectionAppBar _buildSelectionAppBar(List<TagStatistic> stats) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: _visibleStats(stats).map((s) => s.tag.id).toList(),
      actions: _bulkActions(stats),
      shell: SelectionBarShell.appBar,
      onDelete: () => _confirmDelete(context),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final repository = ref.read(tagRepositoryProvider);
    final statsAsync = ref.read(tagStatisticsProvider);
    final stats = statsAsync.valueOrNull ?? [];

    if (_selectedIds.length == 1) {
      final tagId = _selectedIds.first;
      final stat = stats.firstWhere((s) => s.tag.id == tagId);
      final count = stat.diveCount;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.tags_manage_deleteTitle),
          content: Text(
            ctx.l10n.tags_manage_deleteMessage(stat.tag.name, count),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(ctx.l10n.common_action_delete),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(tagListNotifierProvider.notifier).deleteTag(tagId);
        _exitSelectionMode();
      }
    } else {
      final totalDives = await repository.getMergedDiveCount(
        _selectedIds.toList(),
      );

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            ctx.l10n.tags_manage_bulkDeleteTitle(_selectedIds.length),
          ),
          content: Text(ctx.l10n.tags_manage_bulkDeleteMessage(totalDives)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(ctx.l10n.common_action_delete),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref
            .read(tagListNotifierProvider.notifier)
            .deleteTags(_selectedIds.toList());
        _exitSelectionMode();
      }
    }
  }

  Future<void> _showMergeSheet(BuildContext context) async {
    final statsAsync = ref.read(tagStatisticsProvider);
    final stats = statsAsync.valueOrNull ?? [];
    final selectedStats = stats
        .where((s) => _selectedIds.contains(s.tag.id))
        .toList();

    if (selectedStats.length < 2) return;

    final merged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagMergeSheet(selectedStats: selectedStats),
    );

    if (merged == true) {
      _exitSelectionMode();
    }
  }

  void _exitSelectionMode() => _selection.exit();

  void _toggleSelection(String id) => _selection.toggle(id);
}
