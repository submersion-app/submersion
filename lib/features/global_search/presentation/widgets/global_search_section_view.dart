import 'package:flutter/material.dart';

import 'package:submersion/features/global_search/data/global_search_sources.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_labels.dart';
import 'package:submersion/features/global_search/presentation/widgets/global_search_rows.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One record type's matches: a heading with the total, the first rows, and
/// a way to the rest.
class GlobalSearchSectionView extends StatefulWidget {
  const GlobalSearchSectionView({
    super.key,
    required this.section,
    required this.onOpen,
    this.onSeeAll,
  });

  final GlobalSearchSection section;

  /// Opens the record with this id.
  final ValueChanged<String> onOpen;

  /// Opens the list. Null for a type with no list, which holds every match
  /// already and expands in place.
  final VoidCallback? onSeeAll;

  @override
  State<GlobalSearchSectionView> createState() =>
      _GlobalSearchSectionViewState();
}

class _GlobalSearchSectionViewState extends State<GlobalSearchSectionView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ids = _expanded
        ? section.ids
        : section.ids.take(kGlobalSearchPreviewLimit).toList();
    final hasMore = section.total > kGlobalSearchPreviewLimit && !_expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Semantics(
            header: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    globalSearchKindIcon(section.kind),
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    globalSearchKindLabel(l10n, section.kind),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${section.total}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        GlobalSearchRows(kind: section.kind, ids: ids, onOpen: widget.onOpen),
        if (hasMore)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: TextButton(
                key: ValueKey('global-search-more-${section.kind.name}'),
                onPressed:
                    widget.onSeeAll ?? () => setState(() => _expanded = true),
                child: Text(l10n.globalSearch_seeAll(section.total)),
              ),
            ),
          ),
      ],
    );
  }
}
