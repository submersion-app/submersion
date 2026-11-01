import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/table_editor/domain/cell_parsers.dart';
import 'package:submersion/features/table_editor/domain/column_factories.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';

typedef DiveEditorColumn = TableEditorColumn<Dive, DiveField>;

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
  required List<ChoiceOption> sites,
  required List<ChoiceOption> centers,
  required List<ChoiceOption> trips,
}) => [
  referenceColumn(DiveField.siteName, (d) => d.site?.id, sites),
  referenceColumn(DiveField.diveCenterName, (d) => d.diveCenter?.id, centers),
  referenceColumn(DiveField.tripName, (d) => d.tripId ?? d.trip?.id, trips),
  textColumn(DiveField.diveOperator, (d) => d.diveOperator),
  textColumn(DiveField.boatName, (d) => d.boatName),
  textColumn(DiveField.boatCaptain, (d) => d.boatCaptain),
  integerColumn(DiveField.ratingStars, (d) => d.rating, min: 0, max: 5),
  toggleColumn(DiveField.isFavorite, (d) => d.isFavorite),
  toggleColumn(DiveField.excludedFromStats, (d) => d.excludedFromStats),
  toggleColumn(DiveField.excludedFromGasStats, (d) => d.excludedFromGasStats),
  choiceColumn(
    DiveField.waterType,
    (d) => d.waterType,
    WaterType.values,
    (v, l) => v.localizedName(l),
  ),
  _depth(DiveField.visibility, (d) => d.visibilityMeters),
  choiceColumn(
    DiveField.currentDirection,
    (d) => d.currentDirection,
    CurrentDirection.values,
    (v, l) => v.localizedName(l),
  ),
  choiceColumn(
    DiveField.currentStrength,
    (d) => d.currentStrength,
    CurrentStrength.values,
    (v, l) => v.localizedName(l),
  ),
  _depth(DiveField.swellHeight, (d) => d.swellHeight),
  textColumn(DiveField.surfaceConditions, (d) => d.surfaceConditions),
  choiceColumn(
    DiveField.entryMethod,
    (d) => d.entryMethod,
    EntryMethod.values,
    (v, l) => v.localizedName(l),
  ),
  choiceColumn(
    DiveField.exitMethod,
    (d) => d.exitMethod,
    EntryMethod.values,
    (v, l) => v.localizedName(l),
  ),
  numberColumn(
    DiveField.altitude,
    (d) => d.altitude,
    toDisplay: (u, v) => u.convertAltitude(v),
    toStored: (u, v) => u.altitudeToMeters(v),
    symbol: (u) => u.altitudeSymbol,
  ),
  plainNumberColumn(
    DiveField.surfacePressure,
    (d) => d.surfacePressure,
    symbol: 'bar',
    min: 0,
  ),
  integerColumn(
    DiveField.surfaceInterval,
    (d) => d.surfaceInterval?.inMinutes,
    min: 0,
  ),
  integerColumn(
    DiveField.gradientFactorLow,
    (d) => d.gradientFactorLow,
    min: 0,
    max: 100,
  ),
  integerColumn(
    DiveField.gradientFactorHigh,
    (d) => d.gradientFactorHigh,
    min: 0,
    max: 100,
  ),
  referenceColumn(
    DiveField.decoAlgorithm,
    (d) => d.decoAlgorithm,
    kDecoAlgorithmChoices,
  ),
  integerColumn(DiveField.decoConservatism, (d) => d.decoConservatism),
  textColumn(DiveField.diveComputerModel, (d) => d.diveComputerModel),
  numberColumn(
    DiveField.windSpeed,
    (d) => d.windSpeed,
    toDisplay: (u, v) => u.convertWindSpeed(v),
    toStored: (u, v) => u.windSpeedToMs(v),
    symbol: (u) => u.windSpeedSymbol,
    min: 0,
  ),
  choiceColumn(
    DiveField.windDirection,
    (d) => d.windDirection,
    CurrentDirection.values,
    (v, l) => v.localizedName(l),
  ),
  choiceColumn(
    DiveField.cloudCover,
    (d) => d.cloudCover,
    CloudCover.values,
    (v, l) => v.localizedName(l),
  ),
  choiceColumn(
    DiveField.precipitation,
    (d) => d.precipitation,
    Precipitation.values,
    (v, l) => v.localizedName(l),
  ),
  plainNumberColumn(
    DiveField.humidity,
    (d) => d.humidity,
    symbol: '%',
    min: 0,
    max: 100,
  ),
  textColumn(DiveField.weatherDescription, (d) => d.weatherDescription),
  choiceColumn(
    DiveField.diveMode,
    (d) => d.diveMode,
    DiveMode.values,
    (v, l) => v.localizedName(l),
  ),
  _setpoint(DiveField.setpointLow, (d) => d.setpointLow),
  _setpoint(DiveField.setpointHigh, (d) => d.setpointHigh),
  _setpoint(DiveField.setpointDeco, (d) => d.setpointDeco),
  DiveEditorColumn(
    field: DiveField.diluentGas,
    kind: CellEditorKind.text,
    valueOf: (d) => d.diluentGas,
    editText: (d, _) => _gasText(d.diluentGas),
    parse: (text, _, _) => _parseGas(text),
    displayValue: (v, _) => _gasText(v as GasMix),
  ),
  textColumn(DiveField.scrubberType, (d) => d.scrubber?.type),
  integerColumn(
    DiveField.scrubberDuration,
    (d) => d.scrubber?.ratedMinutes,
    min: 0,
  ),
  textColumn(DiveField.notes, (d) => d.notes.isEmpty ? null : d.notes),
  _weight(),
];

DiveEditorColumn _depth(DiveField field, double? Function(Dive) get) =>
    numberColumn(
      field,
      get,
      toDisplay: (u, v) => u.convertDepth(v),
      toStored: (u, v) => u.depthToMeters(v),
      symbol: (u) => u.depthSymbol,
      min: 0,
    );

DiveEditorColumn _setpoint(DiveField field, double? Function(Dive) get) =>
    plainNumberColumn(field, get, symbol: 'bar', min: 0, max: 2);

/// The single weight row's amount. The row's weights must be loaded (the
/// editor's dives provider merges them in), or every dive looks weightless.
DiveEditorColumn _weight() {
  int rowsOf(Dive d) => d.weights.length;
  return numberColumn(
    DiveField.totalWeight,
    (d) => d.weights.length == 1 ? d.weights.single.amountKg : null,
    toDisplay: (u, v) => u.convertWeight(v),
    toStored: (u, v) => u.weightToKg(v),
    symbol: (u) => u.weightSymbol,
    min: 0,
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
