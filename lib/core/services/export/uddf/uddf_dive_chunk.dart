import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';

/// One run of a full UDDF backup's dives with the data that grows with their
/// recordings: the samples, the tank pressure series and the data source
/// rows (each one's own depth series and original bytes).
///
/// The backup asks for these a run at a time and lets each run go once its
/// dives are written, so its working memory follows the run, not the logbook
/// (issue #4249).
class UddfDiveChunk {
  const UddfDiveChunk({
    required this.dives,
    this.tankPressures = const {},
    this.sources = const [],
  });

  /// The run's dives, in the order they were asked for, each with its
  /// recorded profile attached.
  final List<Dive> dives;

  /// The run's tank pressure series, by dive id.
  final Map<String, DiveTankPressureExport> tankPressures;

  /// The run's data source rows, each dive's together and in ordinal order.
  final List<DiveSourceExport> sources;
}

/// Reads the [UddfDiveChunk] for [dives], a run of the backup's dives as the
/// dive list holds them (no profile attached).
typedef UddfDiveChunkLoader = Future<UddfDiveChunk> Function(List<Dive> dives);

/// A loader over data already in memory: [dives] as given (with whatever
/// profile each carries), and the pressures and sources of each run's dives.
///
/// For callers that already hold every dive's data, such as tests; the
/// settings export reads from the database instead, a run at a time.
UddfDiveChunkLoader inMemoryUddfDiveChunks({
  Map<String, DiveTankPressureExport> tankPressures = const {},
  List<DiveSourceExport> sources = const [],
}) {
  final sourcesByDive = <String, List<DiveSourceExport>>{};
  for (final source in sources) {
    (sourcesByDive[source.diveId] ??= []).add(source);
  }
  return (dives) async => UddfDiveChunk(
    dives: dives,
    tankPressures: {for (final dive in dives) dive.id: ?tankPressures[dive.id]},
    sources: [for (final dive in dives) ...?sourcesByDive[dive.id]],
  );
}

/// [dives] in the order the backup writes them: grouped by [dayOf], each
/// group where its first dive was, and in list order within a group.
///
/// `<profiledata>` holds one `<repetitiongroup>` per day, so a day's dives
/// must be written together. The dive list is newest first, which already
/// keeps each day's dives together, so this is usually the list itself.
List<Dive> uddfDiveWriteOrder(List<Dive> dives, String Function(Dive) dayOf) {
  final byDay = <String, List<Dive>>{};
  for (final dive in dives) {
    (byDay[dayOf(dive)] ??= []).add(dive);
  }
  return [for (final day in byDay.values) ...day];
}
