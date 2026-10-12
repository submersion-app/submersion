import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// Service kinds and clocks in a full UDDF backup (issue #2651).
///
/// Only custom kinds are written: built-in ids are fixed in every database.
/// A kind id is written as stored, built-in or custom, so a ref never needs
/// to know which it is. Clocks nest in their `<item>`, because a clock
/// cannot exist without one.
abstract final class UddfServiceClockWriters {
  /// Writes [kinds] as `<servicekinds>`; nothing when there are none.
  static void writeKinds(XmlBuilder builder, List<ServiceKind> kinds) {
    if (kinds.isEmpty) return;
    builder.element(
      'servicekinds',
      nest: () {
        for (final kind in kinds) {
          builder.element(
            'kind',
            attributes: {'id': kind.id},
            nest: () {
              builder.element('name', nest: kind.name);
              if (kind.applicableTypes.isNotEmpty) {
                builder.element(
                  'applicabletypes',
                  nest: () {
                    for (final type in kind.applicableTypes) {
                      builder.element('type', nest: type.name);
                    }
                  },
                );
              }
              _value(builder, 'intervaldays', kind.defaultIntervalDays);
              _value(builder, 'intervaldives', kind.defaultIntervalDives);
              _value(builder, 'intervalhours', kind.defaultIntervalHours);
              _exposure(builder, kind.exposureIntervals);
              _value(builder, 'defaultcost', kind.defaultCost);
              _value(builder, 'defaultcurrency', kind.defaultCurrency);
              _value(builder, 'defaultcategory', kind.defaultCategory?.name);
              builder.element('autoattach', nest: kind.autoAttach.toString());
            },
          );
        }
      },
    );
  }

  /// Writes an item's [schedules] as `<serviceschedules>`, empty when it
  /// has none, so a restore can tell "no clocks" from a file written before
  /// clocks travelled.
  static void writeSchedules(
    XmlBuilder builder,
    List<ServiceSchedule> schedules,
  ) {
    builder.element(
      'serviceschedules',
      nest: () {
        for (final s in schedules) {
          builder.element(
            'schedule',
            attributes: {'kindref': s.serviceKindId},
            nest: () {
              _value(builder, 'intervaldays', s.intervalDays);
              _value(builder, 'intervaldives', s.intervalDives);
              _value(builder, 'intervalhours', s.intervalHours);
              _exposure(builder, s.exposureIntervals);
              _value(builder, 'defaultcost', s.defaultCost);
              _value(builder, 'defaultcurrency', s.defaultCurrency);
              _value(
                builder,
                'anchordate',
                s.anchorDate?.toUtc().toIso8601String(),
              );
              _value(
                builder,
                'anchorsetat',
                s.anchorSetAt?.toUtc().toIso8601String(),
              );
              builder.element('enabled', nest: s.enabled.toString());
            },
          );
        }
      },
    );
  }

  static void _value(XmlBuilder builder, String name, Object? value) {
    if (value == null) return;
    final text = value.toString();
    if (text.isEmpty) return;
    builder.element(name, nest: text);
  }

  static void _exposure(XmlBuilder builder, Map<ExposureUnit, double> map) {
    for (final entry in map.entries) {
      builder.element(
        'exposureinterval',
        attributes: {'unit': entry.key.dbValue},
        nest: entry.value.toString(),
      );
    }
  }

  /// The kinds under [submersion]'s `<servicekinds>`; one without an id or
  /// a name is dropped.
  static List<Map<String, dynamic>> parseKinds(XmlElement submersion) {
    final section = submersion.findElements('servicekinds').firstOrNull;
    if (section == null) return const [];
    return [
      for (final element in section.findElements('kind')) ?_parseKind(element),
    ];
  }

  static Map<String, dynamic>? _parseKind(XmlElement e) {
    final id = e.getAttribute('id')?.trim();
    final name = _text(e, 'name');
    if (id == null || id.isEmpty || name == null) return null;
    final types = [
      for (final t
          in e
              .findElements('applicabletypes')
              .expand((a) => a.findElements('type')))
        if (t.innerText.trim() case final type when type.isNotEmpty) type,
    ];
    final exposures = _exposures(e);
    return {
      'id': id,
      'name': name,
      if (types.isNotEmpty) 'applicableTypes': types,
      'defaultIntervalDays': ?_int(e, 'intervaldays'),
      'defaultIntervalDives': ?_int(e, 'intervaldives'),
      'defaultIntervalHours': ?_double(e, 'intervalhours'),
      if (exposures.isNotEmpty) 'exposureIntervals': exposures,
      'defaultCost': ?_double(e, 'defaultcost'),
      'defaultCurrency': ?_text(e, 'defaultcurrency'),
      'defaultCategory': ?_text(e, 'defaultcategory'),
      'autoAttach': _text(e, 'autoattach')?.toLowerCase() == 'true',
    };
  }

  /// The clocks under [item]'s `<serviceschedules>`, or null when the item
  /// has no such element (a file from before clocks travelled); one without
  /// a kind ref is dropped.
  static List<Map<String, dynamic>>? parseSchedules(XmlElement item) {
    final section = item.findElements('serviceschedules').firstOrNull;
    if (section == null) return null;
    return [
      for (final element in section.findElements('schedule'))
        ?_parseSchedule(element),
    ];
  }

  static Map<String, dynamic>? _parseSchedule(XmlElement e) {
    final ref = e.getAttribute('kindref')?.trim();
    if (ref == null || ref.isEmpty) return null;
    final exposures = _exposures(e);
    return {
      'kindRef': ref,
      'intervalDays': ?_int(e, 'intervaldays'),
      'intervalDives': ?_int(e, 'intervaldives'),
      'intervalHours': ?_double(e, 'intervalhours'),
      if (exposures.isNotEmpty) 'exposureIntervals': exposures,
      'defaultCost': ?_double(e, 'defaultcost'),
      'defaultCurrency': ?_text(e, 'defaultcurrency'),
      'anchorDate': ?_date(e, 'anchordate'),
      'anchorSetAt': ?_date(e, 'anchorsetat'),
      'enabled': _text(e, 'enabled')?.toLowerCase() != 'false',
    };
  }

  /// Exposure intervals by unit name; a unit this build does not know, or
  /// a value that is not a number, is dropped.
  static Map<String, double> _exposures(XmlElement e) => {
    for (final x in e.findElements('exposureinterval'))
      if ((x.getAttribute('unit')?.trim(), double.tryParse(x.innerText.trim()))
          case (final String unit, final double value)
          when ExposureUnit.fromDbValue(unit) != null)
        unit: value,
  };

  static String? _text(XmlElement e, String name) =>
      UddfImportParsers.getElementText(e, name);

  static int? _int(XmlElement e, String name) =>
      int.tryParse(_text(e, name) ?? '');

  static double? _double(XmlElement e, String name) =>
      double.tryParse(_text(e, name) ?? '');

  /// A real instant (a clock baseline), returned in local time.
  static DateTime? _date(XmlElement e, String name) {
    final parsed = DateTime.tryParse(_text(e, name) ?? '');
    return parsed?.toLocal();
  }
}
