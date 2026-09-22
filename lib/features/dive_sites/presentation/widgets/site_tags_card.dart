import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/site_tag_navigation.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Tags card on site detail (issue #1765), built like the dive detail
/// one: a titled card with the tag count and a colored chip per tag.
/// Tapping a chip opens the site list filtered to that tag, as a dive's tag
/// chip opens the dive list. Renders nothing for a site without tags.
class SiteTagsCard extends ConsumerWidget {
  const SiteTagsCard({super.key, required this.siteId, this.bottomGap = 0});

  final String siteId;

  /// Space below the card, collapsed with it when the site has no tags so
  /// the page never shows an empty gap.
  final double bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsForSiteProvider(siteId)).value ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.diveLog_detail_section_tags,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  l10n.diveLog_detail_tagCount(tags.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  TagChip(
                    tag: tag,
                    tooltip: l10n.diveSites_detail_showSitesWith(tag.name),
                    onTap: () => openSitesWithTag(context, ref, tag.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return bottomGap == 0
        ? card
        : Padding(
            padding: EdgeInsets.only(bottom: bottomGap),
            child: card,
          );
  }
}
