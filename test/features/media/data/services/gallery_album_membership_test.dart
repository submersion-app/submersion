import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/gallery_album_membership.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';

const _camera = GalleryAlbum(id: 'camera', name: 'Camera');
const _goPro = GalleryAlbum(id: 'gopro', name: 'GoPro');

void main() {
  test('collects every album an asset was listed in, in listing order', () {
    final membership = GalleryAlbumMembership()
      ..add('a', _goPro)
      ..add('b', _camera)
      ..add('a', _camera);

    expect(membership.of('a'), [_goPro, _camera]);
    expect(membership.of('b'), [_camera]);
  });

  test('ignores the library-wide album and repeats', () {
    final membership = GalleryAlbumMembership()
      ..add('a', null)
      ..add('a', _goPro)
      ..add('a', _goPro);

    expect(membership.of('a'), [_goPro]);
  });

  test('an asset seen only in the library-wide album has no albums', () {
    final membership = GalleryAlbumMembership()..add('a', null);

    expect(membership.of('a'), isEmpty);
    expect(membership.of('never-listed'), isEmpty);
  });

  test('attach copies each asset with its albums', () {
    final membership = GalleryAlbumMembership()..add('a', _goPro);
    final asset = AssetInfo(
      id: 'a',
      type: AssetType.image,
      createDateTime: DateTime.utc(2024),
      width: 1,
      height: 1,
    );

    expect(membership.attach([asset]).single.albums, [_goPro]);
  });
}
