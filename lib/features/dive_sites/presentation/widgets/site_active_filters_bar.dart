import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_chips.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The site list's active-filter bar: Clear, then one removable chip per
/// active axis, including one per top-level condition of the advanced query
/// (#2365), printed in the diver's units.
class SiteActiveFiltersBar extends ConsumerWidget {
  const SiteActiveFiltersBar({super.key, required this.filter});

  final SiteFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Clear all button
            ActionChip(
              avatar: const Icon(Icons.clear_all, size: 18),
              label: Text(context.l10n.diveSites_list_activeFilter_clear),
              onPressed: () {
                ref.read(siteFilterProvider.notifier).state =
                    const SiteFilterState();
              },
            ),
            const SizedBox(width: 8),
            // Individual filter chips
            if (filter.country != null)
              _chip(
                context,
                context.l10n.diveSites_list_activeFilter_country(
                  filter.country!,
                ),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearCountry: true),
              ),
            if (filter.region != null)
              _chip(
                context,
                context.l10n.diveSites_list_activeFilter_region(filter.region!),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearRegion: true),
              ),
            if (filter.difficulty != null)
              _chip(
                context,
                filter.difficulty!.localizedName(context.l10n),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearDifficulty: true),
              ),
            if (filter.minDepth != null || filter.maxDepth != null)
              _chip(
                context,
                _depthRange(context, ref, filter.minDepth, filter.maxDepth),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearMinDepth: true, clearMaxDepth: true),
              ),
            if (filter.minRating != null)
              _chip(
                context,
                context.l10n.diveSites_filter_rating_starsPlus(
                  filter.minRating!.toInt(),
                ),
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearMinRating: true),
              ),
            if (filter.hasCoordinates == true)
              _chip(
                context,
                context.l10n.diveSites_list_activeFilter_hasCoordinates,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearHasCoordinates: true),
              ),
            if (filter.hasDives == true)
              _chip(
                context,
                context.l10n.diveSites_list_activeFilter_hasDives,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(clearHasDives: true),
              ),
            // One chip per filtered site type and tag (issue #1765).
            for (final typeId in filter.siteTypeIds)
              _chip(
                context,
                ref
                        .watch(siteTypesByIdProvider)
                        .value?[typeId]
                        ?.localizedName(context.l10n) ??
                    typeId,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(
                      siteTypeIds: {...filter.siteTypeIds}..remove(typeId),
                    ),
              ),
            for (final tagId in filter.tagIds)
              _chip(
                context,
                (ref.watch(tagsProvider).value ?? const <Tag>[])
                        .where((t) => t.id == tagId)
                        .firstOrNull
                        ?.name ??
                    tagId,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(tagIds: {...filter.tagIds}..remove(tagId)),
              ),
            // One chip per top-level condition of the advanced query
            // (#2365), printed in the diver's units.
            for (final chip in entityQueryChips(
              siteQueryEntity,
              filter.query,
              ref.watch(queryUnitPrefsProvider),
            ))
              _chip(
                context,
                chip.label,
                () => ref.read(siteFilterProvider.notifier).state = filter
                    .copyWith(query: chip.rest, clearQuery: chip.rest == null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Chip label for the active depth filter.
  ///
  /// The bounds are held in meters, like every other stored depth, so they are
  /// converted for display. A two-ended range carries a single trailing symbol,
  /// so only the upper bound is formatted with one.
  String _depthRange(
    BuildContext context,
    WidgetRef ref,
    double? min,
    double? max,
  ) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    if (min != null && max != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeBoth(
        units.convertDepth(min).toStringAsFixed(0),
        units.formatDepth(max, decimals: 0),
      );
    } else if (min != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeMin(
        units.formatDepth(min, decimals: 0),
      );
    } else if (max != null) {
      return context.l10n.diveSites_list_activeFilter_depthRangeMax(
        units.formatDepth(max, decimals: 0),
      );
    }
    return '';
  }
}
