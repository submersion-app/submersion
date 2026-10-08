import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';

/// The review row for one picked gallery or file-dialog asset.
///
/// Every review that starts from picked assets builds its rows here, so they
/// all carry the same date and the same note of where that date came from.
ImportCandidate importCandidateForAsset(AssetInfo asset) => ImportCandidate(
  key: asset.id,
  title: asset.filename ?? asset.id,
  // The same value the import persists as takenAt, so the match shown in the
  // review is the match the row would get.
  takenAt: TripMediaScanner.toWallClockUtc(asset.createDateTime),
  takenAtSource: asset.takenAtSource,
  preview: AssetImportPreview(asset.id),
);
