import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// One choice in the Gallery tab's album filter: an album name and how many
/// of the time window's assets sit in an album of that name.
///
/// Keyed by name, not by album id, because the user can only tell albums
/// apart by name. Android names an album after its folder, so
/// `DCIM/Screenshots` and `Pictures/Screenshots` are two albums both called
/// "Screenshots"; as two chips with the same label each would hold an
/// unpredictable part of those photos.
class GalleryAlbumOption {
  final String name;
  final int count;

  const GalleryAlbumOption({required this.name, required this.count});
}

/// The album names that hold at least one of [assets], fullest first, then
/// by name. An asset in two albums counts toward both, but once per name.
List<GalleryAlbumOption> galleryAlbumOptions(List<AssetInfo> assets) {
  final counts = <String, int>{};
  for (final asset in assets) {
    for (final name in {for (final album in asset.albums) album.name}) {
      counts.update(name, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final options = [
    for (final entry in counts.entries)
      GalleryAlbumOption(name: entry.key, count: entry.value),
  ];
  options.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return options;
}

/// The assets in an album named [albumName], in their original order; all
/// of them when [albumName] is null.
List<AssetInfo> assetsInAlbum(List<AssetInfo> assets, String? albumName) {
  if (albumName == null) return assets;
  return [
    for (final asset in assets)
      if (asset.albums.any((album) => album.name == albumName)) asset,
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
