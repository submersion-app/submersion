import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/explore_label_lookup.dart';
import 'package:submersion/features/query/presentation/query_label_lookup.dart';
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

  /// The field's name in the app language, through its own label key.
  String fieldName(ExploreField f) => exploreLabelForKey(l10n, f.labelKey);

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
    FieldDimension.pressureRate => units.formatSac(v),
    FieldDimension.minutes => l10n.explore_value_minutes(v.round()),
    FieldDimension.percent => '${v.round()}%',
    // No Explore field weighs or measures volume; they read as numbers.
    FieldDimension.weight ||
    FieldDimension.volume ||
    FieldDimension.count ||
    FieldDimension.none => v == v.roundToDouble() ? '${v.round()}' : '$v',
  };

  String _clause(ClauseChip c) {
    final name = fieldName(c.field);
    final v = c.value;
    if (v is bool) {
      final off = c.field.offLabelKey;
      return v || off == null ? name : exploreLabelForKey(l10n, off);
    }
    if (v is List && v.isNotEmpty && v.first is num) {
      return l10n.explore_chip_between(
        name,
        _value((v[0] as num).toDouble(), c.dimension),
        _value((v[1] as num).toDouble(), c.dimension),
      );
    }
    if (v is List || v is String) {
      final raw = v is List ? v.whereType<String>() : [v as String];
      final values = raw.map((e) => _enumValue(c.field, e)).join(', ');
      return c.op == ClauseOp.not
          ? l10n.explore_chip_enumNot(name, values)
          : l10n.explore_chip_enum(name, values);
    }
    final number = (v as num).toDouble();
    if (c.field.name == 'rating') {
      return l10n.explore_chip_rating(_op(c.op), _value(number, c.dimension));
    }
    return l10n.explore_chip_numeric(
      name,
      _op(c.op),
      _value(number, c.dimension),
    );
  }

  /// An enum value in the app language. The catalog's values are the enum
  /// names, so each maps through the same localized names the dive editor
  /// shows; a dive type is the diver's own name and stays as written.
  String _enumValue(ExploreField field, String v) => switch (field.name) {
    'waterType' => WaterType.values.byName(v).localizedName(l10n),
    'diveMode' => DiveMode.values.byName(v).localizedName(l10n),
    'entryMethod' => EntryMethod.values.byName(v).localizedName(l10n),
    'currentStrength' => CurrentStrength.values.byName(v).localizedName(l10n),
    'weekday' => DateFormat.E(l10n.localeName).format(
      // 1 January 2024 was a Monday.
      DateTime(2024, 1, kWeekdayTokens.indexOf(v) + 1),
    ),
    'sacTrend' ||
    'finalStop' => queryLabelForKey(l10n, 'query_dives_${field.name}_$v'),
    'finding' => switch (SafetyRuleId.fromDbValue(v)) {
      final rule? => safetyRuleLabel(rule, l10n),
      null => v,
    },
    _ => v,
  };

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
    // [end] is the last INCLUDED day, so "Before" names the day after it:
    // "before 2022" ends on 31 December 2021 and reads "Before 1 Jan 2022".
    final e = end!;
    return l10n.explore_chip_timeBefore(
      units.formatDate(DateTime(e.year, e.month, e.day + 1)),
    );
  }
}
