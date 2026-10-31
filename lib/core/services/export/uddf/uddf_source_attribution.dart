import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

/// Submersion's extension blocks that say which `<source>` of a dive
/// recorded what (issue #2492): each tank row, each tank pressure series,
/// and each depth series (issue #3965). The pressure series block is also
/// the one lossless record of a series, since the waypoints hold readings
/// only as they fall on the depth clock (issue #3917). A gas switch names
/// its computer the same way (#3966), in a `<computer>` of its own
/// `<gasswitch>`.
///
/// The standard `<tankpressure>` in a waypoint names a cylinder and nothing
/// else, and holds one reading per cylinder per sample. So a backup of a
/// dive two sources recorded wrote one merged list per tank, and the
/// restore filed every reading under one series, interleaving the two
/// recordings again (the #2440 zigzag). `<tankdata>` names no source or
/// computer either, so every restored tank row read as the primary
/// source's (#2716).
///
/// `<samples>` has the same problem with depth: it is one stream of every
/// source's readings interleaved, and a `<waypoint>` names no source, so a
/// restore gave the primary source all of them and the others none. It stays
/// that stream, which older builds and other applications read, and each
/// series travels again below.
///
/// Shared by the full backup and the dives-only export so the two cannot
/// drift apart. The blocks live in `<applicationdata><submersion>` beside
/// the `<datasources>` block whose entries they point at:
///
/// ```xml
/// <tanksources>
///   <tank diveref="dive_..." tankref="tank_..." source="1" computer="1"/>
/// </tanksources>
/// <tankpressureseries>
///   <series diveref="dive_..." tankref="tank_..." source="1" computer="1">
///     <sample divetime="12" pressure="198.5"/>
///   </series>
/// </tankpressureseries>
/// <sourceprofiles>
///   <series diveref="dive_..." source="1" computer="1" primary="false">
///     ...base64...
///   </series>
/// </sourceprofiles>
/// ```
///
/// `source` is the `ordinal` of a `<source>` entry of the same dive, which
/// is how that block identifies a source; it is absent when no source owned
/// the row. A row's `computer` is the ordinal of a source that computer
/// recorded, whose restored computer the row takes, so no second way of
/// naming a computer is needed; it is absent when the row named none. Each
/// series stays a series of its own, since one source can record a tank in
/// two stretches. Pressures are bar, unconverted, so a round trip is exact.
/// A `<sourceprofiles>` series is base64 over a [ProfileSeriesCodec] blob, as
/// `<dcdump>` is over a dump: every field of every sample, exactly, at a
/// fraction of the size of writing them out, since each of these recordings
/// is also in `<samples>`. `primary` is the series' own flag, not the source's.
///
/// A switch names its computer inside its `<gasswitch>`, because nothing in
/// the file identifies a switch for a block to point at: two computers can
/// log one second on one merged cylinder. It takes no `source`, as
/// `gas_switches` stores none.
class UddfSourceAttribution {
  const UddfSourceAttribution._();

  /// The keys the parsed blocks ride under on each dive's map, like the
  /// `dataSources` the import wizard keeps for the same reason (#1735).
  static const String seriesKey = 'tankPressureSeries';
  static const String tanksKey = 'tankSources';
  static const String profilesKey = 'sourceProfiles';

  /// [sources] by the dive each belongs to.
  static Map<String, List<DiveSourceExport>> groupByDive(
    List<DiveSourceExport> sources,
  ) {
    final byDive = <String, List<DiveSourceExport>>{};
    for (final source in sources) {
      (byDive[source.diveId] ??= []).add(source);
    }
    return byDive;
  }

  /// Writes the blocks for [dives], with their pressure series from
  /// [pressures] and their depth series from [sources]. Writes nothing when
  /// no dive has anything for them.
  ///
  /// Only a dive with two or more entries in [sources] has tank rows or
  /// depth series: one with a lone source restores every tank and sample
  /// under it, and one with none in the file (raw data left out) restores
  /// as a single new source. See [_seriesToWrite] for which pressure series
  /// each dive writes.
  static void write(
    XmlBuilder builder, {
    required List<Dive> dives,
    required Map<String, DiveTankPressureExport> pressures,
    required List<DiveSourceExport> sources,
  }) {
    final sourcesByDive = groupByDive(sources);
    List<DiveSourceExport> sourcesOf(Dive dive) =>
        sourcesByDive[dive.id] ?? const [];

    final tanks = [
      for (final dive in dives)
        if (sourcesOf(dive).length >= 2)
          for (final tank in dive.tanks)
            ?_tankRow(dive.id, tank, sourcesOf(dive)),
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
      for (final dive in dives)
        for (final s in _seriesToWrite(
          dive,
          pressures[dive.id],
          sourcesOf(dive),
        ))
          (
            dive.id,
            s,
            _ordinalOf(sourcesOf(dive), s.sourceId),
            _computerOrdinal(sourcesOf(dive), s.computerId, s.sourceId),
          ),
    ];
    if (series.isNotEmpty) {
      builder.element(
        'tankpressureseries',
        nest: () {
          for (final (diveId, s, ordinal, computer) in series) {
            builder.element(
              'series',
              attributes: {
                'diveref': 'dive_$diveId',
                'tankref': 'tank_${s.tankId}',
                'source': ?ordinal?.toString(),
                'computer': ?computer?.toString(),
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

    _writeProfiles(builder, [
      for (final dive in dives)
        if (sourcesOf(dive).length >= 2) sourcesOf(dive),
    ]);
  }

  /// The `<sourceprofiles>` block for [sourcesPerDive], each list being one
  /// dive's sources; nothing when none of them owns a depth series.
  static void _writeProfiles(
    XmlBuilder builder,
    List<List<DiveSourceExport>> sourcesPerDive,
  ) {
    final series = [
      for (final sources in sourcesPerDive)
        for (final source in sources)
          for (final s in source.profileSeries) (sources, source.diveId, s),
    ];
    if (series.isEmpty) return;
    builder.element(
      'sourceprofiles',
      nest: () {
        for (final (sources, diveId, s) in series) {
          final ordinal = _ordinalOf(sources, s.sourceId);
          final computer = _computerOrdinal(sources, s.computerId, s.sourceId);
          builder.element(
            'series',
            attributes: {
              'diveref': 'dive_$diveId',
              'source': ?ordinal?.toString(),
              'computer': ?computer?.toString(),
              'primary': '${s.isPrimary}',
            },
            nest: base64Encode(s.blob),
          );
        }
      },
    );
  }

  /// Whether any of [dives] writes a series of its own, for a file that
  /// would otherwise have no `<applicationdata>` to put the block in.
  static bool hasSeries({
    required List<Dive> dives,
    required Map<String, DiveTankPressureExport> pressures,
    required List<DiveSourceExport> sources,
  }) {
    final sourcesByDive = groupByDive(sources);
    return dives.any(
      (dive) => _seriesToWrite(
        dive,
        pressures[dive.id],
        sourcesByDive[dive.id] ?? const [],
      ).isNotEmpty,
    );
  }

  /// The series of [dive] that go in the block, given its entries in
  /// [sources].
  ///
  /// With two or more sources, all of them: the block says who recorded
  /// each. With fewer, a restore has one source to give them to, so only
  /// the series the app draws can go, since two recordings of one stretch
  /// under one source would interleave (#2440). Even those are left to the
  /// samples when the samples restore them exactly, which is most dives:
  /// their readings share the depth clock.
  static List<TankPressureSeries> _seriesToWrite(
    Dive dive,
    DiveTankPressureExport? pressures,
    List<DiveSourceExport> sources,
  ) {
    if (pressures == null) return const [];
    if (sources.length >= 2) return pressures.series;
    return _samplesRestore(dive, pressures.displayedByTank)
        ? const []
        : pressures.displayedSeries;
  }

  /// Whether the `<tankpressure>` elements of [dive]'s waypoints read back
  /// as exactly [byTank]. A reading no depth sample is near is lost, one
  /// merely near a depth sample comes back at that sample's time, and one
  /// near several comes back once for each.
  static bool _samplesRestore(
    Dive dive,
    Map<String, List<TankPressurePoint>> byTank,
  ) => byTank.values.every((points) {
    final restored = [
      for (final point in dive.profile)
        if (findPressureAtTimestamp(points, point.timestamp)
            case final pressure?)
          (point.timestamp, pressure),
    ];
    return const ListEquality<(int, double)>().equals(restored, [
      for (final point in points) (point.timestamp, point.pressure),
    ]);
  });

  /// Find pressure at a given timestamp using binary search.
  /// Points must be sorted by timestamp (ascending).
  /// Returns null if no point exists within 2 seconds of [timestamp].
  static double? findPressureAtTimestamp(
    List<TankPressurePoint> points,
    int timestamp,
  ) {
    if (points.isEmpty) return null;

    // Binary search for the insertion point
    int low = 0;
    int high = points.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (points[mid].timestamp < timestamp) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    // Check the two candidates (before and at insertion point)
    const maxDiff = 3; // exclusive, so diffs of 0, 1 and 2 are accepted
    TankPressurePoint? closest;
    int minDiff = maxDiff;

    if (low > 0) {
      final diff = (points[low - 1].timestamp - timestamp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = points[low - 1];
      }
    }
    if (low < points.length) {
      final diff = (points[low].timestamp - timestamp).abs();
      if (diff < minDiff) {
        closest = points[low];
      }
    }

    return closest?.pressure;
  }

  /// Writes the `<computer>` of a `<gasswitch>` that [computerId] logged, the
  /// ordinal of one of its dive's [sources] that computer recorded. Writes
  /// nothing for a switch with no computer, which stays the whole dive's, or
  /// one no source recorded.
  ///
  /// A dive with one source needs this too, unlike the tank rows: that source
  /// adopts what a restore cannot place, but a switch left unattributed
  /// applies to every computer rather than to it.
  static void writeSwitchComputer(
    XmlBuilder builder,
    String? computerId,
    List<DiveSourceExport> sources,
  ) {
    final ordinal = _computerOrdinal(sources, computerId, null);
    if (ordinal != null) {
      builder.element('computer', nest: ordinal.toString());
    }
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
    final computer = _computerOrdinal(sources, tank.computerId, tank.sourceId);
    if (source == null && computer == null) return null;
    return {
      'diveref': 'dive_$diveId',
      'tankref': 'tank_${tank.id}',
      'source': ?source?.toString(),
      'computer': ?computer?.toString(),
    };
  }

  /// The ordinal of a source in [sources] that [computerId] recorded: the
  /// row's own source ([sourceId]) when it did, else the first that did.
  /// Null for no computer, or one none of [sources] recorded.
  static int? _computerOrdinal(
    List<DiveSourceExport> sources,
    String? computerId,
    String? sourceId,
  ) {
    if (computerId == null) return null;
    final ofComputer = [
      for (final s in sources)
        if (s.computerId == computerId) s,
    ];
    return (ofComputer.where((s) => s.id == sourceId).firstOrNull ??
            ofComputer.firstOrNull)
        ?.ordinal;
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
  /// Each entry holds `tankRef` (the `<tankdata>` id), `sourceOrdinal` and
  /// `computerOrdinal` (either null when absent) and `samples`. A sample
  /// whose time or finite pressure cannot be read is dropped, and a series
  /// without a dive or tank ref, or with no readable sample, is skipped: it
  /// names nothing to restore.
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
            // tryParse accepts NaN and Infinity, which are no reading.
            if (double.tryParse(sample.getAttribute('pressure') ?? '')
                case final pressure? when pressure.isFinite)
              (timestamp: timestamp, pressure: pressure),
      ];
      if (samples.isEmpty) continue;
      byDiveRef.putIfAbsent(diveRef, () => []).add({
        'tankRef': tankRef,
        'sourceOrdinal': _int(series, 'source'),
        'computerOrdinal': _int(series, 'computer'),
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

  /// Every `<series>` of every `<sourceprofiles>` block, keyed by its
  /// `diveref`, in document order.
  ///
  /// Each entry holds `sourceOrdinal` and `computerOrdinal` (either null when
  /// absent), `isPrimary` and `blob`, the series' base64 text. Nothing decodes
  /// it here: a dive not selected for import never needs its samples.
  static Map<String, List<Map<String, dynamic>>> parseProfiles(
    XmlElement uddfElement,
  ) {
    final byDiveRef = <String, List<Map<String, dynamic>>>{};
    for (final (diveRef, series) in _diveRows(
      uddfElement,
      'sourceprofiles',
      'series',
    )) {
      byDiveRef.putIfAbsent(diveRef, () => []).add({
        'sourceOrdinal': _int(series, 'source'),
        'computerOrdinal': _int(series, 'computer'),
        'isPrimary': series.getAttribute('primary') == 'true',
        'blob': series.innerText.trim(),
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
    for (final (diveRef, row) in _diveRows(uddfElement, blockName, rowName)) {
      final tankRef = row.getAttribute('tankref');
      if (tankRef == null || tankRef.isEmpty) continue;
      yield (diveRef, tankRef, row);
    }
  }

  /// The [rowName] children of every [blockName] block, with their dive ref;
  /// a row without one is skipped.
  static Iterable<(String, XmlElement)> _diveRows(
    XmlElement uddfElement,
    String blockName,
    String rowName,
  ) sync* {
    for (final appData in uddfElement.findElements('applicationdata')) {
      for (final submersion in appData.findElements('submersion')) {
        for (final block in submersion.findElements(blockName)) {
          for (final row in block.findElements(rowName)) {
            final diveRef = row.getAttribute('diveref');
            if (diveRef == null || diveRef.isEmpty) continue;
            yield (diveRef, row);
          }
        }
      }
    }
  }

  static int? _int(XmlElement element, String name) =>
      int.tryParse(element.getAttribute(name) ?? '');
}
