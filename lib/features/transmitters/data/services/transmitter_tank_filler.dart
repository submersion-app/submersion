import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';
import 'package:submersion/features/transmitters/data/services/bailout_mix_fixer.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Outcome of filling registry entries onto dive tanks.
/// [mixesKept]: dives where a bailout entry changed the role but found no
/// bailout mix to give the tank, so it kept the one it had (issue #3307).
typedef ApplyToExistingResult = ({
  int tanksUpdated,
  int divesUpdated,
  int mixesKept,
});

const ApplyToExistingResult noTanksFilled = (
  tanksUpdated: 0,
  divesUpdated: 0,
  mixesKept: 0,
);

/// Fills a transmitter entry's setup onto the dive tanks that carry its key:
/// the one rule behind "Apply to existing dives" and the fill that file
/// imports and dive merges run on their own dives (issue #4347).
///
/// Fill-only: empty size, working pressure, material, preset, gear link and
/// name are filled; the role is replaced while it is still the uninformed
/// backGas default, and always while it is the computer's guess from the
/// transmitter's name (issue #2595), which also drops that source: the
/// entry is the diver's own configuration. A role the diver set is never
/// replaced. One transaction; a failure leaves no half-applied dive.
class TransmitterTankFiller {
  TransmitterTankFiller({SyncRepository? syncRepository})
    : _syncRepository = syncRepository ?? SyncRepository();

  final SyncRepository _syncRepository;

  AppDatabase get _db => DatabaseService.instance.database;

  Future<ApplyToExistingResult> fill(
    List<(DiveTank, Transmitter)> pairs,
  ) async {
    if (pairs.isEmpty) return noTanksFilled;
    final now = DateTime.now().millisecondsSinceEpoch;
    final touchedDives = <String>{};
    var tanks = 0;
    final mixesKeptDives = <String>{};
    final mixFixer = BailoutMixFixer();
    await _db.transaction(() async {
      for (final (row, t) in pairs) {
        final nameDerived =
            TankRoleSource.fromName(row.roleSource) ==
            TankRoleSource.transmitterName;
        // An open-circuit entry (bailout, deco, stage) also replaces the
        // importer's 100% O2 default with that gas's own mix, before the role
        // write below (#3307).
        if (nameDerived && !isLoopTankRole(t.role.name)) {
          if (!await mixFixer.fix(row)) mixesKeptDives.add(row.diveId);
        }
        final companion = _companionFor(row, t, nameDerived: nameDerived);
        // Every field absent means nothing to write for this row.
        if (companion == const DiveTanksCompanion()) continue;
        await (_db.update(
          _db.diveTanks,
        )..where((d) => d.id.equals(row.id))).write(companion);
        await _syncRepository.markRecordPending(
          entityType: 'diveTanks',
          recordId: row.id,
          localUpdatedAt: now,
        );
        touchedDives.add(row.diveId);
        tanks++;
      }
    });
    if (tanks > 0) {
      SyncEventBus.notifyLocalChange();
      // The scan create/update queued ran on the roles before this fill,
      // so a finding about a role it just fixed would stay open (#3307).
      scheduleQualityScan(touchedDives);
    }
    return (
      tanksUpdated: tanks,
      divesUpdated: touchedDives.length,
      mixesKept: mixesKeptDives.length,
    );
  }

  DiveTanksCompanion _companionFor(
    DiveTank row,
    Transmitter t, {
    required bool nameDerived,
  }) {
    final hasVolume = row.volume != null && row.volume! > 0;
    return DiveTanksCompanion(
      volume: !hasVolume && t.volumeL != null
          ? Value(t.volumeL)
          : const Value.absent(),
      workingPressure:
          row.workingPressure == null && t.workingPressureBar != null
          ? Value(t.workingPressureBar)
          : const Value.absent(),
      tankMaterial: row.tankMaterial == null && t.material != null
          ? Value(t.material!.name)
          : const Value.absent(),
      presetName: row.presetName == null && t.presetName != null
          ? Value(t.presetName)
          : const Value.absent(),
      equipmentId: row.equipmentId == null && t.equipmentId != null
          ? Value(t.equipmentId)
          : const Value.absent(),
      tankName:
          (row.tankName == null || row.tankName!.isEmpty) && t.label.isNotEmpty
          ? Value(t.label)
          : const Value.absent(),
      tankRole:
          nameDerived ||
              (row.tankRole == TankRole.backGas.name &&
                  t.role != TankRole.backGas)
          ? Value(t.role.name)
          : const Value.absent(),
      roleSource: nameDerived ? const Value(null) : const Value.absent(),
    );
  }
}
