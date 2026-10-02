import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_group_tile.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    show TagScope;
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Refine panel's Organization group (#2773): tags, minimum rating,
/// favorites and dives excluded from statistics.
class RefineOrganizationGroup extends ConsumerWidget {
  const RefineOrganizationGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {
    'tagIds',
    'minRating',
    'favoritesOnly',
    'excludedFromStatsOnly',
  };

  static int activeCount(DiveFilterState f) => [
    f.tagIds.isNotEmpty,
    f.minRating != null,
    f.favoritesOnly == true,
    f.excludedFromStatsOnly == true,
  ].where((active) => active).length;

  static String title(AppLocalizations l10n) =>
      l10n.diveLog_search_section_organization;

  void _setRating(int? rating) => onChanged(
    draft.copyWith(minRating: rating, clearMinRating: rating == null),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = draft.favoritesOnly ?? false;
    final excluded = draft.excludedFromStatsOnly ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefineSubLabel(l10n.diveLog_filter_sectionTags),
        ref
            .watch(tagListNotifierProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.diveLog_filter_errorLoadingTags),
              data: (everyTag) {
                // Dive tags only (#1765).
                final tags = [
                  for (final tag in everyTag)
                    if (tag.appliesTo(TagScope.dives)) tag,
                ];
                if (tags.isEmpty) {
                  return Text(
                    l10n.diveLog_filter_noTagsYet,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        // The dot carries the tag's own colour (#2254).
                        avatar: CircleAvatar(
                          backgroundColor: tag.color,
                          radius: 6,
                        ),
                        label: Text(tag.name),
                        selected: draft.tagIds.contains(tag.id),
                        onSelected: (selected) => onChanged(
                          draft.copyWith(
                            tagIds: selected
                                ? [...draft.tagIds, tag.id]
                                : [
                                    for (final id in draft.tagIds)
                                      if (id != tag.id) id,
                                  ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        RefineSubLabel(l10n.diveLog_filter_sectionMinRating),
        Row(
          children: [
            for (var rating = 1; rating <= 5; rating++)
              IconButton(
                icon: Icon(
                  (draft.minRating ?? 0) >= rating
                      ? Icons.star
                      : Icons.star_border,
                  color: (draft.minRating ?? 0) >= rating ? Colors.amber : null,
                  size: 32,
                ),
                tooltip: l10n.diveSites_edit_rating_starTooltip(rating),
                // The selected star again clears the rating.
                onPressed: () =>
                    _setRating(draft.minRating == rating ? null : rating),
              ),
          ],
        ),
        if (draft.minRating != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => _setRating(null),
              child: Text(l10n.diveLog_filter_clearRating),
            ),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('filter-favorites-only'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.diveLog_filter_favoritesOnly),
          subtitle: Text(l10n.diveLog_filter_showOnlyFavorites),
          secondary: Icon(Icons.favorite, color: favorites ? Colors.red : null),
          value: favorites,
          onChanged: (v) => onChanged(
            draft.copyWith(
              favoritesOnly: v ? true : null,
              clearFavoritesOnly: !v,
            ),
          ),
        ),
        // So the diver can find the dives they took out of statistics (#526).
        SwitchListTile(
          key: const Key('filter-excluded-from-stats-only'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.diveLog_filter_excludedOnly),
          secondary: const Icon(Icons.bar_chart_outlined),
          value: excluded,
          onChanged: (v) => onChanged(
            draft.copyWith(
              excludedFromStatsOnly: v ? true : null,
              clearExcludedFromStatsOnly: !v,
            ),
          ),
        ),
      ],
    );
  }
}
