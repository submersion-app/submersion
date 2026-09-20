import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One active-filter chip: its label and how to clear just that axis.
class ActiveFilterChip {
  final String label;
  final DiveFilterState Function(DiveFilterState) clear;
  const ActiveFilterChip(this.label, this.clear);
}

/// Pure labelling for the dive list's active-filter bar, covering the axes
/// the bar did not show before Explore, so a handoff never lands on a list
/// whose filter is invisible. Name lookups are injected because they come
/// from providers.
List<ActiveFilterChip> activeFilterChipLabels(
  DiveFilterState f,
  AppLocalizations l10n,
  AppSettings settings, {
  required String? Function(String id) siteName,
  required String? Function(String id) speciesName,
  required String? Function(String id) computerName,
}) {
  final units = UnitFormatter(settings);
  final chips = <ActiveFilterChip>[];
  String depth(double m) => units.convertDepth(m).round().toString();
  String temp(double c) => units.convertTemperature(c).round().toString();

  if (f.minWaterTemp != null && f.maxWaterTemp != null) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filterChip_waterTempRange(
          temp(f.minWaterTemp!),
          temp(f.maxWaterTemp!),
          units.temperatureSymbol,
        ),
        (x) => x.copyWith(clearMinWaterTemp: true, clearMaxWaterTemp: true),
      ),
    );
  } else if (f.minWaterTemp != null) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filterChip_waterTempMin(
          temp(f.minWaterTemp!),
          units.temperatureSymbol,
        ),
        (x) => x.copyWith(clearMinWaterTemp: true),
      ),
    );
  } else if (f.maxWaterTemp != null) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filterChip_waterTempMax(
          temp(f.maxWaterTemp!),
          units.temperatureSymbol,
        ),
        (x) => x.copyWith(clearMaxWaterTemp: true),
      ),
    );
  }
  if (f.minVisibility != null && f.maxVisibility != null) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filterChip_visibilityRange(
          depth(f.minVisibility!),
          depth(f.maxVisibility!),
          units.depthSymbol,
        ),
        (x) => x.copyWith(clearMinVisibility: true, clearMaxVisibility: true),
      ),
    );
  } else if (f.minVisibility != null) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filterChip_visibilityMin(
          depth(f.minVisibility!),
          units.depthSymbol,
        ),
        (x) => x.copyWith(clearMinVisibility: true),
      ),
    );
  } else if (f.maxVisibility != null) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filterChip_visibilityMax(
          depth(f.maxVisibility!),
          units.depthSymbol,
        ),
        (x) => x.copyWith(clearMaxVisibility: true),
      ),
    );
  }
  if (f.waterTypes.isNotEmpty) {
    chips.add(
      ActiveFilterChip(
        f.waterTypes.length == 1
            ? f.waterTypes.single.localizedName(l10n)
            : l10n.diveLog_filterChip_waterTypeCount(f.waterTypes.length),
        (x) => x.copyWith(clearWaterTypes: true),
      ),
    );
  }
  if (f.speciesIds.isNotEmpty) {
    chips.add(
      ActiveFilterChip(
        f.speciesIds.length == 1
            ? (speciesName(f.speciesIds.single) ??
                  l10n.diveLog_filterChip_speciesCount(1))
            : l10n.diveLog_filterChip_speciesCount(f.speciesIds.length),
        (x) => x.copyWith(clearSpeciesIds: true),
      ),
    );
  }
  if (f.siteIds.isNotEmpty) {
    chips.add(
      ActiveFilterChip(
        f.siteIds.length == 1
            ? (siteName(f.siteIds.single) ??
                  l10n.diveLog_filterChip_siteCount(1))
            : l10n.diveLog_filterChip_siteCount(f.siteIds.length),
        (x) => x.copyWith(clearSiteIds: true),
      ),
    );
  }
  if (f.computerId != null) {
    chips.add(
      ActiveFilterChip(
        computerName(f.computerId!) ?? l10n.diveLog_filter_sectionDiveComputer,
        (x) => x.copyWith(clearComputerId: true),
      ),
    );
  }
  if (f.weekdays.isNotEmpty) {
    chips.add(
      ActiveFilterChip(
        '${f.weekdays.length} ${l10n.explore_field_weekday}',
        (x) => x.copyWith(clearWeekdays: true),
      ),
    );
  }
  if (f.decoOnly != null) {
    chips.add(
      ActiveFilterChip(
        f.decoOnly! ? l10n.explore_chip_deco : l10n.explore_chip_noDeco,
        (x) => x.copyWith(clearDecoOnly: true),
      ),
    );
  }
  if (f.minRating != null) {
    chips.add(
      ActiveFilterChip(
        l10n.explore_chip_rating(l10n.explore_op_gte, '${f.minRating}'),
        (x) => x.copyWith(clearMinRating: true),
      ),
    );
  }
  if (f.minBottomTimeMinutes != null || f.maxBottomTimeMinutes != null) {
    final lo = f.minBottomTimeMinutes;
    final hi = f.maxBottomTimeMinutes;
    final label = lo != null && hi != null
        ? l10n.explore_chip_between(
            l10n.explore_field_bottomTime,
            '$lo',
            '$hi min',
          )
        : l10n.explore_chip_numeric(
            l10n.explore_field_bottomTime,
            lo != null ? l10n.explore_op_gte : l10n.explore_op_lte,
            '${lo ?? hi} min',
          );
    chips.add(
      ActiveFilterChip(
        label,
        (x) => x.copyWith(
          clearMinBottomTimeMinutes: true,
          clearMaxBottomTimeMinutes: true,
        ),
      ),
    );
  }
  if (f.minO2Percent != null || f.maxO2Percent != null) {
    final lo = f.minO2Percent;
    final hi = f.maxO2Percent;
    final label = lo != null && hi != null
        ? l10n.explore_chip_between(
            l10n.explore_field_o2,
            '${lo.round()}',
            '${hi.round()}%',
          )
        : l10n.explore_chip_numeric(
            l10n.explore_field_o2,
            lo != null ? l10n.explore_op_gte : l10n.explore_op_lte,
            '${(lo ?? hi)!.round()}%',
          );
    chips.add(
      ActiveFilterChip(
        label,
        (x) => x.copyWith(clearMinO2Percent: true, clearMaxO2Percent: true),
      ),
    );
  }
  if (f.customFieldKey != null && f.customFieldKey!.isNotEmpty) {
    final value = f.customFieldValue;
    chips.add(
      ActiveFilterChip(
        value == null || value.isEmpty
            ? f.customFieldKey!
            : '${f.customFieldKey}: $value',
        (x) =>
            x.copyWith(clearCustomFieldKey: true, clearCustomFieldValue: true),
      ),
    );
  }
  if (f.equipmentAttrConditions.isNotEmpty) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filterChip_equipmentCount(
          f.equipmentAttrConditions.length,
        ),
        (x) => x.copyWith(clearEquipmentAttrConditions: true),
      ),
    );
  }
  if (f.excludedFromStatsOnly == true) {
    chips.add(
      ActiveFilterChip(
        l10n.diveLog_filter_excludedOnly,
        (x) => x.copyWith(clearExcludedFromStatsOnly: true),
      ),
    );
  }
  return chips;
}
