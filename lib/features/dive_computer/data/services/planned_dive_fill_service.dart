import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// What one fill wrote, enough to undo it.
class PlannedDiveFillOutcome {
  final String diveId;
  final DiveMergeSnapshot snapshot;
  final int? assignedDiveNumber;

  const PlannedDiveFillOutcome({
    required this.diveId,
    required this.snapshot,
    required this.assignedDiveNumber,
  });
}

/// Fills a planned dive from a dive computer download (issue #2002): the
/// computer supplies the measured facts, the plan keeps the human ones.
/// The classification lives in `planned_dive_fill_fields.dart`.
class PlannedDiveFillService {
  final DiveRepository _dives;
  final DiveComputerRepository _computers;
  final DiveImportService _import;
  final ProfileSeriesRepository _series;
  final DiveConsolidationService _consolidation;
  final _uuid = const Uuid();

  PlannedDiveFillService({
    DiveRepository? dives,
    DiveComputerRepository? computers,
    DiveImportService? importService,
    ProfileSeriesRepository? series,
    DiveConsolidationService? consolidation,
  }) : _dives = dives ?? DiveRepository(),
       _computers = computers ?? DiveComputerRepository(),
       _series = series ?? ProfileSeriesRepository(),
       _import =
           importService ??
           DiveImportService(
             repository: computers ?? DiveComputerRepository(),
             diveRepository: dives ?? DiveRepository(),
           ),
       _consolidation =
           consolidation ?? DiveConsolidationService(dives ?? DiveRepository());

  Future<PlannedDiveFillOutcome> fill({
    required String plannedDiveId,
    required DownloadedDive dive,
    required String computerId,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    final db = DatabaseService.instance.database;
    return db.transaction(() async {
      final planned = await _dives.getDiveById(plannedDiveId);
      if (planned == null || !planned.isPlanned) {
        throw StateError('Dive $plannedDiveId is not a planned dive');
      }
      final snapshot = await DiveMergeSnapshot.capture(db, [
        plannedDiveId,
      ], plannedDiveId);

      // 1. Drop the sketched or planner-generated curve; the download is
      //    the record of what happened.
      await _series.deleteForDive(plannedDiveId);

      // 2. Measured facts onto the row, tanks reconciled by serial then mix.
      final measured = planned.copyWith(
        entryTime: dive.startTime,
        exitTime: dive.startTime.add(Duration(seconds: dive.durationSeconds)),
        bottomTime: Duration(seconds: dive.durationSeconds),
        runtime: Duration(seconds: dive.durationSeconds),
        maxDepth: dive.maxDepth,
        avgDepth: dive.avgDepth ?? planned.avgDepth,
        waterTemp: dive.minTemperature ?? planned.waterTemp,
        gradientFactorLow: dive.gfLow ?? planned.gradientFactorLow,
        gradientFactorHigh: dive.gfHigh ?? planned.gradientFactorHigh,
        decoAlgorithm: dive.decoAlgorithm ?? planned.decoAlgorithm,
        decoConservatism: dive.decoConservatism ?? planned.decoConservatism,
        diveMode: dive.diveMode,
        tanks: _mergeTanks(planned.tanks, dive.tanks),
        profile: const [],
      );
      await _dives.updateDive(measured);

      // 3. Attach the download to this dive by id: profile, pressures,
      //    switches, events, the data source with its fingerprint, and the
      //    computer's gear links. The row keeps isPlanned until step 4 so
      //    the fuzzy matcher, which skips planned dives, cannot pair another
      //    download with it in between.
      await _import.attachToPlannedDive(
        dive,
        plannedDiveId,
        computerId,
        descriptorVendor: descriptorVendor,
        descriptorProduct: descriptorProduct,
        descriptorModel: descriptorModel,
        libdivecomputerVersion: libdivecomputerVersion,
      );
      await _computers.attributeDiveToComputer(
        diveId: plannedDiveId,
        computerId: computerId,
      );

      // 4. Promote: clears the flag and takes the next dive number. The date
      //    stays as planned; the computer's start already went to entryTime.
      await _dives.convertPlanToActualDive(plannedDiveId);
      final promoted = await _dives.getDiveById(plannedDiveId);

      return PlannedDiveFillOutcome(
        diveId: plannedDiveId,
        snapshot: snapshot,
        assignedDiveNumber: promoted?.diveNumber,
      );
    });
  }

  /// Restores the planned dive from the snapshot: row, tanks, series,
  /// sources, events, switches and pressure series. The consolidation undo
  /// already does exactly this for a surviving target dive.
  Future<void> undo(PlannedDiveFillOutcome outcome) =>
      _consolidation.undo(outcome.snapshot);

  /// Planned tanks matched by transmitter serial first, then by gas mix
  /// (0.5 percent), receive the downloaded pressures; unmatched downloaded
  /// tanks are appended with fresh ids, since updateDive rejects blank ones.
  List<DiveTank> _mergeTanks(
    List<DiveTank> planned,
    List<DownloadedTank> downloaded,
  ) {
    final remaining = [...downloaded];
    final merged = <DiveTank>[];
    for (final tank in planned) {
      DownloadedTank? hit;
      final wantedSerial = normalizeTransmitterSerial(tank.transmitterSerial);
      if (wantedSerial != null) {
        for (final d in remaining) {
          if (normalizeTransmitterSerial(d.transmitterSerial) == wantedSerial) {
            hit = d;
            break;
          }
        }
      }
      hit ??= remaining
          .where(
            (d) =>
                (d.o2Percent - tank.gasMix.o2).abs() <= 0.5 &&
                (d.hePercent - tank.gasMix.he).abs() <= 0.5,
          )
          .firstOrNull;
      if (hit == null) {
        merged.add(tank);
        continue;
      }
      remaining.remove(hit);
      merged.add(
        tank.copyWith(
          startPressure: hit.startPressure ?? tank.startPressure,
          endPressure: hit.endPressure ?? tank.endPressure,
          transmitterSerial: hit.transmitterSerial ?? tank.transmitterSerial,
        ),
      );
    }
    for (final d in remaining) {
      merged.add(
        DiveTank(
          id: _uuid.v4(),
          gasMix: GasMix(o2: d.o2Percent, he: d.hePercent),
          volume: d.volumeLiters,
          startPressure: d.startPressure,
          endPressure: d.endPressure,
          transmitterSerial: d.transmitterSerial,
          order: merged.length,
        ),
      );
    }
    return merged;
  }
}
