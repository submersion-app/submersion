import 'dart:math' as math;

import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/csv/codec/csv_text.dart'
    show trimFixed;
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Cylinder fills in a full UDDF backup (issue #2651): a
/// `<cylinderfills>` section under `<applicationdata><submersion>`, one
/// `<fill>` per record keyed by passport id rather than by an item, so a
/// fill with no cylinder row survives too.
///
/// Values are in UDDF's SI units, as `<mix>` and `<tankdata>`: fractions
/// for O2 and He, pascal and kelvin. The parser rounds them back so a
/// stored 32 % returns as exactly 32, and returns the keys the fills CSV
/// parser emits, so CsvFillImporter stores both formats the same way.
abstract final class UddfFillWriters {
  static const _idPrefix = 'fill_';
  static const _pascalPerBar = 100000.0;
  static const _kelvinOffset = 273.15;

  /// Writes [fills] in their order; nothing at all when there are none.
  /// The reserved signing fields, the diver and the equipment link are left
  /// out: the importing diver owns the copy, and linking is by passport id.
  static void writeFills(XmlBuilder builder, List<CylinderFill> fills) {
    if (fills.isEmpty) return;
    builder.element(
      'cylinderfills',
      nest: () {
        for (final fill in fills) {
          _writeFill(builder, fill);
        }
      },
    );
  }

  static void _writeFill(XmlBuilder builder, CylinderFill fill) {
    builder.element(
      'fill',
      attributes: {'id': '$_idPrefix${fill.id}'},
      nest: () {
        builder.element('passportid', nest: fill.passportId);
        builder.element(
          'datetime',
          nest: fill.filledAt.toUtc().toIso8601String(),
        );
        builder.element('o2', nest: trimFixed(fill.o2Percent / 100, 4));
        builder.element('he', nest: trimFixed(fill.hePercent / 100, 4));
        if (fill.pressureBar case final bar?) {
          builder.element(
            'pressure',
            nest: (bar * _pascalPerBar).round().toString(),
          );
        }
        if (fill.temperatureC case final celsius?) {
          builder.element(
            'temperature',
            nest: trimFixed(celsius + _kelvinOffset, 2),
          );
        }
        _text(builder, 'analyzer', fill.analyzer);
        _text(builder, 'filledby', fill.stationName);
        builder.element('source', nest: fill.source.name);
        _text(builder, 'notes', fill.notes);
      },
    );
  }

  static void _text(XmlBuilder builder, String name, String? value) {
    if (value == null || value.isEmpty) return;
    builder.element(name, nest: value);
  }

  /// The fills under [submersion]'s `<cylinderfills>`, or none. A fill
  /// without an id, a passport id, a readable time or an O2 value is
  /// dropped; the gas-mix check stays with CsvFillImporter.fromPayload.
  static List<Map<String, dynamic>> parseFills(XmlElement submersion) {
    final section = submersion.findElements('cylinderfills').firstOrNull;
    if (section == null) return const [];
    return [
      for (final element in section.findElements('fill')) ?_parseFill(element),
    ];
  }

  static Map<String, dynamic>? _parseFill(XmlElement element) {
    final rawId = element.getAttribute('id')?.trim();
    final id = rawId != null && rawId.startsWith(_idPrefix)
        ? rawId.substring(_idPrefix.length)
        : rawId;
    final passportId = _read(element, 'passportid');
    // A fill time is a real instant, not a dive's wall clock: local, like
    // the fills CSV and the Log fill sheet. A zoneless value already parses
    // as local wall clock.
    final parsed = DateTime.tryParse(_read(element, 'datetime') ?? '');
    final filledAt = parsed?.toLocal();
    final o2 = _number(element, 'o2');
    if (id == null ||
        id.isEmpty ||
        passportId == null ||
        filledAt == null ||
        o2 == null) {
      return null;
    }
    // Helium may be left out (or blank) for none, but a value that is there
    // and unreadable rejects the fill rather than restoring it as air, as
    // the fills CSV does.
    final heText = _read(element, 'he');
    final he = heText == null ? null : double.tryParse(heText);
    if (heText != null && he == null) return null;
    final pascal = _number(element, 'pressure');
    final kelvin = _number(element, 'temperature');
    return {
      'uddfId': id,
      'id': id,
      'passportId': passportId,
      'filledAt': filledAt,
      'o2Percent': _round(o2 * 100, 2),
      'hePercent': he == null ? 0.0 : _round(he * 100, 2),
      if (pascal != null) 'pressureBar': _round(pascal / _pascalPerBar, 3),
      if (kelvin != null) 'temperatureC': _round(kelvin - _kelvinOffset, 2),
      'analyzer': ?_read(element, 'analyzer'),
      'stationName': ?_read(element, 'filledby'),
      'source': ?_read(element, 'source'),
      'notes': ?_read(element, 'notes'),
    };
  }

  static String? _read(XmlElement element, String name) =>
      UddfImportParsers.getElementText(element, name);

  static double? _number(XmlElement element, String name) =>
      double.tryParse(_read(element, name) ?? '');

  static double _round(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).round() / factor;
  }
}
