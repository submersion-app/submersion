import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_favorites_normalize.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_primary_provider.dart';

export 'package:submersion/shared/widgets/nav/favorites/nav_favorites_normalize.dart';

/// Ordered list of favorited sidebar destination ids, stored per device.
///
/// Kept in SharedPreferences rather than AppSettings for the same reason as
/// display zoom: it is a device-local layout preference, and seeding from
/// SharedPreferences in the constructor means the sidebar renders the right
/// favorites on frame one instead of snapping after a database round-trip.
///
/// Only ids in [validIds] (the movable destinations: neither Home nor the
/// phone-only `more` sentinel) are ever accepted or surfaced.
class NavFavoritesNotifier extends StateNotifier<List<String>> {
  NavFavoritesNotifier(this._prefs, {required List<String> validIds})
    : _validIds = validIds,
      super(
        normalizeNavFavoriteIds(
          stored: _prefs.getStringList(SettingsKeys.navFavoriteIds) ?? const [],
          validIds: validIds,
        ),
      );

  final SharedPreferences _prefs;
  final List<String> _validIds;

  bool isFavorite(String id) => state.contains(id);

  /// Appends [id] to the favorites unless it is already present or is not a
  /// favoritable destination.
  Future<void> add(String id) async {
    if (!_validIds.contains(id) || state.contains(id)) return;
    await _commit([...state, id]);
  }

  Future<void> remove(String id) async {
    if (!state.contains(id)) return;
    await _commit(state.where((e) => e != id).toList());
  }

  Future<void> toggle(String id) => isFavorite(id) ? remove(id) : add(id);

  /// Moves the favorite at [oldIndex] so it ends up at [newIndex].
  ///
  /// Plain list semantics: [newIndex] is the item's final resting position,
  /// matching `ReorderableListView.onReorderItem` (which already accounts for
  /// the removed item). Out-of-range indices are ignored.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    if (newIndex < 0 || newIndex >= state.length) return;
    if (newIndex == oldIndex) return;
    final next = [...state];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    await _commit(next);
  }

  Future<void> _commit(List<String> ids) async {
    final normalized = normalizeNavFavoriteIds(
      stored: ids,
      validIds: _validIds,
    );
    state = normalized;
    await _prefs.setStringList(SettingsKeys.navFavoriteIds, normalized);
  }
}

final navFavoritesNotifierProvider =
    StateNotifierProvider<NavFavoritesNotifier, List<String>>((ref) {
      return NavFavoritesNotifier(
        ref.watch(sharedPreferencesProvider),
        validIds: ref.watch(movableNavIdsProvider),
      );
    });

/// The favorited destinations, resolved from ids in the user's chosen order.
final navFavoriteDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final byId = {for (final d in ref.watch(navDestinationsProvider)) d.id: d};
  return ref
      .watch(navFavoritesNotifierProvider)
      .map((id) => byId[id])
      .whereType<NavDestination>()
      .toList(growable: false);
});
