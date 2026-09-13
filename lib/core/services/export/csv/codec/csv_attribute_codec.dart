import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';

/// One attribute read back from an equipment CSV `key=value` pair.
typedef CsvAttribute = ({
  String key,
  bool isCustom,
  String? valueText,
  double? valueNum,
});

/// The metric suffixes the catalog puts on unit-bearing keys. My units drops
/// them, so a value in inches never sits under `hose_length_m`.
const _metricKeySuffixes = ['_mps', '_bar', '_kg', '_m', '_l', '_h'];

bool _carriesUnit(AttributeDimension d) =>
    d != AttributeDimension.none && d != AttributeDimension.thicknessMm;

/// [key] without its metric suffix when it is a curated number attribute
/// whose dimension carries a unit (`hose_length_m` -> `hose_length`), else
/// null.
String? myUnitsKeyFor(String key) {
  final def = EquipmentAttributeCatalog.defFor(key);
  if (def == null ||
      def.kind != AttributeKind.number ||
      !_carriesUnit(def.dimension)) {
    return null;
  }
  for (final suffix in _metricKeySuffixes) {
    if (key.endsWith(suffix)) {
      return key.substring(0, key.length - suffix.length);
    }
  }
  return null;
}

final Map<String, EquipmentAttributeDef> _defByMyUnitsKey = {
  for (final type in EquipmentType.values)
    for (final def in EquipmentAttributeCatalog.attributesFor(type))
      ?myUnitsKeyFor(def.key): def,
};

/// One attribute as the equipment CSV's Attributes column writes it.
///
/// Metric mode keeps the historical `key=value` with the stored value. My
/// units converts a unit-bearing number with the same helpers the detail
/// page uses and names the unit (`hose_length=22 in`), and writes a date in
/// the file's date format. Text, choice, flag, thickness and custom
/// attributes are the same in both modes.
String formatAttributePair(EquipmentAttribute attribute, CsvExportUnits units) {
  final raw = '${attribute.key}=${attribute.valueText ?? attribute.valueNum}';
  if (attribute.isCustom) {
    return _customCollides(attribute.key) ? '$_customPrefix$raw' : raw;
  }
  final formatter = units.formatter;
  final number = attribute.valueNum;
  if (units.isMetric || formatter == null) return raw;
  final def = EquipmentAttributeCatalog.defFor(attribute.key);
  if (def == null || number == null) return raw;
  if (def.kind == AttributeKind.date) {
    final date = DateTime.fromMillisecondsSinceEpoch(number.round());
    return '${attribute.key}=${units.date(date)}';
  }
  final key = myUnitsKeyFor(attribute.key);
  if (key == null) return raw;
  final display = attributeDisplayFromMetric(def.dimension, formatter, number);
  final symbol = attributeUnitSymbol(def.dimension, formatter);
  // A cylinder's water volume in cuft is a fraction of one; three places
  // keep it within 0.03 L of the stored litres.
  final decimals =
      def.dimension == AttributeDimension.volumeL &&
          symbol == VolumeUnit.cubicFeet.symbol
      ? 3
      : 1;
  return '$key=${trimFixed(display, decimals)} $symbol';
}

/// Marks a custom attribute whose key a curated attribute also uses (or
/// that already starts with the marker), so it reads back as custom.
const _customPrefix = 'custom:';

bool _customCollides(String key) =>
    EquipmentAttributeCatalog.defFor(key) != null ||
    _defByMyUnitsKey.containsKey(key) ||
    key.startsWith(_customPrefix);

/// Joins formatted pairs into an Attributes cell, escaping a pair only when
/// a ';' in it would otherwise split it on import (see `csv_list_codec`).
String joinAttributePairs(Iterable<String> pairs) => joinCsvList(pairs);

/// Splits an Attributes cell into decoded pairs. A segment with no `=` is
/// the tail of the previous value: files written before escaping existed
/// kept a '; ' inside a text value raw.
List<String> splitAttributePairs(String cell) {
  final pairs = <String>[];
  for (final item in splitCsvList(cell)) {
    final pair = unescapeCsvListItem(item);
    if (pairs.isNotEmpty && !pair.contains('=')) {
      pairs[pairs.length - 1] = '${pairs.last}; $pair';
    } else {
      pairs.add(pair);
    }
  }
  return pairs;
}

final _numberWithSymbol = RegExp(r'^(-?\d+(?:\.\d+)?)\s+(\S.*)$');

/// Reads one pair back. A curated key is read by its catalog kind; a
/// suffix-stripped key with a trailing symbol is converted back to metric;
/// anything else becomes a custom text attribute. Null when the pair has no
/// `=`, or a curated value cannot be read as its kind requires.
///
/// [dateFormat] is the format the file's date columns name; null means the
/// file is Metric (a date attribute is then epoch milliseconds).
CsvAttribute? parseAttributePair(
  String pair, {
  DateFormatPreference? dateFormat,
}) {
  final eq = pair.indexOf('=');
  if (eq <= 0) return null;
  final key = pair.substring(0, eq).trim();
  final value = pair.substring(eq + 1).trim();
  if (key.isEmpty || value.isEmpty) return null;
  if (key.startsWith(_customPrefix)) {
    final customKey = key.substring(_customPrefix.length);
    return customKey.isEmpty
        ? null
        : (key: customKey, isCustom: true, valueText: value, valueNum: null);
  }

  final def = EquipmentAttributeCatalog.defFor(key);
  if (def != null) return _readCurated(def, value, dateFormat);

  final unitDef = _defByMyUnitsKey[key];
  final match = _numberWithSymbol.firstMatch(value);
  if (unitDef != null && match != null) {
    final metric = _toMetric(
      unitDef.dimension,
      double.parse(match.group(1)!),
      match.group(2)!.trim(),
    );
    if (metric != null) {
      return (
        key: unitDef.key,
        isCustom: false,
        valueText: null,
        valueNum: metric,
      );
    }
  }
  return (key: key, isCustom: true, valueText: value, valueNum: null);
}

CsvAttribute? _readCurated(
  EquipmentAttributeDef def,
  String value,
  DateFormatPreference? dateFormat,
) {
  CsvAttribute withNumber(double n) =>
      (key: def.key, isCustom: false, valueText: null, valueNum: n);
  switch (def.kind) {
    case AttributeKind.number:
    case AttributeKind.flag:
      final n = double.tryParse(value);
      return n == null ? null : withNumber(n);
    case AttributeKind.date:
      final ms = double.tryParse(value);
      if (ms != null) return withNumber(ms);
      final date = parseCsvDate(value, dateFormat);
      if (date == null) return null;
      // Date attributes are stored as local midnight, as the date picker
      // writes them.
      return withNumber(
        DateTime(
          date.year,
          date.month,
          date.day,
        ).millisecondsSinceEpoch.toDouble(),
      );
    case AttributeKind.thickness:
      return (
        key: def.key,
        isCustom: false,
        valueText: value,
        valueNum: parsePrimaryThickness(value),
      );
    case AttributeKind.text:
    case AttributeKind.url:
    case AttributeKind.choice:
      return (key: def.key, isCustom: false, valueText: value, valueNum: null);
  }
}

/// Display value with [symbol] back to canonical metric. The inverse of
/// `attributeDisplayFromMetric`, keyed by the symbol the file wrote rather
/// than by the importing diver's settings.
double? _toMetric(AttributeDimension d, double n, String symbol) =>
    switch ((d, symbol)) {
      (AttributeDimension.massKg, 'kg') => n,
      (AttributeDimension.massKg, 'lbs') => WeightUnit.pounds.convert(
        n,
        WeightUnit.kilograms,
      ),
      (AttributeDimension.volumeL, 'L') => n,
      (AttributeDimension.volumeL, 'cuft') => VolumeUnit.cubicFeet.convert(
        n,
        VolumeUnit.liters,
      ),
      (AttributeDimension.pressureBar, 'bar') => n,
      (AttributeDimension.pressureBar, 'psi') => PressureUnit.psi.convert(
        n,
        PressureUnit.bar,
      ),
      (AttributeDimension.lengthM || AttributeDimension.depthM, 'm') => n,
      (AttributeDimension.lengthM || AttributeDimension.depthM, 'ft') =>
        DepthUnit.feet.convert(n, DepthUnit.meters),
      (AttributeDimension.shortLengthM, 'cm') => n / 100,
      (AttributeDimension.shortLengthM, 'in') => n * 2.54 / 100,
      (AttributeDimension.speedMps, 'm/min') => n / 60,
      (AttributeDimension.speedMps, 'ft/min') =>
        DepthUnit.feet.convert(n, DepthUnit.meters) / 60,
      (AttributeDimension.durationH, 'min') => n / 60,
      _ => null,
    };
