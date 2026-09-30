import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion;
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/features/dive_import/data/services/imported_profile_readers.dart';
import 'package:submersion/features/dive_import/data/services/parsed_profile_event_mapper.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:uuid/uuid.dart';

/// Writes the further computers a parsed dive carries under
/// `additionalComputers`, each as a non-primary source of the stored dive
/// with its own profile, tank pressures and events (issue #2672).
///
/// A parser emits these when one dive in the file holds several computers'
/// recordings, as a Subsurface `<dive>` with more than one `<divecomputer>`
/// does. The dive itself, and its primary source, come from the first
/// computer; this runs after that primary source exists.
class AdditionalComputerWriter {
  AdditionalComputerWriter({
    required DiveRepository diveRepository,
    required TankPressureRepository tankPressureRepository,
  }) : _dives = diveRepository,
       _tankPressures = tankPressureRepository;

  final DiveRepository _dives;
  final TankPressureRepository _tankPressures;
  static const _uuid = Uuid();
  static const _log = LoggerService('AdditionalComputerWriter');

  /// The further computers a parsed dive map carries; empty when none.
  static List<Map<String, dynamic>> entriesOf(Map<String, dynamic> diveData) {
    final raw = diveData['additionalComputers'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Writes every entry of [diveData] onto the stored dive [diveId].
  ///
  /// [primaryComputerId] is the registered computer of the dive's primary
  /// source. Two rows of one dive that share a computer collapse into one
  /// source on read, so an entry resolving to a computer already on the dive
  /// (two of one model with no serial) is written with none rather than
  /// hidden behind the other. [computerIdFor] resolves an entry's registered
  /// computer. [entryTime] is the dive's start: each computer's is offset
  /// from it by its `timeOffsetSeconds`, and so are its samples and events,
  /// putting them on the dive's timeline as a consolidation does.
  ///
  /// Best-effort per computer: the dive is already committed, so a throw
  /// here would abort the rest of the import. A computer that cannot be
  /// written is logged and skipped, and the others are still written.
  Future<void> write({
    required Map<String, dynamic> diveData,
    required String diveId,
    required DateTime? entryTime,
    required List<DiveTank> tanks,
    required String? primaryComputerId,
    required String? Function(Map<String, dynamic> entry) computerIdFor,
    required String? sourceFileName,
    required String sourceFileFormat,
    required DateTime now,
    void Function(String message)? onSkippedEvent,
  }) async {
    final usedComputerIds = {?primaryComputerId};
    for (final entry in entriesOf(diveData)) {
      var computerId = computerIdFor(entry);
      if (computerId != null && !usedComputerIds.add(computerId)) {
        computerId = null;
      }
      try {
        await _writeOne(
          entry,
          diveId: diveId,
          entryTime: entryTime,
          tanks: tanks,
          computerId: computerId,
          sourceFileName: sourceFileName,
          sourceFileFormat: sourceFileFormat,
          now: now,
          onSkippedEvent: onSkippedEvent,
        );
      } catch (e, stackTrace) {
        _log.error(
          'Failed to import the ${entry['diveComputerModel'] ?? 'unnamed'} '
          'computer of dive $diveId; the dive keeps its other computers',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _writeOne(
    Map<String, dynamic> entry, {
    required String diveId,
    required DateTime? entryTime,
    required List<DiveTank> tanks,
    required String? computerId,
    required String? sourceFileName,
    required String sourceFileFormat,
    required DateTime now,
    void Function(String message)? onSkippedEvent,
  }) async {
    final offset = entry['timeOffsetSeconds'] as int? ?? 0;
    final duration = entry['duration'] as Duration?;
    final start = entryTime?.add(Duration(seconds: offset));
    final profileData =
        (entry['profile'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final eventMaps =
        (entry['events'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final sourceId = _uuid.v4();

    await _dives.saveAdditionalComputerReading(
      reading: DiveDataSourcesCompanion(
        id: Value(sourceId),
        diveId: Value(diveId),
        isPrimary: const Value(false),
        computerId: Value(computerId),
        computerModel: Value(entry['diveComputerModel'] as String?),
        computerSerial: Value(entry['diveComputerSerial'] as String?),
        sourceFileName: Value(sourceFileName),
        sourceFileFormat: Value(sourceFileFormat),
        maxDepth: Value(asDoubleOrNull(entry['maxDepth'])),
        avgDepth: Value(asDoubleOrNull(entry['avgDepth'])),
        duration: Value(duration?.inSeconds),
        waterTemp: Value(asDoubleOrNull(entry['waterTemp'])),
        entryTime: Value(start),
        exitTime: Value(
          start != null && duration != null ? start.add(duration) : null,
        ),
        timeOffsetSeconds: Value(offset),
        decoAlgorithm: Value(entry['decoAlgorithm'] as String?),
        gradientFactorLow: Value(entry['gradientFactorLow'] as int?),
        gradientFactorHigh: Value(entry['gradientFactorHigh'] as int?),
        importedAt: Value(now),
        createdAt: Value(now),
      ),
      profile: [
        for (final p in profileData)
          profilePointFromImport(p, offsetSeconds: offset),
      ],
      events: [
        for (final event in profileEventsFromParsed(
          diveId: diveId,
          eventMaps: eventMaps,
          now: now,
          onSkipped: onSkippedEvent,
        ))
          event.copyWith(
            timestamp: event.timestamp + offset,
            computerId: computerId,
          ),
      ],
    );

    final pressures = tankPressuresFromImport(
      profileData,
      tanks,
      offsetSeconds: offset,
    );
    if (pressures.isNotEmpty) {
      await _tankPressures.insertTankPressures(
        diveId,
        pressures,
        sourceId: sourceId,
        computerId: computerId,
      );
    }
  }
}
