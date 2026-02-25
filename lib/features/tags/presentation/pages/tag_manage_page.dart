import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_merge_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  static const _uuid = Uuid();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(tagStatisticsProvider);

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : AppBar(
              title: Text(context.l10n.tags_manage_title),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateDialog(),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (!_isSelectionMode) _buildSearchBar(),
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (stats) => _buildTagList(stats),
            ),
          ),
        ],
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

  Widget _buildTagList(List<TagStatistic> stats) {
    final filtered = _searchQuery.isEmpty
        ? stats
        : stats.where((stat) {
            final query = _searchQuery.toLowerCase();
            return stat.tag.name.toLowerCase().contains(query);
          }).toList();

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
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(tag.id),
            )
          : CircleAvatar(radius: 16, backgroundColor: tag.color),
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
      onLongPress: _isSelectionMode ? null : () => _enterSelectionMode(tag.id),
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

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text(context.l10n.tags_manage_selectedCount(_selectedIds.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.merge),
          onPressed: _selectedIds.length >= 2
              ? () => _showMergeSheet(context)
              : null,
          tooltip: context.l10n.tags_manage_mergeAction,
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: _selectedIds.isNotEmpty
              ? () => _confirmDelete(context)
              : null,
          tooltip: context.l10n.common_action_delete,
        ),
      ],
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

  void _enterSelectionMode(String? initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }
}
