import 'package:submersion/core/services/export/uddf/uddf_source_attribution.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Pressures by the `ordinal` of the `<source>` that recorded them (null for
/// none), then by restored tank id.
typedef PressuresBySourceOrdinal =
    Map<int?, Map<String, List<({int timestamp, double pressure})>>>;

/// The pressures of [diveData]'s per-source tank series (issue #2492),
/// keyed by the `ordinal` of the `<source>` that recorded them (null for a
/// series no source owned), then by the id of the restored tank.
///
/// [tanks] are the dive's tanks as the importer built them, in the order of
/// the parsed `tanks` list, whose `uddfTankId` is what a series' `tankRef`
/// names. A series naming no tank of the dive is dropped. Two series of one
/// source and tank are joined in time order.
///
/// Empty when the dive carries no series block, which leaves the restore to
/// the waypoint pressures as before.
PressuresBySourceOrdinal restoredTankPressureSeries(
  Map<String, dynamic> diveData,
  List<DiveTank> tanks,
) {
  final entries = diveData[UddfSourceAttribution.seriesKey];
  if (entries is! List || entries.isEmpty) return const {};
  final tankIdByRef = _tankIdByRef(diveData, tanks);

  final PressuresBySourceOrdinal result = {};
  for (final entry in entries.cast<Map<String, dynamic>>()) {
    final tankId = tankIdByRef[entry['tankRef']];
    if (tankId == null) continue;
    final samples =
        entry['samples'] as List<({int timestamp, double pressure})>;
    ((result[entry['sourceOrdinal'] as int?] ??= {})[tankId] ??= []).addAll(
      samples,
    );
  }
  return {
    for (final bySource in result.entries)
      bySource.key: {
        for (final byTank in bySource.value.entries)
          byTank.key: [...byTank.value]
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      },
  };
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
  final tankIdByRef = _tankIdByRef(diveData, tanks);
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
/// [tanks] are built in the order of the parsed `tanks` list.
Map<String, String> _tankIdByRef(
  Map<String, dynamic> diveData,
  List<DiveTank> tanks,
) {
  final tanksData = diveData['tanks'];
  return {
    if (tanksData is List)
      for (var i = 0; i < tanksData.length && i < tanks.length; i++)
        if ((tanksData[i] as Map)['uddfTankId'] case final String ref)
          ref: tanks[i].id,
  };
}
