import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';

/// Stores the fill an own cylinder's tag carries (spec section 11), once:
/// the fill id is the row id, so a second tap, the diver's own write read
/// back, or a copy already synced from another device adds nothing, and a
/// fill the diver deleted stays deleted.
class TagFillImporter {
  TagFillImporter({CylinderFillRepository? fills})
    : _fills = fills ?? CylinderFillRepository();

  final CylinderFillRepository _fills;

  /// The stored fill, or null when the tag had none to add.
  Future<CylinderFill?> importIfNew({
    required CylinderPassportPayload tag,
    required String equipmentId,
    required String? diverId,
  }) async {
    final f = tag.fill;
    if (f == null) return null;
    if (await _fills.getById(f.id) != null) return null;
    if (await _fills.wasDeleted(f.id)) return null;
    final now = DateTime.now();
    return _fills.create(
      CylinderFill(
        id: f.id,
        diverId: diverId,
        passportId: tag.passportId,
        equipmentId: equipmentId,
        filledAt: f.filledAt,
        o2Percent: f.o2Percent,
        hePercent: f.hePercent,
        pressureBar: f.pressureBar,
        temperatureC: f.temperatureC,
        analyzer: f.analyzer,
        stationName: f.filledBy,
        source: FillSource.nfc,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
