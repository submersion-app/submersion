import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:sqlite3/common.dart'
    show AllowedArgumentCount, CommonDatabase, SqliteArguments;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/tank_shared_computers.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration_classifier.dart';

/// `tank_config_base(...)`: a dive's [TankBaseConfiguration] name.
const String kTankConfigBaseFunction = 'tank_config_base';

/// `tank_config_summary(...)`: a dive's base and extras from one
/// classification, each name followed by a comma (`sidemount,stages,`). The
/// first name is the base, so `,<extra>,` only ever finds an extra.
const String kTankConfigSummaryFunction = 'tank_config_summary';

/// The tables [tankConfigBaseSql] and [tankConfigSummarySql] read besides
/// `dives`, for a query field's change ticks.
const List<String> kTankConfigurationTables = [
  'dive_tanks',
  'gas_switches',
  'dive_data_sources',
  'dive_profile_series',
];

/// A dive's [TankBaseConfiguration] name, for the dive row aliased [dive].
///
/// The classifier is Dart (regexes, matched pairs, breathed-tank logic), so
/// the chart and the dive filters reach it through a SQL function rather
/// than a translation that could drift from it (#3804).
String tankConfigBaseSql(String dive) =>
    '$kTankConfigBaseFunction(${_argumentsSql(dive)})';

/// A dive's base and extras in the form [decodeTankConfigSummary] reads. One
/// value, so a query after both classifies each dive once.
String tankConfigSummarySql(String dive) =>
    '$kTankConfigSummaryFunction(${_argumentsSql(dive)})';

/// Whether the dive row aliased [dive] has [extra].
String tankConfigHasExtraSql(String dive, TankConfigurationExtra extra) =>
    "instr(${tankConfigSummarySql(dive)}, ',${extra.name},') > 0";

/// The six arguments both functions take: dive mode, whether a primary
/// profile exists, the primary source's id and computer, and the dive's
/// cylinders and gas switches as JSON.
String _argumentsSql(String dive) =>
    '$dive.dive_mode, '
    'EXISTS (SELECT 1 FROM dive_profile_series s '
    'WHERE s.dive_id = $dive.id AND s.is_primary = 1), '
    '(SELECT id FROM dive_data_sources '
    'WHERE dive_id = $dive.id AND is_primary = 1 LIMIT 1), '
    '(SELECT computer_id FROM dive_data_sources '
    'WHERE dive_id = $dive.id AND is_primary = 1 LIMIT 1), '
    '(SELECT json_group_array(json_array(t.id, t.tank_role, t.volume, '
    't.start_pressure, t.end_pressure, t.o2_percent, t.he_percent, '
    't.tank_order, t.tank_name, t.preset_name, t.computer_id, '
    't.shared_computer_ids, t.source_id)) '
    'FROM dive_tanks t WHERE t.dive_id = $dive.id), '
    '(SELECT json_group_array(json_array(g.tank_id, g.timestamp)) '
    'FROM gas_switches g WHERE g.dive_id = $dive.id)';

/// Registers the classifier's functions on [db].
void registerTankConfigurationFunctions(CommonDatabase db) {
  db.createFunction(
    functionName: kTankConfigBaseFunction,
    function: (arguments) => _classify(arguments).base.name,
    argumentCount: const AllowedArgumentCount(6),
    deterministic: true,
  );
  db.createFunction(
    functionName: kTankConfigSummaryFunction,
    function: (arguments) => _encodeSummary(_classify(arguments)),
    argumentCount: const AllowedArgumentCount(6),
    deterministic: true,
  );
}

String _encodeSummary(TankConfigurationResult result) => [
  result.base.name,
  for (final extra in result.extras) extra.name,
  '',
].join(',');

/// The base and extras a [tankConfigSummarySql] value names.
TankConfigurationResult decodeTankConfigSummary(String value) {
  final names = value.split(',');
  return (
    base: TankBaseConfiguration.values.byName(names.first),
    extras: {
      for (final name in names.skip(1))
        if (name.isNotEmpty) TankConfigurationExtra.values.byName(name),
    },
  );
}

TankConfigurationResult _classify(SqliteArguments arguments) {
  final primarySourceId = arguments[2] as String?;
  final primaryComputerId = arguments[3] as String?;
  final all = _decodeTanks(arguments[4] as String);
  final owned = [
    for (final t in all)
      if (_ownedByPrimary(
        t,
        primarySourceId: primarySourceId,
        primaryComputerId: primaryComputerId,
      ))
        t,
  ];
  return classifyTankConfiguration(
    TankConfigurationDive(
      diveMode: _diveModesByName[arguments[0]] ?? DiveMode.oc,
      // A primary that owns none (a bottom timer that logs no cylinders) has
      // no copies to double count, so the dive keeps every cylinder rather
      // than reading as no tanks.
      tanks: owned.isEmpty ? all : owned,
      gasSwitches: _decodeSwitches(arguments[5] as String),
      hasProfile: arguments[1] == 1,
    ),
  );
}

/// The cylinders in a dive's JSON, in `tank_order`. The order matters: the
/// first back gas is the starting gas when no switch says otherwise.
List<domain.DiveTank> _decodeTanks(String json) => [
  for (final row in (jsonDecode(json) as List).cast<List<Object?>>())
    domain.DiveTank(
      id: row[0]! as String,
      role: _tankRolesByName[row[1]] ?? TankRole.backGas,
      volume: _double(row[2]),
      startPressure: _double(row[3]),
      endPressure: _double(row[4]),
      gasMix: domain.GasMix(
        o2: _double(row[5]) ?? 21.0,
        he: _double(row[6]) ?? 0,
      ),
      order: _int(row[7]),
      name: row[8] as String?,
      presetName: row[9] as String?,
      computerId: row[10] as String?,
      sharedComputerIds: decodeSharedComputerIds(row[11] as String?),
      sourceId: row[12] as String?,
    ),
].sorted((a, b) => a.order.compareTo(b.order));

List<({String tankId, int timestamp})> _decodeSwitches(String json) => [
  for (final row in (jsonDecode(json) as List).cast<List<Object?>>())
    (tankId: row[0]! as String, timestamp: _int(row[1])),
];

/// A stored number, whichever way SQLite kept it: JSON hands back a whole
/// number in a REAL column as an int, and column affinity lets a value that
/// is not a number through. A throw here would fail the whole query, so what
/// cannot be read counts as not recorded, and the columns' defaults stand in.
double? _double(Object? value) => value is num ? value.toDouble() : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

/// Whether [tank] belongs to the dive's primary recording, the rule
/// `tripCylinderIdsTakenFor` uses to tell one recording's cylinders from
/// another's copies. A tank that names a computer belongs when that is the
/// primary computer or consolidation shared it with the primary. A tank
/// that names no computer is its source's (#2716: a consolidated source
/// that names no computer), so it belongs when it has no source or the
/// primary source's; otherwise it is another recording's copy, whatever
/// the primary is. With no primary source every tank counts.
bool _ownedByPrimary(
  domain.DiveTank tank, {
  required String? primarySourceId,
  required String? primaryComputerId,
}) {
  if (primarySourceId == null) return true;
  if (tank.computerId == null) {
    final sourceId = tank.sourceId;
    return sourceId == null || sourceId == primarySourceId;
  }
  return primaryComputerId != null && tank.isUsedBy(primaryComputerId);
}

/// Stored roles by name, built once. A name this build does not know (a
/// newer peer's role) reads as back gas, the column's default.
final Map<String, TankRole> _tankRolesByName = TankRole.values.asNameMap();

/// Stored dive modes by name, built once. An unknown name reads as open
/// circuit, the column's default.
final Map<String, DiveMode> _diveModesByName = DiveMode.values.asNameMap();
