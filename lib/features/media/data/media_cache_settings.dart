// The two media cache sizes a diver can set (issue #3337): how much decoded
// image the app keeps in memory, and how much thumbnail it keeps on disk.
//
// Both are device-local, stored in SharedPreferences rather than on the
// diver's synced settings: a phone must not inherit a desktop's sizes.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The in-memory cache slider's stops, in MB.
const List<int> kMemoryCacheStepsMb = [64, 128, 256, 512, 1024, 2048, 4096];

/// The thumbnail disk cache slider's stops, in MB.
const List<int> kDiskCacheStepsMb = [256, 512, 1024, 2048, 4096, 8192, 16384];

/// The cap was a fixed 75 MB before it became a setting, which is not a
/// stop; 128 is the stop above it.
const int kDefaultMemoryCacheMb = 128;

/// The thumbnail pool was a fixed 256 MB while it held only thumbnails
/// fetched from the media store. It now holds one for every local photo
/// too, and 256 MB is only about 5,000 of them.
const int kDefaultDiskCacheMb = 512;

/// SharedPreferences key of the in-memory cache size, in MB.
const String kMediaMemoryCacheMbKey = 'media_memory_cache_mb';

/// SharedPreferences key of the thumbnail disk cache size, in MB.
const String kMediaDiskCacheMbKey = 'media_thumbnail_disk_cache_mb';

const int _bytesPerMb = 1024 * 1024;

/// [mb] moved to the nearest of [steps], or [fallback] when there is none.
///
/// A stored value can be off the stops: written by a build whose stops
/// differed, or edited by hand. A tie goes to the smaller stop.
int snapToCacheStep(int? mb, List<int> steps, {required int fallback}) {
  if (mb == null) return fallback;
  var nearest = steps.first;
  for (final step in steps) {
    if ((step - mb).abs() < (nearest - mb).abs()) nearest = step;
  }
  return nearest;
}

/// The media cache sizes in force on this device.
@immutable
class MediaCacheSettings {
  const MediaCacheSettings({
    this.memoryCacheMb = kDefaultMemoryCacheMb,
    this.diskCacheMb = kDefaultDiskCacheMb,
  });

  /// What [prefs] holds, each size on a stop, with the default for a size
  /// never set.
  factory MediaCacheSettings.fromPrefs(SharedPreferences prefs) =>
      MediaCacheSettings(
        memoryCacheMb: snapToCacheStep(
          prefs.getInt(kMediaMemoryCacheMbKey),
          kMemoryCacheStepsMb,
          fallback: kDefaultMemoryCacheMb,
        ),
        diskCacheMb: snapToCacheStep(
          prefs.getInt(kMediaDiskCacheMbKey),
          kDiskCacheStepsMb,
          fallback: kDefaultDiskCacheMb,
        ),
      );

  /// Decoded images kept in memory, shared by the galleries and the
  /// full-screen viewer.
  final int memoryCacheMb;

  /// Thumbnails kept on disk. Governs the thumbnail pool only: originals and
  /// compressed copies fetched from the media store have pools of their own.
  final int diskCacheMb;

  int get memoryCacheBytes => memoryCacheMb * _bytesPerMb;

  int get diskCacheBytes => diskCacheMb * _bytesPerMb;

  MediaCacheSettings copyWith({int? memoryCacheMb, int? diskCacheMb}) =>
      MediaCacheSettings(
        memoryCacheMb: memoryCacheMb ?? this.memoryCacheMb,
        diskCacheMb: diskCacheMb ?? this.diskCacheMb,
      );

  @override
  bool operator ==(Object other) =>
      other is MediaCacheSettings &&
      other.memoryCacheMb == memoryCacheMb &&
      other.diskCacheMb == diskCacheMb;

  @override
  int get hashCode => Object.hash(memoryCacheMb, diskCacheMb);
}
