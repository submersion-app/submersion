import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

/// The intervals a service type or clock keeps by exposure unit beyond days,
/// dives and hours, which have fields of their own.
final FieldCodec exposureIntervalsCodec = FieldCodec.numberMap(
  keys: {for (final unit in ExposureUnit.mapUnits) unit.name},
  min: 0.1,
  max: 100000,
);

/// [parsed] exposure intervals as the entities hold them.
Map<ExposureUnit, double> exposureFrom(Object? parsed) => {
  if (parsed is String)
    for (final MapEntry(:key, :value)
        in (jsonDecode(parsed) as Map<String, Object?>).entries)
      ExposureUnit.fromDbValue(key)!: (value! as num).toDouble(),
};

/// Why [check]'s intervals cannot be saved, or null: the editors take a
/// count unit as a whole number.
PlanBlock? wholeCountProblem(WriteCheck check, String key) {
  for (final MapEntry(key: unit, value: value) in exposureFrom(
    check.values[key],
  ).entries) {
    if (!unit.isFractional && value != value.roundToDouble()) {
      return PlanBlock(
        BlockReason.invalidValue,
        '$key: ${unit.name} counts, so it takes a whole number.',
      );
    }
  }
  return null;
}

/// Why [check]'s currency under [key] cannot be saved, or null: a code of
/// three letters, as the currency pickers list them.
PlanBlock? currencyProblem(WriteCheck check, String key) {
  final code = check.values[key];
  if (code is! String || RegExp(r'^[A-Z]{3}$').hasMatch(code)) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    '$key: a currency code of three letters, such as EUR.',
  );
}

/// The text codec for a currency code, upper-cased as the pickers store it;
/// blank or null leaves it to inherit.
final FieldCodec currencyCodec = _UpperCodec(nullable: true);

/// [currencyCodec] for a record that always holds a currency.
final FieldCodec requiredCurrencyCodec = _UpperCodec(nullable: false);

class _UpperCodec extends FieldCodec {
  _UpperCodec({required super.nullable});

  @override
  String get describe => 'a currency code, such as EUR';

  /// A blank code reads as none, as a picker's "inherit" saves it.
  @override
  Object? parse(Object? raw) =>
      super.parse(raw is String && raw.trim().isEmpty ? null : raw);

  @override
  Object parseValue(Object raw) {
    if (raw is! String) {
      throw const FieldRefusal('This field takes a currency code.');
    }
    return raw.trim().toUpperCase();
  }
}

/// Re-arms an item's service reminders after a write that moves its clocks,
/// as the record and clock notifiers do. Wired from the provider layer.
typedef GearReminderRefresh = Future<void> Function(String equipmentId);

/// The day [value] names, `YYYY-MM-DD`, as the service pickers store a day:
/// local midnight.
DateTime? calendarDay(Object? value) {
  if (value is! String) return null;
  final day = DateTime.parse(value);
  return DateTime(day.year, day.month, day.day);
}

/// Why the day under [key] falls outside [from] to [to], or null.
PlanBlock? dayRangeProblem(
  WriteCheck check,
  String key, {
  required DateTime from,
  required DateTime to,
}) {
  final day = calendarDay(check.values[key]);
  if (day == null || (!day.isBefore(from) && !day.isAfter(to))) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    '$key: a day from ${calendarDate(from)} to ${calendarDate(to)}.',
  );
}

/// The currency [diverId] works in when none is named: their default, as
/// the edit page and the service dialog start one, else USD.
Future<String> defaultCurrencyOf(String diverId) async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT default_currency FROM diver_settings WHERE diver_id = ?',
        variables: [Variable.withString(diverId)],
      )
      .getSingleOrNull();
  final code = (row?.read<String?>('default_currency') ?? '')
      .trim()
      .toUpperCase();
  return code.isEmpty ? 'USD' : code;
}

/// Today, as a day.
DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
