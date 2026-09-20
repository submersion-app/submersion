import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Turns a chip payload into the diver's words: app language, diver units.
class ChipLabeler {
  ChipLabeler(this.l10n, this.units);
  final AppLocalizations l10n;
  final UnitFormatter units;

  String label(ChipPayload payload) => switch (payload) {
    ClauseChip() => _clause(payload),
    MentionChip(:final entry) => entry.label,
    TimeChip(:final start, :final end) => _time(start, end),
  };

  String fieldName(ExploreDiveField f) => switch (f) {
    ExploreDiveField.depth => l10n.explore_field_depth,
    ExploreDiveField.avgDepth => l10n.explore_field_avgDepth,
    ExploreDiveField.bottomTime => l10n.explore_field_bottomTime,
    ExploreDiveField.waterTemp => l10n.explore_field_waterTemp,
    ExploreDiveField.airTemp => l10n.explore_field_airTemp,
    ExploreDiveField.visibility => l10n.explore_field_visibility,
    ExploreDiveField.rating => l10n.explore_field_rating,
    ExploreDiveField.o2 => l10n.explore_field_o2,
    ExploreDiveField.diveNumber => l10n.explore_field_diveNumber,
    ExploreDiveField.waterType => l10n.explore_field_waterType,
    ExploreDiveField.diveMode => l10n.explore_field_diveMode,
    ExploreDiveField.entryMethod => l10n.explore_field_entryMethod,
    ExploreDiveField.currentStrength => l10n.explore_field_currentStrength,
    ExploreDiveField.favorite => l10n.explore_chip_favorite,
    ExploreDiveField.deco => l10n.explore_chip_deco,
    ExploreDiveField.noBuddy => l10n.explore_chip_noBuddy,
    ExploreDiveField.weekday => l10n.explore_field_weekday,
    ExploreDiveField.diveType => l10n.explore_field_diveType,
    ExploreDiveField.sacTrend => l10n.explore_field_sacTrend,
    ExploreDiveField.sacRoseAfter => l10n.explore_field_sacRoseAfter,
    ExploreDiveField.finalStopUnstable => l10n.explore_field_finalStopUnstable,
    ExploreDiveField.finalStopDuration => l10n.explore_field_finalStopDuration,
    ExploreDiveField.safetyFinding => l10n.explore_field_safetyFinding,
  };

  /// The diver's word for an enum value. Falls back to the raw name, which
  /// is what the dive-type and entry-method values already show.
  String _enumValue(ExploreDiveField field, String raw) => switch ((
    field,
    raw,
  )) {
    (ExploreDiveField.sacTrend, 'rising') => l10n.explore_value_sacTrend_rising,
    (ExploreDiveField.sacTrend, 'falling') =>
      l10n.explore_value_sacTrend_falling,
    (ExploreDiveField.sacTrend, 'flat') => l10n.explore_value_sacTrend_flat,
    (ExploreDiveField.safetyFinding, 'rapidAscent') =>
      l10n.explore_value_finding_rapidAscent,
    (ExploreDiveField.safetyFinding, 'missedDecoStop') =>
      l10n.explore_value_finding_missedDecoStop,
    (ExploreDiveField.safetyFinding, 'omittedSafetyStop') =>
      l10n.explore_value_finding_omittedSafetyStop,
    (ExploreDiveField.safetyFinding, 'sawtoothProfile') =>
      l10n.explore_value_finding_sawtoothProfile,
    (ExploreDiveField.safetyFinding, 'highSurfaceGf') =>
      l10n.explore_value_finding_highSurfaceGf,
    _ => raw,
  };

  String _op(ClauseOp op) => switch (op) {
    ClauseOp.gt => l10n.explore_op_gt,
    ClauseOp.gte => l10n.explore_op_gte,
    ClauseOp.lt => l10n.explore_op_lt,
    ClauseOp.lte => l10n.explore_op_lte,
    _ => l10n.explore_op_eq,
  };

  String _value(double v, FieldDimension d) => switch (d) {
    FieldDimension.depth => units.formatDepth(v, decimals: 0),
    FieldDimension.temperature => units.formatTemperature(v, decimals: 0),
    FieldDimension.pressure => units.formatPressure(v),
    FieldDimension.minutes => '${v.round()} min',
    FieldDimension.percent => '${v.round()}%',
    FieldDimension.count ||
    FieldDimension.none => v == v.roundToDouble() ? '${v.round()}' : '$v',
  };

  String _clause(ClauseChip c) {
    final name = fieldName(c.field);
    final v = c.value;
    if (v is bool) {
      return switch (c.field) {
        ExploreDiveField.deco =>
          v ? l10n.explore_chip_deco : l10n.explore_chip_noDeco,
        ExploreDiveField.noBuddy => l10n.explore_chip_noBuddy,
        // An unstable stop is only ever set true (the compiler leaves the
        // negation unplaced), so the field name alone says it.
        ExploreDiveField.finalStopUnstable =>
          l10n.explore_field_finalStopUnstable,
        _ => l10n.explore_chip_favorite,
      };
    }
    if (v is List && v.isNotEmpty && v.first is num) {
      return l10n.explore_chip_between(
        name,
        _value((v[0] as num).toDouble(), c.dimension),
        _value((v[1] as num).toDouble(), c.dimension),
      );
    }
    if (v is List) {
      final values = v.map((e) => _enumValue(c.field, '$e')).join(', ');
      return c.op == ClauseOp.not
          ? l10n.explore_chip_enumNot(name, values)
          : l10n.explore_chip_enum(name, values);
    }
    if (v is String) {
      final label = _enumValue(c.field, v);
      return c.op == ClauseOp.not
          ? l10n.explore_chip_enumNot(name, label)
          : l10n.explore_chip_enum(name, label);
    }
    final number = (v as num).toDouble();
    if (c.field == ExploreDiveField.rating) {
      return l10n.explore_chip_rating(_op(c.op), _value(number, c.dimension));
    }
    return l10n.explore_chip_numeric(
      name,
      _op(c.op),
      _value(number, c.dimension),
    );
  }

  String _time(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return l10n.explore_chip_timeRange(
        units.formatDate(start),
        units.formatDate(end),
      );
    }
    if (start != null) {
      return l10n.explore_chip_timeSince(units.formatDate(start));
    }
    return l10n.explore_chip_timeBefore(units.formatDate(end));
  }
}
