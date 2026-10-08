import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/distribution_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String focusFactorName(FocusFactorId id, AppLocalizations l10n) => switch (id) {
  FocusFactorId.maxDepth => l10n.insights_focus_metric_maxDepth,
  FocusFactorId.avgDepth => l10n.insights_focus_factor_avgDepth,
  FocusFactorId.duration => l10n.insights_focus_factor_duration,
  FocusFactorId.waterTemp => l10n.insights_focus_metric_waterTemp,
  FocusFactorId.visibility => l10n.insights_focus_factor_visibility,
  FocusFactorId.current => l10n.insights_focus_factor_current,
  FocusFactorId.waterType => l10n.insights_focus_factor_waterType,
  FocusFactorId.entryMethod => l10n.insights_focus_factor_entryMethod,
  FocusFactorId.month => l10n.insights_focus_factor_month,
  FocusFactorId.timeOfDay => l10n.insights_focus_factor_timeOfDay,
  FocusFactorId.site => l10n.insights_focus_factor_site,
  FocusFactorId.diveType => l10n.insights_focus_factor_diveType,
  FocusFactorId.gas => l10n.insights_focus_factor_gas,
  FocusFactorId.tankVolume => l10n.insights_focus_factor_tankVolume,
  FocusFactorId.weight => l10n.insights_focus_metric_weight,
  FocusFactorId.suit => l10n.insights_focus_factor_suit,
  FocusFactorId.buddy => l10n.insights_focus_factor_buddy,
};

String focusFactorGroupName(FocusFactorGroup group, AppLocalizations l10n) =>
    switch (group) {
      FocusFactorGroup.diveShape => l10n.insights_focus_factorGroup_diveShape,
      FocusFactorGroup.conditions => l10n.insights_focus_factorGroup_conditions,
      FocusFactorGroup.whenWhere => l10n.insights_focus_factorGroup_whenWhere,
      FocusFactorGroup.kitGas => l10n.insights_focus_factorGroup_kitGas,
    };

/// A numeric factor's value in the diver's units.
String focusNumericValue(
  FocusFactorId id,
  double value,
  UnitFormatter units,
  AppLocalizations l10n,
) => switch (id) {
  FocusFactorId.maxDepth || FocusFactorId.avgDepth => units.formatDepth(value),
  FocusFactorId.duration => l10n.surfaceInterval_format_minutes(
    value.toStringAsFixed(0),
  ),
  FocusFactorId.waterTemp => units.formatTemperature(value),
  FocusFactorId.tankVolume => units.formatTankVolume(value, null),
  FocusFactorId.weight => units.formatWeight(value),
  _ => value.toStringAsFixed(1),
};

/// A signed difference between two numeric factor values, in display units.
///
/// A temperature difference is a delta: 2 C warmer is 3.6 F warmer, so it
/// scales without the 32-degree offset a reading's conversion applies.
String focusNumericDifference(
  FocusFactorId id,
  double difference,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  final sign = difference >= 0 ? '+' : '-';
  final magnitude = difference.abs();
  if (id == FocusFactorId.waterTemp) {
    return '$sign${units.formatTemperatureDelta(magnitude)}';
  }
  return '$sign${focusNumericValue(id, magnitude, units, l10n)}';
}

/// Display text for one category value, from the stable key the repository
/// and the analyzer emit.
///
/// [typesById] (the loaded `dive_types` rows) is only consulted for
/// [FocusFactorId.diveType]; see [diveTypeDistributionLabel].
String focusCategoryLabel(
  FocusFactorId id,
  CategoryShare share,
  AppLocalizations l10n,
  UnitFormatter units, {
  Map<String, DiveTypeEntity>? typesById,
}) {
  final key = share.key;
  switch (id) {
    case FocusFactorId.visibility:
      return visibilityDistributionLabel(key, l10n, units);
    case FocusFactorId.current:
      return CurrentStrength.values
              .where((c) => c.name == key)
              .firstOrNull
              ?.localizedName(l10n) ??
          key;
    case FocusFactorId.waterType:
      return waterTypeDistributionLabel(key, l10n);
    case FocusFactorId.entryMethod:
      return entryMethodDistributionLabel(key, l10n);
    case FocusFactorId.month:
      // Keys are "1".."12", as the analyzer emits them.
      final labels = insightsMonthLabels(l10n);
      for (var month = 1; month <= labels.length; month++) {
        if (key == '$month') return labels[month - 1];
      }
      return key;
    case FocusFactorId.timeOfDay:
      return timeOfDayDistributionLabel(key, l10n);
    case FocusFactorId.site:
      return share.label ?? key;
    case FocusFactorId.diveType:
      return diveTypeDistributionLabel(key, l10n, typesById: typesById);
    case FocusFactorId.gas:
      return switch (key) {
        'air' => l10n.insights_focus_gas_air,
        'nitrox' => l10n.insights_focus_gas_nitrox,
        'trimix' => l10n.insights_focus_gas_trimix,
        _ => key,
      };
    case FocusFactorId.suit:
      if (key == 'drysuit') return EquipmentType.drysuit.localizedName(l10n);
      if (key == 'unknown') {
        return l10n.insights_progression_divesBySuitThickness_unknown;
      }
      return '${key.substring('wetsuit:'.length)} mm';
    case FocusFactorId.buddy:
      return key == 'solo'
          ? l10n.insights_social_soloVsBuddy_solo
          : l10n.insights_social_soloVsBuddy_withBuddy;
    case FocusFactorId.maxDepth ||
        FocusFactorId.avgDepth ||
        FocusFactorId.duration ||
        FocusFactorId.waterTemp ||
        FocusFactorId.tankVolume ||
        FocusFactorId.weight:
      return key;
  }
}
