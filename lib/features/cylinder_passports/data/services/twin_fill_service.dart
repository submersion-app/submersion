import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Whether the fill history offers to edit [fill]: a fill the diver typed
/// in. A signed or imported fill's values are the record, and a trip fill's
/// copy ([tripCopyIds]) is rewritten whenever its trip fill is saved.
bool isEditableFill(CylinderFill fill, {required Set<String> tripCopyIds}) =>
    fill.source == FillSource.manual &&
    !fill.isSigned &&
    !tripCopyIds.contains(fill.id);

/// The two fills of one twin set fill (issue #4242): one per cylinder, the
/// same gas, pressure, time, station and notes, tied by a shared
/// `filledTogetherId` so an edit or delete of one can follow on the other.
///
/// Each row goes through [CylinderFillRepository]'s own writes, so each is
/// staged for sync and tombstoned like any other fill.
class TwinFillService {
  TwinFillService({
    CylinderFillRepository? fills,
    CylinderPassportRepository? passports,
  }) : _fills = fills ?? CylinderFillRepository(),
       _passports = passports ?? CylinderPassportRepository();

  final CylinderFillRepository _fills;
  final CylinderPassportRepository _passports;
  final _uuid = const Uuid();

  /// Saves [fill] and the same fill on [partnerEquipmentId], in one
  /// transaction. A partner that never had a passport id gets one here, the
  /// way opening its passport page would mint it.
  Future<({CylinderFill fill, CylinderFill partnerFill})> recordTwinFill(
    CylinderFill fill, {
    required String partnerEquipmentId,
  }) => DatabaseService.instance.database.transaction(() async {
    final partnerPassportId = await _passports.ensurePassportId(
      partnerEquipmentId,
      diverId: fill.diverId,
    );
    final group = _uuid.v4();
    final saved = await _fills.create(fill.copyWith(filledTogetherId: group));
    final partner = await _fills.create(
      fill.copyWith(
        id: '',
        passportId: partnerPassportId,
        equipmentId: partnerEquipmentId,
        filledTogetherId: group,
      ),
    );
    return (fill: saved, partnerFill: partner);
  });

  /// Saves [edited]; with [toTied], copies what the diver can edit onto the
  /// other fill of its twin set fill when that still exists.
  Future<void> applyEdit(CylinderFill edited, {required bool toTied}) =>
      DatabaseService.instance.database.transaction(() async {
        await _fills.update(edited);
        if (!toTied) return;
        final tied = await _fills.tiedFillOf(edited);
        if (tied == null) return;
        await _fills.update(
          tied.copyWith(
            filledAt: edited.filledAt,
            o2Percent: edited.o2Percent,
            hePercent: edited.hePercent,
            pressureBar: edited.pressureBar,
            clearPressureBar: edited.pressureBar == null,
            temperatureC: edited.temperatureC,
            clearTemperatureC: edited.temperatureC == null,
            analyzer: edited.analyzer,
            clearAnalyzer: edited.analyzer == null,
            stationName: edited.stationName,
            clearStationName: edited.stationName == null,
            notes: edited.notes,
          ),
        );
      });

  /// Deletes [fill]; with [tiedToo], the other fill of its twin set fill as
  /// well.
  Future<void> delete(CylinderFill fill, {required bool tiedToo}) =>
      DatabaseService.instance.database.transaction(() async {
        final tied = tiedToo ? await _fills.tiedFillOf(fill) : null;
        await _fills.delete(fill.id);
        if (tied != null) await _fills.delete(tied.id);
      });
}
