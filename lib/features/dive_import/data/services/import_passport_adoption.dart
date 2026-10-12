import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';

const _log = LoggerService('importPassportAdoption');

/// Restores the passport ids a full UDDF backup carries on its items
/// (issue #2651), for every item the import created or matched to an
/// existing row ([equipmentIdMapping], keyed by the file's item id).
///
/// Runs after equipment and before fills, so a restored cylinder holds its
/// id by the time CsvFillImporter links fills by it. Each id goes only into
/// an empty slot ([CylinderPassportRepository.adoptImportedPassportId]); a
/// refusal or a failure is logged and the import carries on. Returns how
/// many ids were written.
Future<int> adoptImportedPassportIds(
  List<Map<String, dynamic>> items,
  Map<String, String> equipmentIdMapping,
  CylinderPassportRepository repository, {
  required String diverId,
}) async {
  var count = 0;
  for (final item in items) {
    final passportId = (item['passportId'] as String?)?.trim();
    final uddfId = item['uddfId'] as String?;
    if (passportId == null || passportId.isEmpty || uddfId == null) continue;
    final equipmentId = equipmentIdMapping[uddfId];
    if (equipmentId == null) continue;
    try {
      final adopted = await repository.adoptImportedPassportId(
        equipmentId: equipmentId,
        passportId: passportId,
        diverId: diverId,
      );
      if (adopted) {
        count++;
      } else {
        _log.info(
          'Kept the tag already on $equipmentId or on another item; the '
          "file's passport id was not adopted",
        );
      }
    } catch (e) {
      _log.warning('Could not adopt a passport id onto $equipmentId: $e');
    }
  }
  return count;
}
