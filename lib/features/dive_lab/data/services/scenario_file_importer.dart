import 'package:collection/collection.dart';

import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_codec.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

class ImportedScenario {
  const ImportedScenario({
    required this.diveId,
    required this.scenarioId,
    required this.diveCreated,
    required this.alreadyPresent,
  });
  final String diveId;
  final String scenarioId;

  /// The dive did not exist locally and was created from the snapshot.
  final bool diveCreated;

  /// An identical scenario already existed on the dive; nothing was written.
  final bool alreadyPresent;
}

/// Attaches a shared scenario to the matching local dive, or creates the
/// dive from the file's snapshot first.
class ScenarioFileImporter {
  ScenarioFileImporter({
    DiveRepository? diveRepository,
    TankPressureRepository? tankPressureRepository,
    DiveScenarioRepository? scenarioRepository,
  }) : _dives = diveRepository ?? DiveRepository(),
       _pressures = tankPressureRepository ?? TankPressureRepository(),
       _scenarios = scenarioRepository ?? DiveScenarioRepository();

  final DiveRepository _dives;
  final TankPressureRepository _pressures;
  final DiveScenarioRepository _scenarios;

  /// [diveNotes] is written on a dive created from the snapshot (the caller
  /// localises it).
  Future<ImportedScenario> import(
    SublabFile file, {
    required String diveNotes,
  }) async {
    final snapshot = file.snapshot;
    var diveId = snapshot.diveId;
    var created = false;
    final existing = await _dives.getDiveById(diveId);
    if (existing == null) {
      final dive = await _dives.createDive(
        Dive(
          id: diveId,
          diveNumber: null,
          dateTime: snapshot.diveDateTime,
          diveMode: snapshot.diveMode,
          gradientFactorLow: snapshot.gfLow,
          gradientFactorHigh: snapshot.gfHigh,
          altitude: snapshot.altitudeMeters,
          waterType: snapshot.waterType,
          surfacePressure: snapshot.surfacePressureBar,
          setpointHigh: snapshot.setpointHigh,
          setpointLow: snapshot.setpointLow,
          tanks: snapshot.tanks,
          profile: snapshot.profile,
          notes: diveNotes,
        ),
      );
      diveId = dive.id;
      created = true;
      for (final s in snapshot.gasSwitches) {
        await _dives.createGasSwitch(
          GasSwitch(
            id: '',
            diveId: diveId,
            timestamp: s.timestamp,
            tankId: s.tankId,
            createdAt: DateTime.now(),
          ),
        );
      }
      if (snapshot.tankPressures.isNotEmpty) {
        await _pressures.insertTankPressures(diveId, {
          for (final e in snapshot.tankPressures.entries)
            e.key: [
              for (final p in e.value)
                (timestamp: p.timestamp, pressure: p.pressureBar),
            ],
        });
      }
    }

    final incoming = file.scenario;
    final local = await _scenarios.getScenariosForDive(diveId);
    for (final s in local) {
      if (_sameScenario(s, incoming)) {
        return ImportedScenario(
          diveId: diveId,
          scenarioId: s.id,
          diveCreated: created,
          alreadyPresent: true,
        );
      }
    }
    final saved = await _scenarios.saveScenario(
      incoming.copyWith(id: '', diveId: diveId),
    );
    return ImportedScenario(
      diveId: diveId,
      scenarioId: saved.id,
      diveCreated: created,
      alreadyPresent: false,
    );
  }

  bool _sameScenario(DiveScenario a, DiveScenario b) =>
      a.name == b.name &&
      a.branchSeconds == b.branchSeconds &&
      a.mode == b.mode &&
      const ListEquality<Object>().equals(a.interventions, b.interventions);
}
