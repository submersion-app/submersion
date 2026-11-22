import 'package:collection/collection.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

/// Moves the crops of named identifications that this device analysed
/// before crops synced into the logbook (issue #4876), so the results
/// already here reach other devices with their pictures and without being
/// analysed again. Runs at launch, a batch of media at a time; safe to run
/// again, since a crop already moved has no file left.
class NamedCropBackfill {
  NamedCropBackfill({
    required MediaIdentificationRepository identifications,
    required IdentificationCropStore crops,
    required Future<String?> Function() deviceId,
  }) : _identifications = identifications,
       _crops = crops,
       _deviceId = deviceId;

  final MediaIdentificationRepository _identifications;
  final IdentificationCropStore _crops;
  final Future<String?> Function() _deviceId;
  final _log = LoggerService.forClass(NamedCropBackfill);

  /// Returns how many crops it moved. Never throws.
  Future<int> run({int batch = 50}) async {
    try {
      final me = await _deviceId();
      var moved = 0;
      // Only media with a crops folder can hold files still to move, so a
      // finished backfill reads no rows at all.
      for (final slice in (await _crops.mediaWithFiles()).slices(batch)) {
        final (runs, rows) = await _identifications.forMediaIdsWithRuns(
          slice,
          withPaths: false,
        );
        for (final mediaId in slice) {
          final run = runs[mediaId];
          // Another device's crops were never files here.
          if (run != null && me != null && !run.madeOn(me)) continue;
          moved += await _crops.promote(mediaId, [
            for (final i in rows[mediaId] ?? const <MediaIdentification>[])
              if (isNamed(i)) i.id,
          ]);
        }
      }
      // A crop whose mark failed after its write would otherwise never
      // sync: no backfill of unstamped rows covers crops.
      await _crops.republishUnstamped();
      return moved;
    } on Object catch (e) {
      _log.debug('Could not move named crops into the logbook', error: e);
      return 0;
    }
  }
}
