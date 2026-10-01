import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_import/data/services/additional_computer_writer.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';

/// Adds to a stored dive the further computers a fresh parse of its file
/// carries and the dive does not have yet (issue #2672).
///
/// This is the upgrade path for a dive imported before the importer kept
/// every computer: it holds only its first one, and neither a resync nor a
/// consolidation would otherwise bring the rest in. Running it again adds
/// nothing, because a computer the dive already records is never written
/// twice.
class MissingComputerAttacher {
  MissingComputerAttacher({
    required AppDatabase db,
    DiveRepository? diveRepository,
    TankPressureRepository? tankPressureRepository,
    DiveComputerRepository? diveComputerRepository,
  }) : _db = db,
       _writer = AdditionalComputerWriter(
         diveRepository: diveRepository ?? DiveRepository(),
         tankPressureRepository:
             tankPressureRepository ?? TankPressureRepository(database: db),
       ),
       _computers = diveComputerRepository ?? DiveComputerRepository();

  final AppDatabase _db;
  final AdditionalComputerWriter _writer;
  final DiveComputerRepository _computers;
  static const _log = LoggerService('MissingComputerAttacher');

  /// Writes onto [diveId] each further computer of [diveData] (a parsed dive
  /// map) that the dive's sources do not already record, returning how many
  /// were added.
  ///
  /// The parse may place the dive at a different start than the stored dive
  /// (another file of the same dive); each added computer is moved by that
  /// difference so its samples land where they happened on this dive.
  Future<int> attach({
    required String diveId,
    required Map<String, dynamic> diveData,
    required String? sourceFileName,
    required String sourceFileFormat,
    DateTime? now,
  }) async {
    if (AdditionalComputerWriter.entriesOf(diveData).isEmpty) return 0;

    final dive = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return 0;

    final sources = await (_db.select(
      _db.diveDataSources,
    )..where((t) => t.diveId.equals(diveId))).get();
    final missing = missingComputers(diveData, [
      for (final s in sources)
        UddfEntityImporter.computerKeyFor(s.computerModel, s.computerSerial),
    ]);
    if (missing.isEmpty) return 0;

    final tanks =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
            .get();

    final idByKey = <String, String>{};
    for (final entry in missing) {
      final key = _keyOf(entry);
      if (key == null || idByKey.containsKey(key)) continue;
      try {
        final computer = await _computers.findOrRegisterImportedComputer(
          model: entry['diveComputerModel'] as String,
          serialNumber: entry['diveComputerSerial'] as String?,
          firmwareVersion: entry['diveComputerFirmware'] as String?,
          diverId: dive.diverId,
        );
        if (computer != null) idByKey[key] = computer.id;
      } catch (e, stackTrace) {
        // Attribution is cosmetic next to the samples: the computer is still
        // added, just not linked to a registered device.
        _log.error(
          'Failed to register imported dive computer for "$key"',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    final diveStart = DateTime.fromMillisecondsSinceEpoch(
      dive.diveDateTime,
      isUtc: true,
    );
    final parsedStart = diveData['dateTime'] as DateTime?;
    final shift = parsedStart == null
        ? 0
        : parsedStart.difference(diveStart).inSeconds;

    return _writer.write(
      computers: [
        for (final entry in missing)
          {
            ...entry,
            'timeOffsetSeconds':
                (entry['timeOffsetSeconds'] as int? ?? 0) + shift,
          },
      ],
      diveId: diveId,
      entryTime: dive.entryTime == null
          ? diveStart
          : DateTime.fromMillisecondsSinceEpoch(dive.entryTime!, isUtc: true),
      tankIds: [for (final tank in tanks) tank.id],
      usedComputerIds: [for (final s in sources) ?s.computerId],
      computerIdFor: (entry) => idByKey[_keyOf(entry)],
      sourceFileName: sourceFileName,
      sourceFileFormat: sourceFileFormat,
      now: now ?? DateTime.now(),
      onSkippedEvent: _log.warning,
    );
  }

  /// The re-import of a dive imported before the importer kept every
  /// computer, matched to that older copy and flagged Consolidate.
  ///
  /// When [targetDiveId] already records [diveData]'s first computer and the
  /// parse carries further ones, adds those the dive lacks and returns true:
  /// the incoming dive has nothing else to contribute, and a fold would be
  /// refused for sharing that computer. Returns false, writing nothing, for
  /// any other pairing, which a normal consolidation handles.
  Future<bool> attachToMatch({
    required String targetDiveId,
    required Map<String, dynamic> diveData,
    required String? sourceFileName,
    required String sourceFileFormat,
  }) async {
    if (AdditionalComputerWriter.entriesOf(diveData).isEmpty) return false;
    final firstKey = UddfEntityImporter.computerKeyFor(
      diveData['diveComputerModel'] as String?,
      diveData['diveComputerSerial'] as String?,
    );
    if (firstKey == null) return false;
    final sources = await (_db.select(
      _db.diveDataSources,
    )..where((t) => t.diveId.equals(targetDiveId))).get();
    final recordsFirst = sources.any(
      (s) =>
          UddfEntityImporter.computerKeyFor(
            s.computerModel,
            s.computerSerial,
          ) ==
          firstKey,
    );
    if (!recordsFirst) return false;
    await attach(
      diveId: targetDiveId,
      diveData: diveData,
      sourceFileName: sourceFileName,
      sourceFileFormat: sourceFileFormat,
    );
    return true;
  }

  /// The further computers of [diveData] that [presentKeys] (the identity of
  /// each of the stored dive's sources) do not account for.
  ///
  /// Identities are counted, not merely compared: two computers of one model
  /// with no serial share one, and a dive holding one of them still lacks
  /// the other. The parse's first computer is the one the dive's primary
  /// source records, so it claims its identity before the others.
  static List<Map<String, dynamic>> missingComputers(
    Map<String, dynamic> diveData,
    Iterable<String?> presentKeys,
  ) {
    final unclaimed = <String?, int>{};
    for (final key in presentKeys) {
      unclaimed[key] = (unclaimed[key] ?? 0) + 1;
    }
    bool claim(String? key) {
      final count = unclaimed[key] ?? 0;
      if (count == 0) return false;
      unclaimed[key] = count - 1;
      return true;
    }

    claim(
      UddfEntityImporter.computerKeyFor(
        diveData['diveComputerModel'] as String?,
        diveData['diveComputerSerial'] as String?,
      ),
    );
    return [
      for (final entry in AdditionalComputerWriter.entriesOf(diveData))
        if (!claim(_keyOf(entry))) entry,
    ];
  }

  static String? _keyOf(Map<String, dynamic> entry) =>
      UddfEntityImporter.computerKeyFor(
        entry['diveComputerModel'] as String?,
        entry['diveComputerSerial'] as String?,
      );
}
