import 'package:xml/xml.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A rebreather dive's settings and per-sample oxygen data in UDDF, shared by
/// the full backup and the dives-only export (issue #4178).
///
/// UDDF reads a cell reading as a `<measuredpo2 ref>` naming an `<o2sensor>`
/// the owner's `<rebreather>` declares, so the cells are declared once per
/// document and every waypoint names them. Values are in bar, as the setpoint
/// and loop ppO2 always were; the importer tells bar from Pascal by size.
abstract final class UddfRebreatherWriters {
  /// The id the owner's `<rebreather>` is declared under.
  static const rebreatherId = 'o2cells';

  /// The id cell [index] (zero based) is declared under.
  static String cellRef(int index) => 'o2cell_${index + 1}';

  static List<double?> _cells(DiveProfilePoint p) => [
    p.o2Sensor1,
    p.o2Sensor2,
    p.o2Sensor3,
    p.o2Sensor4,
    p.o2Sensor5,
    p.o2Sensor6,
  ];

  static List<int?> _millivolts(DiveProfilePoint p) => [
    p.o2SensorMv1,
    p.o2SensorMv2,
    p.o2SensorMv3,
    p.o2SensorMv4,
    p.o2SensorMv5,
    p.o2SensorMv6,
  ];

  /// How many cells the document declares for [dives]: up to the highest
  /// cell any sample has a reading or a millivolt value for, so a gap in the
  /// middle keeps every later cell in its place. Zero when none has either.
  static int cellCount(Iterable<Dive> dives) {
    const max = UddfImportParsers.maxO2Sensors;
    var count = 0;
    for (final dive in dives) {
      for (final point in dive.profile) {
        final cells = _cells(point);
        final millivolts = _millivolts(point);
        for (var i = count; i < max; i++) {
          if (cells[i] != null || millivolts[i] != null) count = i + 1;
        }
        if (count == max) return max;
      }
    }
    return count;
  }

  /// Declares [count] cells inside the owner's `<equipment>`. Writes nothing
  /// for zero.
  static void writeCellDeclarations(XmlBuilder builder, int count) {
    if (count == 0) return;
    builder.element(
      'rebreather',
      attributes: {'id': rebreatherId},
      nest: () {
        for (var i = 0; i < count; i++) {
          builder.element('o2sensor', attributes: {'id': cellRef(i)});
        }
      },
    );
  }

  /// [point]'s oxygen data, inside its `<waypoint>`.
  ///
  /// `<setpoint>` and a bare `<ppo2>` are the names Submersion has always
  /// written for the setpoint and the loop's ppO2. Each cell's millivolts go
  /// in a `<measuredmillivolts ref>`, Submersion's own element: UDDF has none.
  static void writeSample(XmlBuilder builder, DiveProfilePoint point) {
    if (point.setpoint case final setpoint?) {
      builder.element('setpoint', nest: setpoint.toString());
    }
    if (point.ppO2 case final ppO2?) {
      builder.element('ppo2', nest: ppO2.toString());
    }
    for (final (index, value) in _cells(point).indexed) {
      if (value == null) continue;
      builder.element(
        'measuredpo2',
        attributes: {'ref': cellRef(index)},
        nest: value.toString(),
      );
    }
    for (final (index, value) in _millivolts(point).indexed) {
      if (value == null) continue;
      builder.element(
        'measuredmillivolts',
        attributes: {'ref': cellRef(index)},
        nest: value.toString(),
      );
    }
  }

  /// [dive]'s rebreather settings in a dive level `<rebreather>`. Writes
  /// nothing for an open circuit dive.
  static void writeConfiguration(XmlBuilder builder, Dive dive) {
    if (dive.diveMode == DiveMode.oc) return;
    builder.element(
      'rebreather',
      nest: () {
        builder.element('divemode', nest: dive.diveMode.name);
        final values = <String, Object?>{
          // CCR setpoints
          'setpointlow': dive.setpointLow,
          'setpointhigh': dive.setpointHigh,
          'setpointdeco': dive.setpointDeco,
          // SCR configuration
          'scrtype': dive.scrType?.name,
          'scrinjectionrate': dive.scrInjectionRate,
          'scradditionratio': dive.scrAdditionRatio,
          'scrorificesize': dive.scrOrificeSize,
          'assumedvo2': dive.assumedVo2,
          // Diluent gas
          'diluento2': dive.diluentGas?.o2,
          'diluenthe': dive.diluentGas?.he,
          // Loop FO2 measurements
          'loopo2min': dive.loopO2Min,
          'loopo2max': dive.loopO2Max,
          'loopo2avg': dive.loopO2Avg,
          // Scrubber and loop
          'loopvolume': dive.loopVolume,
          'scrubbertype': dive.scrubber?.type,
          'scrubberdurationminutes': dive.scrubber?.ratedMinutes,
          'scrubberremainingminutes': dive.scrubber?.remainingMinutes,
        };
        for (final MapEntry(:key, :value) in values.entries) {
          if (value != null) builder.element(key, nest: value.toString());
        }
      },
    );
  }
}
