import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

const _log = LoggerService('csvFillImporter');

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
    final fills = [
      for (final (i, item) in items.indexed)
        if (selected.contains(i)) ?fromPayload(item),
    ];
    // One query tells which ids are already here or were deleted here; the
    // ids stored below join it, so a repeated row is skipped too.
    final known = {
      ...await _fills.knownIds([for (final fill in fills) fill.id]),
    };
    // A file usually holds many fills of the same few cylinders, so each
    // passport id is looked up once per import.
    final linked = <String, String?>{};
    var count = 0;
    for (final fill in fills) {
      if (!known.add(fill.id)) continue;
      try {
        await _store(fill, diverId, linked);
        count++;
      } catch (e) {
        // One bad row must not abort the import; it is logged so a failed
        // row is told apart from one skipped as already here.
        _log.warning('Could not import fill ${fill.id}: $e');
      }
    }
    return count;
  }

  /// Stores [fill] for [diverId], linked to the cylinder holding its
  /// passport id. [linked] caches the cylinder found for each passport id.
  Future<CylinderFill> _store(
    CylinderFill fill,
    String diverId,
    Map<String, String?> linked,
  ) async {
    if (!linked.containsKey(fill.passportId)) {
      linked[fill.passportId] = await _passports.findEquipmentIdByPassportId(
        fill.passportId,
        diverId: diverId,
      );
    }
    final now = DateTime.now();
    return _fills.create(
      fill.copyWith(
        diverId: diverId,
        equipmentId: linked[fill.passportId],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// A fill from a SubmersionFillsCsvParser row, unlinked and without a
  /// diver, or null when the row lacks an id, a passport id, a time or an
  /// O2 reading, or holds a gas mix the Log fill sheet would refuse.
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
    final he = (data['hePercent'] as num?)?.toDouble() ?? 0;
    if (!CylinderFill.isPossibleMix(o2.toDouble(), he)) return null;
    final now = DateTime.now();
    return CylinderFill(
      id: id,
      passportId: passportId,
      filledAt: filledAt,
      o2Percent: o2.toDouble(),
      hePercent: he,
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
