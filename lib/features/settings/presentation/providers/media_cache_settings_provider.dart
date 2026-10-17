import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/media/data/network_cache_config.dart';

/// The media cache sizes: how much decoded image is kept in memory and how
/// much thumbnail is kept on disk (issue #3337).
///
/// Device-local like [MediaProvenanceBadgesNotifier], and for a stronger
/// reason than that one has: the right size is a property of the machine, so
/// a phone must not inherit a desktop's.
///
/// A memory change reaches the image cache at once. A disk change is stored
/// and the thumbnail pool is brought inside the new size straight away, so
/// lowering the slider frees the space now rather than at the next download.
class MediaCacheSettingsNotifier extends StateNotifier<MediaCacheSettings> {
  MediaCacheSettingsNotifier(
    SharedPreferences prefs, {
    void Function(int bytes)? applyMemoryCap,
    Future<void> Function()? onDiskCapChanged,
    Future<void> Function()? onEmptyDiskCache,
  }) : _prefs = prefs,
       _applyMemoryCap = applyMemoryCap ?? _applyToImageCache,
       _onDiskCapChanged = onDiskCapChanged,
       _onEmptyDiskCache = onEmptyDiskCache,
       super(MediaCacheSettings.fromPrefs(prefs));

  /// The defaults with nothing behind them, for a container without
  /// SharedPreferences. Changes still take effect; they are not stored.
  MediaCacheSettingsNotifier.unstored({
    MediaCacheSettings settings = const MediaCacheSettings(),
    void Function(int bytes)? applyMemoryCap,
  }) : _prefs = null,
       _applyMemoryCap = applyMemoryCap ?? _applyToImageCache,
       _onDiskCapChanged = null,
       _onEmptyDiskCache = null,
       super(settings);

  final SharedPreferences? _prefs;
  final void Function(int bytes) _applyMemoryCap;
  final Future<void> Function()? _onDiskCapChanged;
  final Future<void> Function()? _onEmptyDiskCache;
  final _log = LoggerService.forClass(MediaCacheSettingsNotifier);

  /// The latest preference write, which the next one waits on.
  ///
  /// The slider does not await a change, so two releases can have writes
  /// out together, and where a write replaces the whole preferences file
  /// (Windows, Linux) two in flight can land in either order. One at a time
  /// keeps the stored size the last one chosen.
  Future<void> _lastWrite = Future<void>.value();

  static void _applyToImageCache(int bytes) =>
      applyMediaCacheCaps(memoryBytes: bytes);

  Future<void> _persist(String key, int mb) {
    final prefs = _prefs;
    if (prefs == null) return Future<void>.value();
    final write = _lastWrite.then((_) => prefs.setInt(key, mb));
    // A failed write must not hold up the ones after it; its caller still
    // sees the error.
    _lastWrite = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  Future<void> setMemoryCacheMb(int mb) async {
    final snapped = snapToCacheStep(
      mb,
      kMemoryCacheStepsMb,
      fallback: kDefaultMemoryCacheMb,
    );
    if (snapped == state.memoryCacheMb) return;
    state = state.copyWith(memoryCacheMb: snapped);
    _applyMemoryCap(state.memoryCacheBytes);
    await _persist(kMediaMemoryCacheMbKey, snapped);
  }

  /// Empties the thumbnail disk cache. True when it was emptied; false when
  /// it could not be, or there is no cache behind this notifier. Never
  /// throws: the caller is a button.
  Future<bool> emptyDiskCache() async {
    final empty = _onEmptyDiskCache;
    if (empty == null) return false;
    try {
      await empty();
      return true;
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not empty the thumbnail cache',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> setDiskCacheMb(int mb) async {
    final snapped = snapToCacheStep(
      mb,
      kDiskCacheStepsMb,
      fallback: kDefaultDiskCacheMb,
    );
    if (snapped == state.diskCacheMb) return;
    state = state.copyWith(diskCacheMb: snapped);
    await _persist(kMediaDiskCacheMbKey, snapped);
    // Eviction is housekeeping. The size is already stored and every cache
    // store reads it when it next evicts, so a failure here (no cache
    // database yet, a locked file) costs a delay, not the setting.
    try {
      await _onDiskCapChanged?.call();
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not trim the thumbnail cache to its new size',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Defaults to the default sizes, with no storage behind it.
///
/// For the reason [mediaProvenanceBadgesProvider] gives: it must not reach
/// for [sharedPreferencesProvider], which throws in a container that did not
/// override it. `rootProviderOverrides` swaps in the stored-value notifier.
final mediaCacheSettingsProvider =
    StateNotifierProvider<MediaCacheSettingsNotifier, MediaCacheSettings>(
      (ref) => MediaCacheSettingsNotifier.unstored(),
    );
