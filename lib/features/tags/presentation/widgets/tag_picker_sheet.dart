import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet listing tags the diver has used before, so tagging stays
/// consistent without having to remember earlier spellings (#1171).
///
/// Mirrors the equipment picker's placement and chrome, but multi-select:
/// tags are cheap to add in batches, so the sheet accumulates ticks and
/// reports them in a single [onTagsPicked] call.
///
/// Tags already on the dive are omitted entirely -- every row in the list is
/// an addition, which is what lets the confirm button count ticks.
class TagPickerSheet extends ConsumerStatefulWidget {
  const TagPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedTagIds,
    required this.onTagsPicked,
  });

  /// Supplied by the enclosing [DraggableScrollableSheet] so dragging the
  /// list also resizes the sheet.
  final ScrollController scrollController;

  /// Tags already attached, filtered out of the list.
  final Set<String> selectedTagIds;

  /// Called with the ticked tags, most-used first.
  final void Function(List<Tag> tags) onTagsPicked;

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  final _searchController = TextEditingController();
  final _pickedIds = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String tagId) {
    setState(() {
      if (!_pickedIds.remove(tagId)) _pickedIds.add(tagId);
    });
  }

  /// Picked tags in the provider's most-used-first order rather than the
  /// order they happened to be ticked in.
  List<Tag> _pickedFrom(List<TagStatistic> stats) => [
    for (final stat in stats)
      if (_pickedIds.contains(stat.tag.id)) stat.tag,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Already ordered `dive_count DESC, name`, which is exactly the
    // "tags you use most" ordering this sheet wants.
    final statsAsync = ref.watch(tagStatisticsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.tags_picker_title, style: theme.textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.common_action_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.tags_manage_searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: statsAsync.when(
            data: (stats) => _buildList(context, stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.tags_picker_errorLoading(error.toString()),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _pickedIds.isEmpty
                  ? null
                  : () => widget.onTagsPicked(
                      _pickedFrom(statsAsync.valueOrNull ?? const []),
                    ),
              child: Text(l10n.tags_picker_addCount(_pickedIds.length)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<TagStatistic> stats) {
    final available = stats
        .where((stat) => !widget.selectedTagIds.contains(stat.tag.id))
        .toList();

    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? available
        : available
              .where((stat) => stat.tag.name.toLowerCase().contains(query))
              .toList();

    if (visible.isEmpty) {
      return _EmptyState(
        icon: stats.isEmpty ? Icons.label_outline : Icons.search_off,
        message: stats.isEmpty
            ? context.l10n.tags_picker_empty
            : available.isEmpty
            ? context.l10n.tags_picker_allAdded
            : context.l10n.tags_picker_noMatches,
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final stat = visible[index];
        return CheckboxListTile(
          value: _pickedIds.contains(stat.tag.id),
          onChanged: (_) => _toggle(stat.tag.id),
          controlAffinity: ListTileControlAffinity.trailing,
          secondary: CircleAvatar(radius: 12, backgroundColor: stat.tag.color),
          title: Text(stat.tag.name),
          subtitle: Text(context.l10n.tags_manage_diveCount(stat.diveCount)),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
