import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

AssetInfo _asset(String id, DateTime createdAt) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: createdAt,
  width: 1920,
  height: 1080,
);

class _Picker implements PhotoPickerService {
  _Picker(this.assets);

  final List<AssetInfo> assets;

  @override
  bool get supportsGalleryBrowsing => true;

  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async => assets;

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;

  @override
  Future<String?> getFilePath(String assetId) async => null;

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async => null;
}

void main() {
  test('trip scan keeps boundary-day photo inside dive buffer', () async {
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime.utc(2024, 1, 15, 0, 10),
      entryTime: DateTime.utc(2024, 1, 15, 0, 10),
      exitTime: DateTime.utc(2024, 1, 15, 1, 0),
    );
    final picker = _Picker([
      _asset('pre-buffer', DateTime(2024, 1, 14, 23, 45)),
    ]);

    final result = await TripMediaScanner.scanGalleryForTrip(
      dives: [dive],
      tripStartDate: DateTime.utc(2024, 1, 15),
      tripEndDate: DateTime.utc(2024, 1, 15),
      existingAssetIds: const {},
      photoPickerService: picker,
    );

    expect(result, isNotNull);
    expect(result!.matchedByDive[dive], hasLength(1));
    expect(result.matchedByDive[dive]!.single.id, 'pre-buffer');
    expect(result.unmatched, isEmpty);
  });
}
