import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_importer.dart';
import 'package:submersion/features/universal_import/data/services/garmin_download_history.dart';

const _log = LoggerService('GarminMarkerAfterImport');

/// Moves a Garmin's download marker on once the diver has finished
/// importing its dives (issue #4223), whatever they imported, skipped or
/// matched to dives already logged: none is offered again.
///
/// Only for an import of exactly the files [pending] was made for, so a
/// later hand-picked file import never moves it. The serials of the
/// imported [dives] find the computer when the watch's own serial does not,
/// as on its first download. Returns whether the marker was saved.
Future<bool> saveGarminMarkerAfterImport({
  required GarminPendingMarker? pending,
  required Iterable<String?> importedPaths,
  required Iterable<Map<String, dynamic>> dives,
  required GarminDownloadHistory history,
}) async {
  if (pending == null) return false;
  final paths = importedPaths.whereType<String>().toSet();
  if (paths.isEmpty ||
      paths.length != pending.paths.length ||
      !paths.every(pending.paths.contains)) {
    return false;
  }
  final fitSerials = {
    for (final dive in dives)
      if (dive['diveComputerSerial'] case final String serial
          when serial.trim().isNotEmpty)
        serial.trim(),
  };
  try {
    return await history.save(
      pending.marker,
      computerId: pending.computerId,
      watchSerial: pending.watchSerial,
      fitSerials: fitSerials,
    );
  } catch (e) {
    // The dives are in; at worst the next download offers them again.
    _log.warning('Saving the Garmin download marker failed: $e');
    return false;
  }
}
