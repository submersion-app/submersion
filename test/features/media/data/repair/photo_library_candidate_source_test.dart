import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/repair/photo_library_candidate_source.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

class _FakePicker implements PhotoPickerService {
  _FakePicker(this.assets);
  final List<AssetInfo> assets;
  final windows = <(DateTime, DateTime)>[];

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    windows.add((start, end));
    return [
      for (final a in assets)
        if (!a.createDateTime.isBefore(start) && !a.createDateTime.isAfter(end))
          a,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem broken(String id, DateTime takenAt) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  originalFilename: '$id.jpg',
  takenAt: takenAt,
  isOrphaned: true,
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

AssetInfo asset(String id, DateTime created) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: created,
  width: 100,
  height: 100,
);

void main() {
  test(
    'harvests assets inside the one-hour window keyed to the row filename',
    () async {
      final taken = DateTime(2026, 6, 12, 10, 30);
      final picker = _FakePicker([
        asset('near', taken.add(const Duration(minutes: 5))),
        asset('far', taken.add(const Duration(hours: 3))),
      ]);
      final source = PhotoLibraryCandidateSource(picker: picker);

      final harvest = await source.harvest([broken('a', taken)]);

      final candidates = harvest.byFilename['a.jpg']!;
      expect(candidates.map((c) => c.assetId), ['near']);
      expect(candidates.single.isGallery, isTrue);
      // Window bounds honored: takenAt +/- 1 hour.
      expect(
        picker.windows.single.$1,
        taken.subtract(const Duration(hours: 1)),
      );
      expect(picker.windows.single.$2, taken.add(const Duration(hours: 1)));
    },
  );

  test('no assets in range harvests nothing for that row', () async {
    final source = PhotoLibraryCandidateSource(picker: _FakePicker(const []));
    final harvest = await source.harvest([
      broken('a', DateTime(2026, 6, 12, 10, 30)),
    ]);
    expect(harvest.byFilename, isEmpty);
    expect(harvest.foundPaths, isEmpty);
  });
}
