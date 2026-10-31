import 'package:submersion/core/services/export/uddf/uddf_source_attribution.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One series of a backup's per-source block, resolved to a restored tank:
/// the `ordinal`s of the `<source>` that recorded it and of one its computer
/// recorded (either null when the file names none).
typedef RestoredTankSeries = ({
  String tankId,
  int? sourceOrdinal,
  int? computerOrdinal,
  List<({int timestamp, double pressure})> samples,
});

/// [diveData]'s per-source tank series (issue #2492), each still a series
/// of its own: one source can record a tank in two stretches with another
/// source's recording between them, and joining the two would make them
/// span the other.
///
/// [tankIds] are the ids of the dive's tanks, in the order of the parsed
/// `tanks` list, whose `uddfTankId` is what a series' `tankRef` names. A
/// series naming no tank of the dive is dropped.
///
/// Empty when the dive carries no series block, which leaves the restore to
/// the waypoint pressures as before.
List<RestoredTankSeries> restoredTankPressureSeries(
  Map<String, dynamic> diveData,
  List<String> tankIds,
) {
  final entries = diveData[UddfSourceAttribution.seriesKey];
  if (entries is! List || entries.isEmpty) return const [];
  final tankIdByRef = _tankIdByRef(diveData, tankIds);
  return [
    for (final entry in entries.cast<Map<String, dynamic>>())
      if (tankIdByRef[entry['tankRef']] case final tankId?)
        (
          tankId: tankId,
          sourceOrdinal: entry['sourceOrdinal'] as int?,
          computerOrdinal: entry['computerOrdinal'] as int?,
          samples: entry['samples'] as List<({int timestamp, double pressure})>,
        ),
  ];
}

/// The data source and computer each restored tank of [diveData] came from
/// (issues #2492, #2716), keyed by restored tank id, from its `tankSources`
/// rows. [sourceIdByOrdinal] and [computerIdByOrdinal] are the restored
/// source rows and their computers by `<source>` ordinal; an ordinal with
/// no restored row leaves that half of the tank unattributed, and a tank
/// left with neither is absent.
Map<String, ({String? sourceId, String? computerId})> restoredTankAttribution(
  Map<String, dynamic> diveData,
  List<DiveTank> tanks, {
  required Map<int, String> sourceIdByOrdinal,
  required Map<int, String?> computerIdByOrdinal,
}) {
  final rows = diveData[UddfSourceAttribution.tanksKey];
  if (rows is! List || rows.isEmpty) return const {};
  final tankIdByRef = _tankIdByRef(diveData, [
    for (final tank in tanks) tank.id,
  ]);
  return {
    for (final row in rows.cast<Map<String, dynamic>>())
      if (tankIdByRef[row['tankRef']] case final tankId?)
        if ((
              sourceId: sourceIdByOrdinal[row['sourceOrdinal']],
              computerId: computerIdByOrdinal[row['computerOrdinal']],
            )
            case final attribution
            when attribution.sourceId != null || attribution.computerId != null)
          tankId: attribution,
  };
}

/// Restored tank id by the `<tankdata>` id the file declared it under.
/// [tankIds] are in the order of the parsed `tanks` list.
Map<String, String> _tankIdByRef(
  Map<String, dynamic> diveData,
  List<String> tankIds,
) {
  final tanksData = diveData['tanks'];
  return {
    if (tanksData is List)
      for (var i = 0; i < tanksData.length && i < tankIds.length; i++)
        if ((tanksData[i] as Map)['uddfTankId'] case final String ref)
          ref: tankIds[i],
  };
}
