import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';
import 'package:submersion/features/media/presentation/helpers/asset_import_candidate.dart';

void main() {
  AssetInfo asset({String? filename, TakenAtSource? source}) => AssetInfo(
    id: 'asset-1',
    type: AssetType.video,
    createDateTime: DateTime(2025, 12, 27, 11, 50, 49),
    width: 0,
    height: 0,
    filename: filename,
    takenAtSource: source,
  );

  test('dates the row in wall-clock UTC with the same digits', () {
    final c = importCandidateForAsset(asset(filename: 'clip.mp4'));

    expect(c.key, 'asset-1');
    expect(c.title, 'clip.mp4');
    expect(c.takenAt, DateTime.utc(2025, 12, 27, 11, 50, 49));
    expect(c.preview, isA<AssetImportPreview>());
  });

  test('falls back to the id when the asset has no filename', () {
    expect(importCandidateForAsset(asset()).title, 'asset-1');
  });

  test('carries where the date came from to the review row', () {
    // Without it, a clip dated only by its mtime reads as a bare "No
    // matching dive" in every review that builds rows from picked assets.
    expect(
      importCandidateForAsset(
        asset(source: TakenAtSource.fileModifiedTime),
      ).takenAtSource,
      TakenAtSource.fileModifiedTime,
    );
    expect(importCandidateForAsset(asset()).takenAtSource, isNull);
  });
}
