import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// One choice in the Gallery tab's album filter: an album and how many of
/// the time window's assets it holds.
class GalleryAlbumOption {
  final GalleryAlbum album;
  final int count;

  const GalleryAlbumOption({required this.album, required this.count});
}

/// The albums that hold at least one of [assets], fullest first, then by
/// name. An asset in two albums counts toward both.
List<GalleryAlbumOption> galleryAlbumOptions(List<AssetInfo> assets) {
  final counts = <String, int>{};
  final albums = <String, GalleryAlbum>{};
  for (final asset in assets) {
    for (final album in asset.albums) {
      albums.putIfAbsent(album.id, () => album);
      counts.update(album.id, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final options = [
    for (final entry in albums.entries)
      GalleryAlbumOption(album: entry.value, count: counts[entry.key]!),
  ];
  options.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.album.name.toLowerCase().compareTo(b.album.name.toLowerCase());
  });
  return options;
}

/// The assets in the album [albumId], in their original order; all of them
/// when [albumId] is null.
List<AssetInfo> assetsInAlbum(List<AssetInfo> assets, String? albumId) {
  if (albumId == null) return assets;
  return [
    for (final asset in assets)
      if (asset.albums.any((album) => album.id == albumId)) asset,
  ];
}

/// The selection after the grid reports [selectedVisibleIds] as the picks
/// among [visibleIds]. Picks the album filter hides are kept, so switching
/// albums never drops a photo the user already chose.
Set<String> mergeVisibleSelection({
  required Set<String> current,
  required Iterable<String> visibleIds,
  required Iterable<String> selectedVisibleIds,
}) {
  final visible = visibleIds.toSet();
  return {
    ...current.where((id) => !visible.contains(id)),
    ...selectedVisibleIds,
  };
}
