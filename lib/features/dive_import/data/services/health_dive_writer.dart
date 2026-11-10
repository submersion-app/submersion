import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart'
    show ImportTripResolver;
import 'package:submersion/features/dive_import/data/services/apple_watch_computer.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    show DiveComputerRepository;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/data/services/equipment_set_for_computer_linker.dart';
import 'package:submersion/features/pre_dive/data/services/checklist_dive_linker.dart';

/// Saves one Apple Health workout as a new dive, the way every Health
/// import does (issue #637): numbered, in the trip that covers it,
/// attributed to the diver's Apple Watch computer, with the diver's default
/// gear, checklists and altitude. The import wizard and the automatic
/// import both write through it, so the two paths cannot drift apart.
class HealthDiveWriter {
  HealthDiveWriter({
    required DiveRepository dives,
    DiveComputerRepository? computers,
    ImportedDiveConverter converter = const ImportedDiveConverter(),
    ChecklistDiveLinker? checklistLinker,
    ImportTripResolver? tripForImports,
    SyncRepository? sync,
  }) : _dives = dives,
       _sync = sync ?? SyncRepository(),
       _computers = computers ?? DiveComputerRepository(),
       _converter = converter,
       _checklistLinker = checklistLinker ?? ChecklistDiveLinker(),
       _tripForImports = tripForImports;

  static final _log = LoggerService.forClass(HealthDiveWriter);

  final DiveRepository _dives;
  final DiveComputerRepository _computers;
  final ImportedDiveConverter _converter;
  final ChecklistDiveLinker _checklistLinker;
  final ImportTripResolver? _tripForImports;
  final SyncRepository _sync;

  /// One per writer: its lookup cache collapses a batch of dives at the same
  /// place into a single elevation request.
  final _altitudeEnricher = DiveAltitudeEnricher();
  DiveComputer? _watch;

  /// Saves [workout] for [diverId] and returns the saved dive. [diveNumber]
  /// wins over the next free number when given. A caller writing inside a
  /// transaction passes [enrichAltitude] false and calls [enrichAltitude]
  /// once it commits: the altitude lookup may go to the network, and a
  /// transaction must not hold the database while it waits.
  Future<Dive> importAsNew(
    ImportedDive workout, {
    required String diverId,
    int? diveNumber,
    bool enrichAltitude = true,
  }) async {
    final number =
        diveNumber ?? await _dives.getNextDiveNumber(diverId: diverId);
    final converted = _converter.convert(
      workout,
      diverId: diverId,
      diveNumber: number,
    );
    final tripId = await _tripFor(workout.startTime, diverId);
    final dive = tripId == null
        ? converted
        : converted.copyWith(tripId: tripId);
    await _dives.createDive(dive);
    // The dive takes the workout's id on every device, so a workout whose
    // dive was deleted (or merged into another) can come back. Its old
    // tombstone goes, as for any record revived under the same id, or sync
    // would delete the dive again here and on every peer. With no database
    // (a mocked repository) there is no tombstone, as for the linkers below.
    if (DatabaseService.instance.databaseOrNull != null) {
      await _sync.removeDeletion(entityType: 'dives', recordId: dive.id);
    }
    // The diver's Apple Watch computer, before the gear linkers below, which
    // follow the dive's computer. Best effort, as the trip lookup is: a
    // failed lookup must not lose the dive.
    try {
      _watch ??= await appleWatchComputerFor(_computers, diverId);
      await _computers.attributeDiveToComputer(
        diveId: dive.id,
        computerId: _watch!.id,
      );
    } catch (e, stackTrace) {
      _log.warning(
        'Could not attribute ${dive.id} to the Apple Watch computer',
        error: e,
        stackTrace: stackTrace,
      );
    }
    await DiveEquipmentDefaulter().applyForImportedDive(dive);
    await _checklistLinker.applyForImportedDive(dive);
    if (enrichAltitude) await _altitudeEnricher.applyForImportedDive(dive);
    // After the defaulter, never before: the defaulter bails on a dive that
    // already has equipment, so linking first would suppress the diver's
    // default and geofenced sets.
    await DiveComputerGearLinker().linkComputerGearForDive(diveId: dive.id);
    // Every equipment set that lists this computer as a member (#1020).
    await EquipmentSetForComputerLinker().linkComputerSetsForDive(
      diveId: dive.id,
    );
    return dive;
  }

  /// The altitude [importAsNew] left out for the dive [diveId], read from
  /// what the dive holds now. Best effort: a dive that is gone gets nothing.
  Future<void> enrichAltitudeFor(String diveId) async {
    final dive = await _dives.getDiveById(diveId);
    if (dive != null) await _altitudeEnricher.applyForImportedDive(dive);
  }

  Future<String?> _tripFor(DateTime start, String diverId) async {
    final resolver = _tripForImports;
    if (resolver == null) return null;
    try {
      return await resolver(start, diverId);
    } catch (e, stackTrace) {
      _log.warning(
        'Trips unavailable, importing the dive without one',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
