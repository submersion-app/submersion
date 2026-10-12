import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/utils/elapsed_duration_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_participant_names.dart';
import 'package:submersion/features/dive_log/query/dive_column_filters.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// What a cell menu item does (#2984); the menu words it.
enum CellFilterKind {
  only,
  exclude,
  atLeast,
  atMost,
  onOrAfter,
  onOrBefore,
  withValue,
  withoutValue,
  noValue,
  anyValue,
}

/// One cell menu item: the rule it adds and the value it names.
@immutable
class CellFilterOption {
  const CellFilterOption(this.kind, this.rule, {this.valueLabel = ''});

  final CellFilterKind kind;
  final QueryNode rule;

  /// The value as the cell shows it; empty for noValue and anyValue.
  final String valueLabel;
}

/// The cell menu for [field] on [dive] (#2984).
///
/// Every item is a rule the query engine evaluates on the SAME value the
/// cell displays. Where the cell shows something the field does not read
/// (a runtime derived from timestamps, an entry method inherited from the
/// site, a legacy free-text buddy, a legacy visibility bucket, a dive name
/// shown from its site), there are no items rather than a rule that would
/// drop the dive that was clicked.
///
/// [surfaceIntervals] is null while the computed intervals are loading, and
/// [knownComputerIds] lists the computer rows that exist (null while
/// loading); a cell that depends on either offers nothing until it is known.
List<CellFilterOption> diveCellFilterOptions({
  required DiveField field,
  required Dive dive,
  required UnitFormatter units,
  required UnitPrefs prefs,
  String Function(String id)? diveTypeLabel,
  Map<String, Duration?>? surfaceIntervals = const {},
  Set<String>? knownComputerIds,
}) {
  final spec = kDiveColumnFilters[field];
  if (spec == null || spec.kind == DiveColumnFilterKind.headerOnly) {
    return const [];
  }
  // An unstored interval shows "--" until the computed map arrives, though
  // the query may compute one: "no value" would then drop the dive.
  if (field == DiveField.surfaceInterval &&
      surfaceIntervals == null &&
      dive.surfaceInterval == null) {
    return const [];
  }
  // `computer` joins dive_computers, so a link whose row is missing (or not
  // loaded yet) would drop the dive the cell shows a stored model for.
  final computerId = dive.computerId;
  if (field == DiveField.diveComputerModel &&
      computerId != null &&
      !(knownComputerIds?.contains(computerId) ?? false)) {
    return const [];
  }
  ConditionNode cond(QueryOp op, QueryValue? v) =>
      ConditionNode(spec.path, op, v);

  final shownValue = field == DiveField.surfaceInterval
      ? _surfaceInterval(dive, surfaceIntervals)
      : field.extractFromDive(
          dive,
          gasModel: units.settings.gasModel,
          diveTypeLabel: diveTypeLabel,
        );
  final displayed = field.formatValue(shownValue, units);
  final raw = _queriedValue(field, dive, surfaceIntervals, diveTypeLabel);
  // A dive whose only participants are guides shows no buddy, but the
  // `buddies` relation counts every link: "no buddy" would drop it.
  if (field == DiveField.buddy &&
      raw is List &&
      raw.isEmpty &&
      dive.buddies.isNotEmpty) {
    return const [];
  }
  if (raw == null || (raw is List && raw.isEmpty)) {
    if (!isBlankFieldValue(displayed)) return const [];
    return [
      CellFilterOption(CellFilterKind.noValue, cond(QueryOp.isEmpty, null)),
      CellFilterOption(CellFilterKind.anyValue, cond(QueryOp.isSet, null)),
    ];
  }
  // A value the cell cannot show (a zero-minute duration) is not offered.
  if (isBlankFieldValue(displayed)) return const [];

  List<CellFilterOption> onlyExclude(QueryValue v, String label) => [
    CellFilterOption(
      CellFilterKind.only,
      cond(QueryOp.eq, v),
      valueLabel: label,
    ),
    CellFilterOption(
      CellFilterKind.exclude,
      NotNode(cond(QueryOp.eq, v)),
      valueLabel: label,
    ),
  ];
  List<CellFilterOption> ranged(
    ConditionNode only,
    QueryValue lo,
    QueryValue hi,
    String label, {
    bool dates = false,
  }) => [
    CellFilterOption(CellFilterKind.only, only, valueLabel: label),
    CellFilterOption(
      dates ? CellFilterKind.onOrAfter : CellFilterKind.atLeast,
      cond(QueryOp.gte, lo),
      valueLabel: label,
    ),
    CellFilterOption(
      dates ? CellFilterKind.onOrBefore : CellFilterKind.atMost,
      cond(QueryOp.lte, hi),
      valueLabel: label,
    ),
  ];

  switch (spec.kind) {
    case DiveColumnFilterKind.relation:
      final ref = raw as RefValue;
      return onlyExclude(ref, ref.label);
    case DiveColumnFilterKind.multiRelation:
      return [
        for (final ref in raw as List<RefValue>) ...[
          CellFilterOption(
            CellFilterKind.withValue,
            cond(QueryOp.eq, ref),
            valueLabel: ref.label,
          ),
          CellFilterOption(
            CellFilterKind.withoutValue,
            NotNode(cond(QueryOp.eq, ref)),
            valueLabel: ref.label,
          ),
        ],
      ];
    case DiveColumnFilterKind.integer:
      final value = (raw as num).toDouble();
      // A value the validator refuses would put an error on a chip the
      // diver never typed; offer nothing instead.
      final sanity = _fieldOf(spec).sanity;
      if (sanity != null && (value < sanity.min || value > sanity.max)) {
        return const [];
      }
      final v = NumberValue(value, null);
      return ranged(cond(QueryOp.eq, v), v, v, displayed);
    case DiveColumnFilterKind.duration:
      final whole = (raw as Duration).inMinutes;
      // Past a day the cell drops its minutes ("6d 13h"), and past a year its
      // hours ("1y 35d"): filter on the whole span the cell shows, so a dive
      // whose cell reads the same is never left out.
      final step = switch (splitElapsed(raw).tier) {
        ElapsedTier.minutes || ElapsedTier.hoursMinutes => 1,
        ElapsedTier.daysHours => Duration.minutesPerHour,
        ElapsedTier.yearsDays => Duration.minutesPerDay,
      };
      if (step == 1) {
        final minutes = NumberValue(whole.toDouble(), null);
        return ranged(cond(QueryOp.eq, minutes), minutes, minutes, displayed);
      }
      final start = whole ~/ step * step;
      final lo = NumberValue(start.toDouble(), null);
      final hi = NumberValue((start + step - 1).toDouble(), null);
      return ranged(
        cond(QueryOp.between, ListValue([lo, hi])),
        lo,
        hi,
        displayed,
      );
    case DiveColumnFilterKind.number:
      if (raw is! num) return const [];
      final queryField = _fieldOf(spec);
      final dimension = queryField.dimension;
      // Bounds clamped into the range below could not include a value
      // outside it, so such a value is not offered.
      final range = queryField.sanity;
      if (range != null && (raw < range.min || raw > range.max)) {
        return const [];
      }
      final (shown, _) = storageToDisplay(
        raw.toDouble(),
        null,
        dimension,
        prefs,
      );
      // Half a display step either side of the value as the cell rounds
      // it, so the clicked dive is always inside.
      final step = math.pow(10, -spec.decimals).toDouble();
      final rounded = (shown / step).round() * step;
      // Kept inside the field's sanity range, so the rule validates.
      final sanity = queryField.sanity;
      double ground(double v) {
        final stored = groundToStorage(v, null, dimension, prefs);
        return sanity == null
            ? stored
            : stored.clamp(sanity.min, sanity.max).toDouble();
      }
      final lo = NumberValue(ground(rounded - step / 2), null);
      final hi = NumberValue(ground(rounded + step / 2), null);
      return ranged(
        cond(QueryOp.between, ListValue([lo, hi])),
        lo,
        hi,
        displayed,
      );
    case DiveColumnFilterKind.date:
      final day = DateValue(raw as DateTime);
      return ranged(
        cond(QueryOp.eq, day),
        day,
        day,
        units.formatDate(raw),
        dates: true,
      );
    case DiveColumnFilterKind.text:
      return onlyExclude(StringValue(raw as String), raw);
    case DiveColumnFilterKind.enumValue:
      return onlyExclude(
        EnumValue((raw as Enum).name, label: displayed),
        displayed,
      );
    case DiveColumnFilterKind.boolean:
      return onlyExclude(BoolValue(raw as bool), displayed);
    case DiveColumnFilterKind.headerOnly:
      return const [];
  }
}

/// The stored text, or null for an empty one (the cell shows "--").
String? _nonBlank(String? text) =>
    text == null || text.trim().isEmpty ? null : text;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

QueryField _fieldOf(DiveColumnFilter spec) =>
    resolvePath(appQueryRegistry, diveQueryEntity, spec.path).field!;

Duration? _surfaceInterval(Dive dive, Map<String, Duration?>? computed) =>
    computed != null && computed.containsKey(dive.id)
    ? computed[dive.id]
    : dive.surfaceInterval;

/// The value the column's query field reads for [dive], or null when it
/// reads nothing (an empty cell, or a cell showing a derived value).
Object? _queriedValue(
  DiveField field,
  Dive dive,
  Map<String, Duration?>? surfaceIntervals,
  String Function(String id)? diveTypeLabel,
) => switch (field) {
  DiveField.siteName => switch (dive.site) {
    null => null,
    final s => RefValue(s.id, s.name),
  },
  DiveField.tripName => switch (dive.trip) {
    null => null,
    final t => RefValue(t.id, t.name),
  },
  DiveField.diveCenterName => switch (dive.diveCenter) {
    null => null,
    final c => RefValue(c.id, c.name),
  },
  DiveField.diveComputerModel => switch (dive.computerId) {
    null => null,
    final id => RefValue(id, dive.diveComputerModel ?? id),
  },
  DiveField.diveTypeName => [
    for (final id in dive.diveTypeIds)
      RefValue(id, (diveTypeLabel ?? Dive.diveTypeDisplayName)(id)),
  ],
  DiveField.buddy => [
    for (final b in dive.nonGuideBuddies) RefValue(b.buddy.id, b.buddy.name),
  ],
  DiveField.tags => [for (final t in dive.tags) RefValue(t.id, t.name)],
  DiveField.diveNumber => dive.diveNumber,
  DiveField.ratingStars => dive.rating,
  DiveField.tankCount => dive.tanks.length,
  DiveField.maxDepth => dive.maxDepth,
  DiveField.avgDepth => dive.avgDepth,
  DiveField.waterTemp => dive.waterTemp,
  DiveField.airTemp => dive.airTemp,
  DiveField.visibility => dive.visibilityMeters,
  DiveField.totalWeight => dive.totalWeight > 0 ? dive.totalWeight : null,
  DiveField.bottomTime => dive.bottomTime,
  DiveField.runtime => dive.runtime,
  DiveField.surfaceInterval => _surfaceInterval(dive, surfaceIntervals),
  // The `date` field reads dive_date_time; the cell shows the entry time.
  // On another calendar day they would disagree, so nothing is offered.
  DiveField.dateTime =>
    _sameDay(dive.dateTime, dive.effectiveEntryTime) ? dive.dateTime : null,
  // The `name` field compares the stored text; the cell shows it trimmed.
  DiveField.diveName =>
    dive.name == dive.effectiveName ? dive.effectiveName : null,
  DiveField.boatName => _nonBlank(dive.boatName),
  DiveField.boatCaptain => _nonBlank(dive.boatCaptain),
  DiveField.diveOperator => _nonBlank(dive.diveOperator),
  DiveField.surfaceConditions => _nonBlank(dive.surfaceConditions),
  DiveField.currentStrength => dive.currentStrength,
  DiveField.entryMethod => dive.entryMethod,
  DiveField.exitMethod => dive.exitMethod,
  DiveField.waterType => dive.effectiveWaterType,
  DiveField.diveMode => dive.diveMode,
  DiveField.isFavorite => dive.isFavorite,
  _ => null,
};
