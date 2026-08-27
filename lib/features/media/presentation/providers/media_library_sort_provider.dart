import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The library's active sort, persisted through the app settings key-value
/// store exactly as MediaLibraryViewModeNotifier persists the view mode.
///
/// Deliberately NOT part of MediaLibraryFilter: sort is a view preference,
/// and folding it into the filter would add a field to every serialized
/// smart album.
final mediaLibrarySortProvider =
    StateNotifierProvider<MediaLibrarySortNotifier, SortState<MediaSortField>>((
      ref,
    ) {
      return MediaLibrarySortNotifier(ref.watch(appSettingsRepositoryProvider));
    });

class MediaLibrarySortNotifier
    extends StateNotifier<SortState<MediaSortField>> {
  MediaLibrarySortNotifier(this._settings) : super(kDefaultMediaSort) {
    logFailure(_prime(), MediaLibrarySortNotifier, 'prime');
  }

  static const String settingKey = 'media_library_sort';

  final AppSettingsRepository _settings;

  Future<void> _prime() async {
    final raw = await _settings.getRawSetting(settingKey);
    if (!mounted || raw == null) return;
    final decoded = decodeMediaSort(raw);
    if (decoded != null) state = decoded;
  }

  Future<void> setSort(MediaSortField field, SortDirection direction) async {
    state = SortState(field: field, direction: direction);
    await _settings.setRawSetting(settingKey, encodeMediaSort(state));
  }
}
