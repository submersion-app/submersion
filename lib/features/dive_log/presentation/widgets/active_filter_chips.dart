import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One removable chip per active axis of the filter in [filterProvider].
/// Shared by the dive list's filter bar and the Connections Filter tab, so
/// both describe a filter the same way.
List<Widget> activeDiveFilterChips(
  BuildContext context,
  WidgetRef ref,
  StateProvider<DiveFilterState> filterProvider,
) {
  final filter = ref.watch(filterProvider);
  final settings = ref.watch(settingsProvider);
  final units = UnitFormatter(settings);
  final chips = <Widget>[];

  if (filter.startDate != null || filter.endDate != null) {
    String dateText;
    if (filter.startDate != null && filter.endDate != null) {
      dateText = context.l10n.diveLog_filterChip_dateRange(
        units.formatMonthDay(filter.startDate),
        units.formatMonthDay(filter.endDate),
      );
    } else if (filter.startDate != null) {
      dateText = context.l10n.diveLog_filterChip_from(
        units.formatMonthDay(filter.startDate),
      );
    } else {
      dateText = context.l10n.diveLog_filterChip_until(
        units.formatMonthDay(filter.endDate),
      );
    }
    chips.add(
      _chip(context, dateText, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearStartDate: true,
          clearEndDate: true,
        );
      }),
    );
  }

  if (filter.diveTypeId != null) {
    final diveTypeName =
        ref
            .watch(diveTypeProvider(filter.diveTypeId!))
            .value
            ?.localizedName(context.l10n) ??
        builtInDiveTypeName(context.l10n, filter.diveTypeId!) ??
        filter.diveTypeId!;
    chips.add(
      _chip(context, diveTypeName, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearDiveType: true,
        );
      }),
    );
  }

  if (filter.siteId != null) {
    final siteName =
        ref.watch(siteProvider(filter.siteId!)).value?.name ??
        context.l10n.diveLog_edit_row_site;
    chips.add(
      _chip(context, siteName, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearSiteId: true,
        );
      }),
    );
  }

  if (filter.tripId != null) {
    final tripName =
        ref.watch(tripByIdProvider(filter.tripId!)).value?.name ??
        context.l10n.diveLog_edit_row_trip;
    chips.add(
      _chip(context, tripName, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearTripId: true,
        );
      }),
    );
  }

  if (filter.diveCenterId != null) {
    final centerName =
        ref.watch(diveCenterByIdProvider(filter.diveCenterId!)).value?.name ??
        context.l10n.diveLog_search_label_diveCenter;
    chips.add(
      _chip(context, centerName, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearDiveCenterId: true,
        );
      }),
    );
  }

  if (filter.equipmentIds.isNotEmpty) {
    final label = filter.equipmentIds.length == 1
        ? (ref
                  .watch(equipmentItemProvider(filter.equipmentIds.first))
                  .value
                  ?.name ??
              context.l10n.diveLog_edit_section_equipment)
        : context.l10n.diveLog_filterChip_equipmentCount(
            filter.equipmentIds.length,
          );
    chips.add(
      _chip(context, label, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          equipmentIds: [],
        );
      }),
    );
  }

  if (filter.minDepth != null || filter.maxDepth != null) {
    // Bounds are stored in meters; show them in the diver's depth unit.
    final unit = units.depthSymbol;
    final minValue = filter.minDepth == null
        ? null
        : units.convertDepth(filter.minDepth!).round();
    final maxValue = filter.maxDepth == null
        ? null
        : units.convertDepth(filter.maxDepth!).round();
    String depthText;
    if (minValue != null && maxValue != null) {
      depthText = '$minValue-$maxValue$unit';
    } else if (minValue != null) {
      depthText = '>$minValue$unit';
    } else {
      depthText = '<${maxValue!}$unit';
    }
    chips.add(
      _chip(context, depthText, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearMinDepth: true,
          clearMaxDepth: true,
        );
      }),
    );
  }

  if (filter.favoritesOnly == true) {
    chips.add(
      _chip(context, context.l10n.diveLog_filterChip_favorites, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearFavoritesOnly: true,
        );
      }),
    );
  }

  if (filter.noBuddyOnly == true) {
    chips.add(
      _chip(context, context.l10n.diveLog_filterChip_noBuddy, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearNoBuddyOnly: true,
        );
      }),
    );
  }

  if (filter.tagIds.isNotEmpty) {
    final tagCount = filter.tagIds.length;
    chips.add(
      _chip(context, context.l10n.diveLog_detail_tagCount(tagCount), () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearTagIds: true,
        );
      }),
    );
  }

  if (filter.buddyNameFilter != null && filter.buddyNameFilter!.isNotEmpty) {
    chips.add(
      _chip(context, filter.buddyNameFilter!, () {
        ref.read(filterProvider.notifier).state = filter.copyWith(
          clearBuddyNameFilter: true,
        );
      }),
    );
  }

  return chips;
}

Widget _chip(BuildContext context, String label, VoidCallback onRemove) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
  );
}
