import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A site's types (neutral) then its tags (colored), issue #1765. Tapping a
/// chip opens the site list filtered to it, so "show me every site I tagged
/// to try" is one tap from any such site. Renders nothing when the site has
/// neither.
class SiteClassificationChips extends ConsumerWidget {
  const SiteClassificationChips({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(siteTypesForSiteProvider(siteId)).value ?? const [];
    final tags = ref.watch(tagsForSiteProvider(siteId)).value ?? const [];
    if (types.isEmpty && tags.isEmpty) return const SizedBox.shrink();

    void filterBy(SiteFilterState filter) {
      ref.read(siteFilterProvider.notifier).state = filter;
      context.go('/sites');
    }

    final l10n = context.l10n;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in types)
          ActionChip(
            avatar: const Icon(Icons.category_outlined, size: 16),
            label: Text(type.localizedName(l10n)),
            tooltip: l10n.diveSites_detail_showSitesWith(
              type.localizedName(l10n),
            ),
            onPressed: () => filterBy(SiteFilterState(siteTypeIds: {type.id})),
          ),
        for (final tag in tags)
          ActionChip(
            avatar: CircleAvatar(backgroundColor: tag.color, radius: 6),
            label: Text(tag.name),
            tooltip: l10n.diveSites_detail_showSitesWith(tag.name),
            onPressed: () => filterBy(SiteFilterState(tagIds: {tag.id})),
          ),
      ],
    );
  }
}
