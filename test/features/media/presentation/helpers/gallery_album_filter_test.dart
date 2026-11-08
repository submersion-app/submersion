import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/helpers/gallery_album_filter.dart';

const _camera = GalleryAlbum(id: 'camera', name: 'Camera');
const _goPro = GalleryAlbum(id: 'gopro', name: 'GoPro');
const _whatsApp = GalleryAlbum(id: 'wa', name: 'WhatsApp Images');

AssetInfo _asset(String id, [List<GalleryAlbum> albums = const []]) =>
    AssetInfo(
      id: id,
      type: AssetType.image,
      createDateTime: DateTime.utc(2024, 1, 1, 10),
      width: 100,
      height: 100,
      albums: albums,
    );

void main() {
  group('galleryAlbumOptions', () {
    test('counts each album and puts the fullest first', () {
      final options = galleryAlbumOptions([
        _asset('1', [_goPro]),
        _asset('2', [_whatsApp]),
        _asset('3', [_goPro, _camera]),
        _asset('4', [_goPro]),
        _asset('5', [_camera]),
      ]);

      expect(options.map((o) => (o.name, o.count)), [
        ('GoPro', 3),
        ('Camera', 2),
        ('WhatsApp Images', 1),
      ]);
    });

    test('breaks a tie by name, ignoring case', () {
      const zeta = GalleryAlbum(id: 'z', name: 'zeta');
      const alpha = GalleryAlbum(id: 'a', name: 'Alpha');
      final options = galleryAlbumOptions([
        _asset('1', [zeta]),
        _asset('2', [alpha]),
      ]);

      expect(options.map((o) => o.name), ['Alpha', 'zeta']);
    });

    test('folds albums that share a name into one option', () {
      const dcim = GalleryAlbum(id: 'dcim/shots', name: 'Screenshots');
      const pictures = GalleryAlbum(id: 'pictures/shots', name: 'Screenshots');
      final options = galleryAlbumOptions([
        _asset('1', [dcim]),
        _asset('2', [pictures]),
        _asset('3', [dcim, pictures]),
      ]);

      expect(options.map((o) => (o.name, o.count)), [('Screenshots', 3)]);
      expect(
        assetsInAlbum([
          _asset('1', [dcim]),
          _asset('2', [pictures]),
          _asset('4', [_goPro]),
        ], 'Screenshots').map((a) => a.id),
        ['1', '2'],
      );
    });

    test('lists nothing for assets that carry no albums', () {
      expect(galleryAlbumOptions([_asset('1'), _asset('2')]), isEmpty);
    });
  });

  group('assetsInAlbum', () {
    final assets = [
      _asset('1', [_goPro]),
      _asset('2', [_whatsApp]),
      _asset('3'),
    ];

    test('a null album keeps every asset, in order', () {
      expect(assetsInAlbum(assets, null).map((a) => a.id), ['1', '2', '3']);
    });

    test('an album keeps only its own assets', () {
      expect(assetsInAlbum(assets, 'GoPro').map((a) => a.id), ['1']);
    });
  });

  group('mergeVisibleSelection', () {
    test('keeps picks the filter hides and replaces the visible ones', () {
      final merged = mergeVisibleSelection(
        current: {'hidden', 'shown-a'},
        visibleIds: ['shown-a', 'shown-b'],
        selectedVisibleIds: ['shown-b'],
      );

      expect(merged, {'hidden', 'shown-b'});
    });
  });

  group('AssetInfo.albums', () {
    test('defaults to none and survives copyWith', () {
      final asset = _asset('1', [_goPro]);

      expect(_asset('2').albums, isEmpty);
      expect(asset.copyWith(filename: 'x.jpg').albums, [_goPro]);
      expect(asset.copyWith(albums: [_camera]).albums, [_camera]);
    });

    test('GalleryAlbum compares by id and name', () {
      expect(const GalleryAlbum(id: 'gopro', name: 'GoPro'), equals(_goPro));
      expect(const GalleryAlbum(id: 'gopro', name: 'Other'), isNot(_goPro));
    });

    test('equal albums hash alike, so a set holds one', () {
      final copy = GalleryAlbum(id: _goPro.id, name: _goPro.name);

      expect(copy.hashCode, _goPro.hashCode);
      expect({_goPro, copy, _camera}, hasLength(2));
    });
  });
}
