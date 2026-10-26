import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/domain/rule_value_kind.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Looks an id up to a display name; null when the row is gone.
typedef RuleNameOf = String? Function(QuerySubject subject, String id);

String ruleDiveFieldLabel(AppLocalizations l, BulkField f) => switch (f) {
  BulkField.diveCenter => l.rules_field_diveCenter,
  BulkField.diveOperator => l.rules_field_diveOperator,
  BulkField.boatName => l.rules_field_boatName,
  BulkField.boatCaptain => l.rules_field_boatCaptain,
  BulkField.trip => l.rules_field_trip,
  BulkField.rating => l.rules_field_rating,
  BulkField.isFavorite => l.rules_field_isFavorite,
  BulkField.excludedFromStats => l.rules_field_excludedFromStats,
  BulkField.excludedFromGasStats => l.rules_field_excludedFromGasStats,
  BulkField.waterType => l.rules_field_waterType,
  BulkField.visibility => l.rules_field_visibility,
  BulkField.currentDirection => l.rules_field_currentDirection,
  BulkField.currentStrength => l.rules_field_currentStrength,
  BulkField.swellHeight => l.rules_field_swellHeight,
  BulkField.surfaceConditions => l.rules_field_surfaceConditions,
  BulkField.entryMethod => l.rules_field_entryMethod,
  BulkField.exitMethod => l.rules_field_exitMethod,
  BulkField.altitude => l.rules_field_altitude,
  BulkField.surfacePressure => l.rules_field_surfacePressure,
  BulkField.surfaceInterval => l.rules_field_surfaceInterval,
  BulkField.gradientFactorLow => l.rules_field_gradientFactorLow,
  BulkField.gradientFactorHigh => l.rules_field_gradientFactorHigh,
  BulkField.decoAlgorithm => l.rules_field_decoAlgorithm,
  BulkField.decoConservatism => l.rules_field_decoConservatism,
  BulkField.diveComputerModel => l.rules_field_diveComputerModel,
  BulkField.windSpeed => l.rules_field_windSpeed,
  BulkField.windDirection => l.rules_field_windDirection,
  BulkField.cloudCover => l.rules_field_cloudCover,
  BulkField.precipitation => l.rules_field_precipitation,
  BulkField.humidity => l.rules_field_humidity,
  BulkField.weatherDescription => l.rules_field_weatherDescription,
  BulkField.diveMode => l.rules_field_diveMode,
  BulkField.setpointLow => l.rules_field_setpointLow,
  BulkField.setpointHigh => l.rules_field_setpointHigh,
  BulkField.setpointDeco => l.rules_field_setpointDeco,
  BulkField.diluentGas => l.rules_field_diluentGas,
  BulkField.scrubberType => l.rules_field_scrubberType,
  BulkField.scrubberDuration => l.rules_field_scrubberDuration,
  BulkField.diverRole => l.rules_field_diverRole,
  BulkField.notes => l.rules_field_notes,
};

String ruleSiteFieldLabel(AppLocalizations l, SiteRuleField f) => switch (f) {
  SiteRuleField.waterType => l.rules_field_waterType,
  SiteRuleField.difficulty => l.rules_siteField_difficulty,
  SiteRuleField.country => l.rules_siteField_country,
  SiteRuleField.region => l.rules_siteField_region,
  SiteRuleField.city => l.rules_siteField_city,
  SiteRuleField.island => l.rules_siteField_island,
  SiteRuleField.bodyOfWater => l.rules_siteField_bodyOfWater,
  SiteRuleField.minDepth => l.rules_siteField_minDepth,
  SiteRuleField.maxDepth => l.rules_siteField_maxDepth,
  SiteRuleField.altitude => l.rules_field_altitude,
  SiteRuleField.entryMethod => l.rules_field_entryMethod,
  SiteRuleField.exitMethod => l.rules_field_exitMethod,
  SiteRuleField.hazards => l.rules_siteField_hazards,
  SiteRuleField.accessNotes => l.rules_siteField_accessNotes,
  SiteRuleField.mooringNumber => l.rules_siteField_mooringNumber,
  SiteRuleField.parkingInfo => l.rules_siteField_parkingInfo,
};

String ruleDiveCollectionLabel(AppLocalizations l, DiveCollection c) =>
    switch (c) {
      DiveCollection.diveTypes => l.rules_collection_diveTypes,
      DiveCollection.tags => l.rules_collection_tags,
      DiveCollection.equipment => l.rules_collection_equipment,
      DiveCollection.buddies => l.rules_collection_buddies,
      DiveCollection.courses => l.rules_collection_courses,
    };

String ruleSiteCollectionLabel(AppLocalizations l, SiteCollection c) =>
    switch (c) {
      SiteCollection.tags => l.rules_collection_siteTags,
      SiteCollection.siteTypes => l.rules_collection_siteTypes,
    };

QuerySubject diveCollectionSubject(DiveCollection c) => switch (c) {
  DiveCollection.diveTypes => QuerySubject.diveTypes,
  DiveCollection.tags => QuerySubject.tags,
  DiveCollection.equipment => QuerySubject.equipment,
  DiveCollection.buddies => QuerySubject.buddies,
  DiveCollection.courses => QuerySubject.courses,
};

QuerySubject siteCollectionSubject(SiteCollection c) => switch (c) {
  SiteCollection.tags => QuerySubject.tags,
  SiteCollection.siteTypes => QuerySubject.siteTypes,
};

/// The subject an entity-reference field names, for its picker and labels.
QuerySubject? diveFieldRefSubject(BulkField f) => switch (f) {
  BulkField.diveCenter => QuerySubject.centers,
  BulkField.trip => QuerySubject.trips,
  _ => null,
};

/// A stored enum value in the diver's language. [field] is the dive or
/// site field name; dive and site share the water type and entry names.
String ruleEnumValueLabel(AppLocalizations l, String field, String value) {
  T? byName<T extends Enum>(List<T> values) {
    for (final v in values) {
      if (v.name == value) return v;
    }
    return null;
  }

  return switch (field) {
        'waterType' => byName(WaterType.values)?.localizedName(l),
        'currentDirection' ||
        'windDirection' => byName(CurrentDirection.values)?.localizedName(l),
        'currentStrength' => byName(CurrentStrength.values)?.localizedName(l),
        'entryMethod' ||
        'exitMethod' => byName(EntryMethod.values)?.localizedName(l),
        'cloudCover' => byName(CloudCover.values)?.localizedName(l),
        'precipitation' => byName(Precipitation.values)?.localizedName(l),
        'diveMode' => [
          for (final m in DiveMode.values)
            if (m.code == value) m.localizedName(l),
        ].firstOrNull,
        'difficulty' => byName(SiteDifficulty.values)?.localizedName(l),
        'decoAlgorithm' => switch (value) {
          'buhlmann' => 'Bühlmann',
          _ => value.toUpperCase(),
        },
        _ => null,
      } ??
      value;
}

/// A diluent's O2/He percentages, '-' for one not set.
String ruleDiluentLabel(num? o2, num? he) =>
    '${o2 == null ? '-' : _trimNumber(o2)}/${he == null ? '-' : _trimNumber(he)}';

/// [v] to two places at most, trailing zeros dropped, in the locale's digits.
String _trimNumber(num v) {
  final s = v.toStringAsFixed(2);
  return localiseDecimalText(
    s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s,
  );
}

/// A canonical number shown in the diver's units.
String ruleNumberLabel(UnitFormatter u, RuleUnit unit, num v) => switch (unit) {
  RuleUnit.depth => u.formatDepth(v.toDouble()),
  RuleUnit.altitude => u.formatAltitude(v.toDouble()),
  RuleUnit.windSpeed => u.formatWindSpeed(v.toDouble(), decimals: 1),
  RuleUnit.millibar => u.formatSurfacePressure(v.toDouble()),
  RuleUnit.seconds => '${(v / 60).round()} min',
  RuleUnit.none => _trimNumber(v),
};

/// One value of [kind] as the diver reads it.
String ruleValueLabel(
  AppLocalizations l,
  UnitFormatter u, {
  required RuleValueKind kind,
  required RuleUnit unit,
  required String fieldName,
  required Object? value,
  QuerySubject? refSubject,
  RuleNameOf? nameOf,
}) {
  if (value == null || (value is String && value.isEmpty)) {
    return l.rules_value_empty;
  }
  return switch (kind) {
    RuleValueKind.boolean =>
      (value == true || value == 1) ? l.rules_value_yes : l.rules_value_no,
    RuleValueKind.rating => '${(value as num).round()}/5',
    RuleValueKind.number when value is num => ruleNumberLabel(u, unit, value),
    RuleValueKind.enumName => ruleEnumValueLabel(l, fieldName, '$value'),
    RuleValueKind.entityRef =>
      (refSubject == null ? null : nameOf?.call(refSubject, '$value')) ??
          l.rules_actionSummary_missing,
    _ => '$value',
  };
}

/// The value a dive set-field action writes, as the diver reads it.
String diveActionValueLabel(
  AppLocalizations l,
  UnitFormatter u,
  SetDiveFieldAction a,
  RuleNameOf nameOf,
) {
  if (a.field == BulkField.diluentGas) {
    final o2 = a.values['diluentO2'] as num?;
    final he = a.values['diluentHe'] as num?;
    return ruleDiluentLabel(o2 ?? 0, he ?? 0);
  }
  final key = diveFieldValueKeys(a.field).first;
  return ruleValueLabel(
    l,
    u,
    kind: diveFieldKind(a.field),
    unit: diveFieldUnit(a.field),
    fieldName: a.field.name,
    value: a.values[key],
    refSubject: diveFieldRefSubject(a.field),
    nameOf: nameOf,
  );
}

String _names(
  AppLocalizations l,
  QuerySubject subject,
  List<String> ids,
  RuleNameOf nameOf,
) => [
  for (final id in ids) nameOf(subject, id) ?? l.rules_actionSummary_missing,
].join(', ');

/// One line saying what [action] does, for a rule's row and its card.
String describeRuleAction(
  AppLocalizations l,
  UnitFormatter u,
  RuleAction action,
  RuleNameOf nameOf,
) => switch (action) {
  SetDiveFieldAction() => l.rules_actionSummary_set(
    ruleDiveFieldLabel(l, action.field),
    diveActionValueLabel(l, u, action, nameOf),
  ),
  DiveMembershipAction(:final collection, :final mode, :final ids) =>
    (mode == MembershipMode.add
        ? l.rules_actionSummary_add
        : l.rules_actionSummary_remove)(
      ruleDiveCollectionLabel(l, collection),
      _names(l, diveCollectionSubject(collection), ids, nameOf),
    ),
  AppendDiveNotesAction(:final text) => l.rules_actionSummary_appendNotes(text),
  SetSiteFieldAction(:final field, :final value) => l.rules_actionSummary_set(
    ruleSiteFieldLabel(l, field),
    ruleValueLabel(
      l,
      u,
      kind: field.kind,
      unit: siteFieldUnit(field),
      fieldName: field.name,
      value: value,
    ),
  ),
  SiteMembershipAction(:final collection, :final mode, :final ids) =>
    (mode == MembershipMode.add
        ? l.rules_actionSummary_add
        : l.rules_actionSummary_remove)(
      ruleSiteCollectionLabel(l, collection),
      _names(l, siteCollectionSubject(collection), ids, nameOf),
    ),
  AppendSiteDescriptionAction(:final text) =>
    l.rules_actionSummary_appendDescription(text),
  UnknownRuleAction() => l.rules_actionSummary_unknown,
};

/// Whether [action] names something that no longer exists.
bool ruleActionIsBroken(RuleAction action, RuleNameOf nameOf) =>
    switch (action) {
      DiveMembershipAction(:final collection, :final ids) => ids.any(
        (id) => nameOf(diveCollectionSubject(collection), id) == null,
      ),
      SiteMembershipAction(:final collection, :final ids) => ids.any(
        (id) => nameOf(siteCollectionSubject(collection), id) == null,
      ),
      SetDiveFieldAction(:final field, :final values) =>
        diveFieldRefSubject(field) != null &&
            nameOf(
                  diveFieldRefSubject(field)!,
                  '${values[diveFieldValueKeys(field).first]}',
                ) ==
                null,
      _ => false,
    };

/// The rule's triggers in words; "only when run by hand" when it has none.
String ruleTriggersLabel(AppLocalizations l, Rule rule) {
  if (!rule.enabled) return l.rules_trigger_off;
  final parts = [
    if (rule.triggers.contains(RuleTrigger.afterImport))
      l.rules_trigger_afterImport,
    if (rule.triggers.contains(RuleTrigger.afterManualCreate))
      rule.subject == RuleSubject.dives
          ? l.rules_trigger_afterManualDive
          : l.rules_trigger_afterManualSite,
  ];
  return parts.isEmpty ? l.rules_trigger_onDemandOnly : parts.join(', ');
}

/// Why [rule] cannot run as it stands, or null.
String? ruleProblemText(AppLocalizations l, Rule rule) =>
    switch (rule.problem) {
      RuleLoadProblem.unreadable => l.rules_problem_unreadable,
      RuleLoadProblem.invalid => l.rules_problem_invalid,
      RuleLoadProblem.unknownSubject => l.rules_problem_unknownSubject,
      RuleLoadProblem.unresolvedRef => l.rules_problem_unresolvedRef,
      RuleLoadProblem.newerVersion => l.rules_problem_newerVersion,
      null =>
        rule.actions.any((a) => a is UnknownRuleAction)
            ? l.rules_problem_newerVersion
            : rule.actions.isEmpty
            ? l.rules_problem_noActions
            : null,
    };

/// What a run of the rules left undone, one line each: selected items not
/// the diver's to change, rules that cannot run, actions naming deleted
/// items. Wherever a run's results show (#3513), so a skip is never silent.
List<String> ruleRunNotes(
  AppLocalizations l, {
  int outOfScope = 0,
  Iterable<String> skippedRules = const [],
  Iterable<String> skippedActions = const [],
}) => [
  if (outOfScope > 0) l.rules_preview_outOfScope(outOfScope),
  if (skippedRules.isNotEmpty)
    l.rules_preview_skippedRules(skippedRules.join(', ')),
  if (skippedActions.isNotEmpty)
    l.rules_preview_skippedActions(skippedActions.join(', ')),
];
