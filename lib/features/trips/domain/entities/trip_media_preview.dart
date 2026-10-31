import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The most thumbnails any trip preview shows, and so the most items read for
/// one dive. The first N items of a day or of a trip are always among the
/// first N of each of their dives, so any preview up to this size can be
/// composed from [DiveMediaPreview.items] alone.
const int tripMediaPreviewLimit = 6;

/// Chronological, with id breaking ties: the order the preview query ranks a
/// dive's rows in, which merging several dives' previews has to keep.
int compareMediaChronologically(MediaItem a, MediaItem b) {
  final byTime = a.takenAt.compareTo(b.takenAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// One dive's earliest media, plus the counts of everything on the dive.
class DiveMediaPreview extends Equatable {
  /// At most [tripMediaPreviewLimit] items, in chronological order.
  final List<MediaItem> items;

  /// Every media item on the dive, not just [items].
  final int mediaCount;

  /// The photos among [mediaCount]; videos, signatures and documents are not.
  final int photoCount;

  const DiveMediaPreview({
    required this.items,
    required this.mediaCount,
    required this.photoCount,
  });

  DiveMediaPreview copyWith({
    List<MediaItem>? items,
    int? mediaCount,
    int? photoCount,
  }) {
    return DiveMediaPreview(
      items: items ?? this.items,
      mediaCount: mediaCount ?? this.mediaCount,
      photoCount: photoCount ?? this.photoCount,
    );
  }

  @override
  List<Object?> get props => [items, mediaCount, photoCount];
}

/// What the trip's small previews need, without the trip's full gallery.
class TripMediaPreview extends Equatable {
  /// Only dives that have media.
  final Map<String, DiveMediaPreview> byDiveId;

  const TripMediaPreview({this.byDiveId = const {}});

  static const empty = TripMediaPreview();

  TripMediaPreview copyWith({Map<String, DiveMediaPreview>? byDiveId}) {
    return TripMediaPreview(byDiveId: byDiveId ?? this.byDiveId);
  }

  /// Every media item on the trip.
  int get mediaCount =>
      byDiveId.values.fold(0, (sum, dive) => sum + dive.mediaCount);

  /// The trip's first [limit] items, across all its dives.
  List<MediaItem> earliest(int limit) {
    assert(limit <= tripMediaPreviewLimit);
    final items = [for (final dive in byDiveId.values) ...dive.items]
      ..sort(compareMediaChronologically);
    return items.take(limit).toList();
  }

  @override
  List<Object?> get props => [byDiveId];
}
