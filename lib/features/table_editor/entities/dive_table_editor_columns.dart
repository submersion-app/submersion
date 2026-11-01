import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/table_editor/domain/cell_parsers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef DiveEditorColumn = TableEditorColumn<Dive, DiveField>;
typedef _Column = DiveEditorColumn;
typedef _Units = UnitFormatter;

/// The deco algorithms a dive stores, with the labels the app shows for them.
const kDecoAlgorithmChoices = [
  ChoiceOption('buhlmann', 'Bühlmann'),
  ChoiceOption('vpm', 'VPM'),
  ChoiceOption('rgbm', 'RGBM'),
  ChoiceOption('dciem', 'DCIEM'),
];

/// The dive tab's editable columns (#3422): every scalar bulk edit handles,
/// plus the single-row weight. Computer-measured columns are left out, so
/// they stay read-only in the sheet.
List<DiveEditorColumn> diveEditorColumns({
  required Map<String, List<DiveWeight>> weightsByDive,
  required List<ChoiceOption> sites,
  required List<ChoiceOption> centers,
  required List<ChoiceOption> trips,
}) => [
  _reference(DiveField.siteName, (d) => d.site?.id, sites),
  _reference(DiveField.diveCenterName, (d) => d.diveCenter?.id, centers),
  _reference(DiveField.tripName, (d) => d.tripId ?? d.trip?.id, trips),
  _text(DiveField.diveOperator, (d) => d.diveOperator),
  _text(DiveField.boatName, (d) => d.boatName),
  _text(DiveField.boatCaptain, (d) => d.boatCaptain),
  _integer(DiveField.ratingStars, (d) => d.rating, min: 0, max: 5),
  _toggle(DiveField.isFavorite, (d) => d.isFavorite),
  _toggle(DiveField.excludedFromStats, (d) => d.excludedFromStats),
  _toggle(DiveField.excludedFromGasStats, (d) => d.excludedFromGasStats),
  _choice(
    DiveField.waterType,
    (d) => d.waterType,
    WaterType.values,
    (v, l) => v.localizedName(l),
  ),
  _number(
    DiveField.visibility,
    (d) => d.visibilityMeters,
    toDisplay: (u, v) => u.convertDepth(v),
    toStored: (u, v) => u.depthToMeters(v),
    symbol: (u) => u.depthSymbol,
    min: 0,
  ),
  _choice(
    DiveField.currentDirection,
    (d) => d.currentDirection,
    CurrentDirection.values,
    (v, l) => v.localizedName(l),
  ),
  _choice(
    DiveField.currentStrength,
    (d) => d.currentStrength,
    CurrentStrength.values,
    (v, l) => v.localizedName(l),
  ),
  _number(
    DiveField.swellHeight,
    (d) => d.swellHeight,
    toDisplay: (u, v) => u.convertDepth(v),
    toStored: (u, v) => u.depthToMeters(v),
    symbol: (u) => u.depthSymbol,
    min: 0,
  ),
  _text(DiveField.surfaceConditions, (d) => d.surfaceConditions),
  _choice(
    DiveField.entryMethod,
    (d) => d.entryMethod,
    EntryMethod.values,
    (v, l) => v.localizedName(l),
  ),
  _choice(
    DiveField.exitMethod,
    (d) => d.exitMethod,
    EntryMethod.values,
    (v, l) => v.localizedName(l),
  ),
  _number(
    DiveField.altitude,
    (d) => d.altitude,
    toDisplay: (u, v) => u.convertAltitude(v),
    toStored: (u, v) => u.altitudeToMeters(v),
    symbol: (u) => u.altitudeSymbol,
  ),
  _number(
    DiveField.surfacePressure,
    (d) => d.surfacePressure,
    toDisplay: (_, v) => v,
    toStored: (_, v) => v,
    symbol: (_) => 'bar',
    min: 0,
  ),
  _integer(
    DiveField.surfaceInterval,
    (d) => d.surfaceInterval?.inMinutes,
    min: 0,
  ),
  _integer(
    DiveField.gradientFactorLow,
    (d) => d.gradientFactorLow,
    min: 0,
    max: 100,
  ),
  _integer(
    DiveField.gradientFactorHigh,
    (d) => d.gradientFactorHigh,
    min: 0,
    max: 100,
  ),
  _Column(
    field: DiveField.decoAlgorithm,
    kind: CellEditorKind.choice,
    valueOf: (d) => d.decoAlgorithm,
    choices: (_) => kDecoAlgorithmChoices,
    parse: (text, _, _) => parseChoiceCell(text, kDecoAlgorithmChoices),
  ),
  _integer(DiveField.decoConservatism, (d) => d.decoConservatism),
  _text(DiveField.diveComputerModel, (d) => d.diveComputerModel),
  _number(
    DiveField.windSpeed,
    (d) => d.windSpeed,
    toDisplay: (u, v) => u.convertWindSpeed(v),
    toStored: (u, v) => u.windSpeedToMs(v),
    symbol: (u) => u.windSpeedSymbol,
    min: 0,
  ),
  _choice(
    DiveField.windDirection,
    (d) => d.windDirection,
    CurrentDirection.values,
    (v, l) => v.localizedName(l),
  ),
  _choice(
    DiveField.cloudCover,
    (d) => d.cloudCover,
    CloudCover.values,
    (v, l) => v.localizedName(l),
  ),
  _choice(
    DiveField.precipitation,
    (d) => d.precipitation,
    Precipitation.values,
    (v, l) => v.localizedName(l),
  ),
  _number(
    DiveField.humidity,
    (d) => d.humidity,
    toDisplay: (_, v) => v,
    toStored: (_, v) => v,
    symbol: (_) => '%',
    min: 0,
    max: 100,
  ),
  _text(DiveField.weatherDescription, (d) => d.weatherDescription),
  _choice(
    DiveField.diveMode,
    (d) => d.diveMode,
    DiveMode.values,
    (v, l) => v.localizedName(l),
  ),
  _setpoint(DiveField.setpointLow, (d) => d.setpointLow),
  _setpoint(DiveField.setpointHigh, (d) => d.setpointHigh),
  _setpoint(DiveField.setpointDeco, (d) => d.setpointDeco),
  _Column(
    field: DiveField.diluentGas,
    kind: CellEditorKind.text,
    valueOf: (d) => d.diluentGas,
    editText: (d, _) => _gasText(d.diluentGas),
    parse: (text, _, _) => _parseGas(text),
  ),
  _text(DiveField.scrubberType, (d) => d.scrubber?.type),
  _integer(DiveField.scrubberDuration, (d) => d.scrubber?.ratedMinutes, min: 0),
  _text(DiveField.notes, (d) => d.notes.isEmpty ? null : d.notes),
  _weight(weightsByDive),
];

_Column _text(DiveField field, String? Function(Dive) get) => _Column(
  field: field,
  kind: CellEditorKind.text,
  valueOf: get,
  editText: (d, _) => get(d) ?? '',
  parse: (text, _, _) => parseTextCell(text),
);

_Column _number(
  DiveField field,
  double? Function(Dive) get, {
  required double Function(_Units, double) toDisplay,
  required double Function(_Units, double) toStored,
  required String? Function(_Units) symbol,
  double? min,
  double? max,
}) => _Column(
  field: field,
  kind: CellEditorKind.number,
  valueOf: get,
  editText: (d, u) {
    final v = get(d);
    return v == null ? '' : formatDecimalForInput(toDisplay(u, v));
  },
  parse: (text, u, _) => parseNumberCell(
    text,
    toStored: (v) => toStored(u, v),
    min: min,
    max: max,
  ),
  unitSymbol: symbol,
);

_Column _setpoint(DiveField field, double? Function(Dive) get) => _number(
  field,
  get,
  toDisplay: (_, v) => v,
  toStored: (_, v) => v,
  symbol: (_) => 'bar',
  min: 0,
  max: 2,
);

_Column _integer(
  DiveField field,
  int? Function(Dive) get, {
  int? min,
  int? max,
}) => _Column(
  field: field,
  kind: CellEditorKind.integer,
  valueOf: get,
  editText: (d, _) => get(d)?.toString() ?? '',
  parse: (text, _, _) => parseIntegerCell(text, min: min, max: max),
);

_Column _toggle(DiveField field, bool Function(Dive) get) => _Column(
  field: field,
  kind: CellEditorKind.toggle,
  valueOf: get,
  parse: (text, _, l) => parseToggleCell(text, l),
);

_Column _choice<E extends Enum>(
  DiveField field,
  E? Function(Dive) get,
  List<E> values,
  String Function(E, AppLocalizations) label,
) {
  List<ChoiceOption> options(AppLocalizations l) => [
    for (final v in values) ChoiceOption(v.name, label(v, l)),
  ];
  return _Column(
    field: field,
    kind: CellEditorKind.choice,
    valueOf: (d) => get(d)?.name,
    choices: options,
    parse: (text, _, l) => parseChoiceCell(text, options(l)),
  );
}

_Column _reference(
  DiveField field,
  String? Function(Dive) get,
  List<ChoiceOption> options,
) => _Column(
  field: field,
  kind: CellEditorKind.reference,
  valueOf: get,
  choices: (_) => options,
  parse: (text, _, _) => parseChoiceCell(text, options),
);

_Column _weight(Map<String, List<DiveWeight>> weightsByDive) {
  int rowsOf(Dive d) => weightsByDive[d.id]?.length ?? 0;
  return _Column(
    field: DiveField.totalWeight,
    kind: CellEditorKind.number,
    valueOf: (d) {
      final rows = weightsByDive[d.id];
      return rows == null || rows.length != 1 ? null : rows.single.amountKg;
    },
    editText: (d, u) {
      final rows = weightsByDive[d.id];
      if (rows == null || rows.length != 1) return '';
      return formatDecimalForInput(u.convertWeight(rows.single.amountKg));
    },
    parse: (text, u, _) =>
        parseNumberCell(text, toStored: u.weightToKg, min: 0),
    unitSymbol: (u) => u.weightSymbol,
    isEditable: (d) => rowsOf(d) <= 1,
    readOnlyReason: (d, l) =>
        rowsOf(d) <= 1 ? null : l.tableEditor_weightRows(rowsOf(d)),
  );
}

String _gasText(GasMix? gas) {
  if (gas == null) return '';
  final o2 = formatDecimalForInput(gas.o2);
  if (gas.he == 0) return o2;
  return '$o2/${formatDecimalForInput(gas.he)}';
}

/// "21", "21/35" or "18/45": oxygen and helium percentages.
CellParseResult _parseGas(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const CellParsed(null);
  final parts = trimmed.split('/');
  if (parts.length > 2) return const CellRejected(TableDraftFlag.unparsable);
  final o2 = _percent(parts[0]);
  final he = parts.length == 2 ? _percent(parts[1]) : 0.0;
  if (o2 == null || he == null || o2 + he > 100) {
    return const CellRejected(TableDraftFlag.unparsable);
  }
  return CellParsed(GasMix(o2: o2, he: he));
}

double? _percent(String text) =>
    switch (parseNumberCell(text, toStored: (v) => v, min: 0, max: 100)) {
      CellParsed(:final value) => value as double?,
      CellRejected() => null,
    };
