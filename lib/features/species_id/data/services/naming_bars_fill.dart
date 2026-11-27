import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';

final _log = LoggerService.forClass(NamingBars);

/// Gives the runs this device made with the installed pack, before runs
/// kept their pack's naming bars, those bars (issue #4876), so a device that
/// receives them names their rows at the diver's level with no pack of its
/// own. Run once at launch; a run analysed or renamed since keeps its own.
/// Never throws. Returns how many runs it wrote.
Future<int> fillNamingBarsFromInstalledPack({
  required Future<InstalledPack?> Function() installed,
  required MediaIdentificationRepository identifications,
  required Future<String?> Function() deviceId,
}) async {
  try {
    final pack = await installed();
    if (pack == null) return 0;
    final manifest = pack.manifest;
    return await identifications.fillNamingBars(
      manifest.packVersion,
      NamingBars.fromNaming(manifest.naming),
      deviceId: await deviceId(),
    );
  } on Object catch (e) {
    _log.debug('Could not give old runs their naming bars', error: e);
    return 0;
  }
}
