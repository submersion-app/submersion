import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/site_species_suggestions.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One-tap species for the dive editor (issue #4383): what other dives at
/// the dive's site logged, most dives first, then the site's expected list.
///
/// Shows nothing until the suggestions load and nothing when there are none,
/// so a dive at a new site looks exactly as it did before.
class SiteSpeciesSuggestionChips extends ConsumerStatefulWidget {
  const SiteSpeciesSuggestionChips({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.loggedSpeciesIds,
    required this.onAdd,
    this.excludeDiveId,
  });

  /// How many chips show before "Show all".
  static const collapsedCount = 8;

  final String siteId;
  final String siteName;

  /// Species already on the dive; they are not suggested again.
  final Set<String> loggedSpeciesIds;

  /// The dive being edited, whose saved sightings must not count toward its
  /// own suggestions; null for a dive not saved yet.
  final String? excludeDiveId;

  final ValueChanged<SiteSpeciesSuggestion> onAdd;

  @override
  ConsumerState<SiteSpeciesSuggestionChips> createState() =>
      _SiteSpeciesSuggestionChipsState();
}

class _SiteSpeciesSuggestionChipsState
    extends ConsumerState<SiteSpeciesSuggestionChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sources = ref
        .watch(
          siteSpeciesSuggestionSourcesProvider((
            siteId: widget.siteId,
            excludeDiveId: widget.excludeDiveId,
          )),
        )
        .value;
    if (sources == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final suggestions = buildSiteSpeciesSuggestions(
      spotted: sources.spotted,
      expected: sources.expected,
      excludeSpeciesIds: widget.loggedSpeciesIds,
      displayName: (id, stored) => localizedSpeciesName(l10n, id, stored),
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();

    const limit = SiteSpeciesSuggestionChips.collapsedCount;
    final hasMore = suggestions.length > limit;
    final shown = _expanded || !hasMore
        ? suggestions
        : suggestions.take(limit).toList();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.diveLog_edit_suggestions_title(widget.siteName),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final suggestion in shown) _chip(context, suggestion),
              if (hasMore)
                ActionChip(
                  label: Text(
                    _expanded
                        ? l10n.diveLog_edit_suggestions_showFewer
                        : l10n.diveLog_edit_suggestions_showAll(
                            suggestions.length,
                          ),
                  ),
                  labelStyle: TextStyle(color: theme.colorScheme.primary),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, SiteSpeciesSuggestion suggestion) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final name = localizedSpeciesName(
      l10n,
      suggestion.speciesId,
      suggestion.speciesName,
    );
    final addLabel = l10n.diveLog_edit_suggestions_add(name);
    return ActionChip(
      avatar: Icon(Icons.add, size: 18, color: colorScheme.primary),
      tooltip: suggestion.isExpectedOnly
          ? l10n.diveLog_edit_suggestions_expected
          : l10n.diveLog_edit_suggestions_seenOnDives(suggestion.diveCount),
      label: suggestion.isExpectedOnly
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, semanticsLabel: addLabel),
                const SizedBox(width: 4),
                Icon(
                  Icons.bookmark_border,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            )
          : Text('$name · ${suggestion.diveCount}', semanticsLabel: addLabel),
      onPressed: () => widget.onAdd(suggestion),
    );
  }
}
