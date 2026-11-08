import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// Which albums each gallery asset was listed in while a query walked the
/// library album by album. The library lists an asset once per album, so the
/// walk sees the same asset several times; this gathers those sightings.
class GalleryAlbumMembership {
  final Map<String, List<GalleryAlbum>> _albums = {};

  /// Records that [assetId] was listed in [album]. A null [album] is the
  /// library-wide "all photos" album, which holds everything and so tells the
  /// filter nothing; it is ignored.
  void add(String assetId, GalleryAlbum? album) {
    if (album == null) return;
    final albums = _albums.putIfAbsent(assetId, () => []);
    if (!albums.contains(album)) albums.add(album);
  }

  /// The albums [assetId] was listed in, in the order they were seen.
  List<GalleryAlbum> of(String assetId) =>
      List.unmodifiable(_albums[assetId] ?? const <GalleryAlbum>[]);

  /// [assets] with their recorded albums attached.
  List<AssetInfo> attach(List<AssetInfo> assets) => [
    for (final asset in assets) asset.copyWith(albums: of(asset.id)),
  ];
}
