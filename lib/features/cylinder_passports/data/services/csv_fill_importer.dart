import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Stores the rows of a Submersion fills CSV (spec section 10.2, PR 5).
///
/// Each row keeps its fill id, so a file imports once: a fill already here,
/// or one the diver deleted (the deletion log), adds nothing, the rule
/// TagFillImporter applies to a fill read from a tag. A fill is linked to
/// the importing diver's cylinder that holds its passport id when there is
/// one; otherwise it stays under the passport id alone and is relinked when
/// a cylinder gets that id (Link an existing tag, Add to my gear).
class CsvFillImporter {
  CsvFillImporter({
    CylinderFillRepository? fills,
    CylinderPassportRepository? passports,
  }) : _fills = fills ?? CylinderFillRepository(),
       _passports = passports ?? CylinderPassportRepository();

  final CylinderFillRepository _fills;
  final CylinderPassportRepository _passports;

  /// Stores the rows of [items] at the indices in [selected] for [diverId]
  /// and returns how many were created. A row that cannot be read or
  /// stored is skipped; one bad row never aborts the import.
  Future<int> importRows(
    List<Map<String, dynamic>> items, {
    required Set<int> selected,
    required String diverId,
  }) async {
    var count = 0;
    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final fill = fromPayload(items[i]);
      if (fill == null) continue;
      try {
        if (await importIfNew(fill, diverId: diverId) != null) count++;
      } catch (_) {
        // One bad row must not abort the import.
      }
    }
    return count;
  }

  /// The stored fill, or null when [fill] is already here or was deleted.
  Future<CylinderFill?> importIfNew(
    CylinderFill fill, {
    required String diverId,
  }) async {
    if (await _fills.getById(fill.id) != null) return null;
    if (await _fills.wasDeleted(fill.id)) return null;
    final equipmentId = await _passports.findEquipmentIdByPassportId(
      fill.passportId,
      diverId: diverId,
    );
    final now = DateTime.now();
    return _fills.create(
      fill.copyWith(
        diverId: diverId,
        equipmentId: equipmentId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// A fill from a SubmersionFillsCsvParser row, unlinked and without a
  /// diver, or null when the row lacks an id, a passport id, a time or an
  /// O2 reading.
  static CylinderFill? fromPayload(Map<String, dynamic> data) {
    final id = data['id'];
    final passportId = data['passportId'];
    final filledAt = data['filledAt'];
    final o2 = data['o2Percent'];
    if (id is! String ||
        id.isEmpty ||
        passportId is! String ||
        passportId.isEmpty ||
        filledAt is! DateTime ||
        o2 is! num) {
      return null;
    }
    final now = DateTime.now();
    return CylinderFill(
      id: id,
      passportId: passportId,
      filledAt: filledAt,
      o2Percent: o2.toDouble(),
      hePercent: (data['hePercent'] as num?)?.toDouble() ?? 0,
      pressureBar: (data['pressureBar'] as num?)?.toDouble(),
      temperatureC: (data['temperatureC'] as num?)?.toDouble(),
      analyzer: data['analyzer'] as String?,
      stationName: data['stationName'] as String?,
      source: FillSource.fromName(data['source'] as String?),
      notes: data['notes'] as String? ?? '',
      createdAt: now,
      updatedAt: now,
    );
  }
}
