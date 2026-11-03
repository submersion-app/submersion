import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// How a store resolver gets one tier of an item: from what it already
/// holds, else from the store. On disk in the installed apps
/// (`DiskMediaStoreFetches`); in memory in a browser
/// (`MemoryMediaStoreFetches`), which has no file to download into (issue
/// #4121). The resolver keeps the rest: which tiers to try, in what order,
/// one fetch per tier at a time.
///
/// Each returns null when the tier cannot be served (absent, unreadable,
/// failing its hash check), so the resolver can fall through to the next.
abstract interface class MediaStoreFetches {
  /// The thumb. A copy held from before [freshAfter] is not served;
  /// [isPoster] marks a decodable stand-in for a row that is not itself an
  /// image.
  Future<MediaSourceData?> thumb(
    MediaItem item,
    String hash, {
    DateTime? freshAfter,
    required bool isPoster,
  });

  /// The compressed rendition, fresh against the row's own stamp.
  Future<MediaSourceData?> rendition(MediaItem item, String hash);

  /// The original, checked against [hash].
  Future<MediaSourceData?> original(MediaItem item, String hash);
}
