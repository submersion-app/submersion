import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The documents list's tag filter (issue #1970): one chip per tag, any of
/// the selected ones matches. Lists every tag some document carries plus any
/// tag still selected, so a filter on a tag that has since gone stays
/// clearable from here. Renders nothing when there is nothing to offer.
class DocumentTagFilterRow extends StatelessWidget {
  const DocumentTagFilterRow({
    super.key,
    required this.tags,
    required this.selectedIds,
    required this.onChanged,
  });

  /// The tags to offer, in display order.
  final List<Tag> tags;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final (i, tag) in tags.indexed)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: FilterChip(
                key: ValueKey('documents-filter-tag-${tag.id}'),
                avatar: CircleAvatar(backgroundColor: tag.color, radius: 6),
                label: Text(tag.name),
                selected: selectedIds.contains(tag.id),
                onSelected: (on) => onChanged(
                  on
                      ? {...selectedIds, tag.id}
                      : selectedIds.where((id) => id != tag.id).toSet(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
