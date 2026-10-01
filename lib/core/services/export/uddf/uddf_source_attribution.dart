import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';

/// Submersion's extension blocks that say which `<source>` of a dive
/// recorded what (issue #2492): each tank row, and each tank pressure
/// series.
///
/// The standard `<tankpressure>` in a waypoint names a cylinder and nothing
/// else, and holds one reading per cylinder per sample. So a backup of a
/// dive two sources recorded wrote one merged list per tank, and the
/// restore filed every reading under one series, interleaving the two
/// recordings again (the #2440 zigzag). `<tankdata>` names no source or
/// computer either, so every restored tank row read as the primary
/// source's (#2716).
///
/// Shared by the full backup and the dives-only export so the two cannot
/// drift apart. Both blocks live in `<applicationdata><submersion>` beside
/// the `<datasources>` block whose entries they point at:
///
/// ```xml
/// <tanksources>
///   <tank diveref="dive_..." tankref="tank_..." source="1" computer="1"/>
/// </tanksources>
/// <tankpressureseries>
///   <series diveref="dive_..." tankref="tank_..." source="1">
///     <sample divetime="12" pressure="198.5"/>
///   </series>
/// </tankpressureseries>
/// ```
///
/// `source` is the `ordinal` of a `<source>` entry of the same dive, which
/// is how that block identifies a source; it is absent when no source owned
/// the row. A tank's `computer` is the ordinal of a source that computer
/// recorded, whose restored computer the tank takes, so no second way of
/// naming a computer is needed. Pressures are bar, unconverted, so a round
/// trip is exact.
class UddfSourceAttribution {
  const UddfSourceAttribution._();

  /// The keys the parsed blocks ride under on each dive's map, like the
  /// `dataSources` the import wizard keeps for the same reason (#1735).
  static const String seriesKey = 'tankPressureSeries';
  static const String tanksKey = 'tankSources';

  /// Writes both blocks for every dive of [dives] that has two or more
  /// entries in [sources], with its series from [pressures]. Writes nothing
  /// when no dive does.
  ///
  /// A dive with one source needs neither: the restore gives that lone
  /// source every series it writes from the samples and every tank it can
  /// claim. A dive with none in the file (raw data left out) restores as a
  /// single new source, so the blocks could not keep anything apart either.
  static void write(
    XmlBuilder builder, {
    required List<Dive> dives,
    required Map<String, DiveTankPressureExport> pressures,
    required List<DiveSourceExport> sources,
  }) {
    final sourcesByDive = <String, List<DiveSourceExport>>{};
    for (final source in sources) {
      (sourcesByDive[source.diveId] ??= []).add(source);
    }
    final attributed = [
      for (final dive in dives)
        if ((sourcesByDive[dive.id]?.length ?? 0) >= 2) dive,
    ];
    if (attributed.isEmpty) return;

    final tanks = [
      for (final dive in attributed)
        for (final tank in dive.tanks)
          ?_tankRow(dive.id, tank, sourcesByDive[dive.id]!),
    ];
    if (tanks.isNotEmpty) {
      builder.element(
        'tanksources',
        nest: () {
          for (final attributes in tanks) {
            builder.element('tank', attributes: attributes);
          }
        },
      );
    }

    final series = [
      for (final dive in attributed)
        for (final s in pressures[dive.id]?.series ?? const [])
          (dive.id, s, _ordinalOf(sourcesByDive[dive.id]!, s.sourceId)),
    ];
    if (series.isEmpty) return;
    builder.element(
      'tankpressureseries',
      nest: () {
        for (final (diveId, s, ordinal) in series) {
          builder.element(
            'series',
            attributes: {
              'diveref': 'dive_$diveId',
              'tankref': 'tank_${s.tankId}',
              'source': ?ordinal?.toString(),
            },
            nest: () {
              for (final sample in s.samples) {
                builder.element(
                  'sample',
                  attributes: {
                    'divetime': '${sample.timestamp}',
                    'pressure': '${sample.pressure}',
                  },
                );
              }
            },
          );
        }
      },
    );
  }

  /// The `<tank>` attributes for [tank], or null when neither its source
  /// nor its computer is one of [sources]: a hand-added tank, or one whose
  /// source was never recorded, restores as it is written today.
  static Map<String, String>? _tankRow(
    String diveId,
    DiveTank tank,
    List<DiveSourceExport> sources,
  ) {
    final source = _ordinalOf(sources, tank.sourceId);
    // The tank's own source when that recorded its computer, else the
    // first source that did.
    final ofComputer = [
      if (tank.computerId != null)
        for (final s in sources)
          if (s.computerId == tank.computerId) s,
    ];
    final computer =
        (ofComputer.where((s) => s.id == tank.sourceId).firstOrNull ??
                ofComputer.firstOrNull)
            ?.ordinal;
    if (source == null && computer == null) return null;
    return {
      'diveref': 'dive_$diveId',
      'tankref': 'tank_${tank.id}',
      'source': ?source?.toString(),
      'computer': ?computer?.toString(),
    };
  }

  static int? _ordinalOf(List<DiveSourceExport> sources, String? sourceId) {
    if (sourceId == null) return null;
    for (final s in sources) {
      if (s.id == sourceId) return s.ordinal;
    }
    return null;
  }

  /// Every `<series>` in [uddfElement]'s `<applicationdata><submersion>`
  /// blocks, keyed by its `diveref`, in document order.
  ///
  /// Each entry holds `tankRef` (the `<tankdata>` id), `sourceOrdinal`
  /// (null when absent) and `samples`. A series without a dive or tank ref,
  /// or with no readable sample, is skipped: it names nothing to restore.
  static Map<String, List<Map<String, dynamic>>> parseSeries(
    XmlElement uddfElement,
  ) {
    final byDiveRef = <String, List<Map<String, dynamic>>>{};
    for (final (diveRef, tankRef, series) in _rows(
      uddfElement,
      'tankpressureseries',
      'series',
    )) {
      final samples = <({int timestamp, double pressure})>[
        for (final sample in series.findElements('sample'))
          if (int.tryParse(sample.getAttribute('divetime') ?? '')
              case final timestamp?)
            if (double.tryParse(sample.getAttribute('pressure') ?? '')
                case final pressure?)
              (timestamp: timestamp, pressure: pressure),
      ];
      if (samples.isEmpty) continue;
      byDiveRef.putIfAbsent(diveRef, () => []).add({
        'tankRef': tankRef,
        'sourceOrdinal': _int(series, 'source'),
        'samples': samples,
      });
    }
    return byDiveRef;
  }

  /// Every `<tank>` in [uddfElement]'s `<tanksources>` blocks, keyed by its
  /// `diveref`, each holding `tankRef`, `sourceOrdinal` and
  /// `computerOrdinal` (either null when absent). A row naming neither is
  /// skipped.
  static Map<String, List<Map<String, dynamic>>> parseTanks(
    XmlElement uddfElement,
  ) {
    final byDiveRef = <String, List<Map<String, dynamic>>>{};
    for (final (diveRef, tankRef, tank) in _rows(
      uddfElement,
      'tanksources',
      'tank',
    )) {
      final source = _int(tank, 'source');
      final computer = _int(tank, 'computer');
      if (source == null && computer == null) continue;
      byDiveRef.putIfAbsent(diveRef, () => []).add({
        'tankRef': tankRef,
        'sourceOrdinal': source,
        'computerOrdinal': computer,
      });
    }
    return byDiveRef;
  }

  /// The [rowName] children of every [blockName] block, with their dive and
  /// tank refs; a row missing either is skipped.
  static Iterable<(String, String, XmlElement)> _rows(
    XmlElement uddfElement,
    String blockName,
    String rowName,
  ) sync* {
    for (final appData in uddfElement.findElements('applicationdata')) {
      for (final submersion in appData.findElements('submersion')) {
        for (final block in submersion.findElements(blockName)) {
          for (final row in block.findElements(rowName)) {
            final diveRef = row.getAttribute('diveref');
            final tankRef = row.getAttribute('tankref');
            if (diveRef == null || diveRef.isEmpty) continue;
            if (tankRef == null || tankRef.isEmpty) continue;
            yield (diveRef, tankRef, row);
          }
        }
      }
    }
  }

  static int? _int(XmlElement element, String name) =>
      int.tryParse(element.getAttribute(name) ?? '');
}
