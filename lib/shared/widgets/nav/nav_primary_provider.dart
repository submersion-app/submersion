import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// Canonical list of every nav destination (14 entries including `more`).
final navDestinationsProvider = Provider<List<NavDestination>>((ref) {
  return kNavDestinations;
});

/// Ids of destinations that can be moved between primary and overflow (12 entries).
final movableNavIdsProvider = Provider<List<String>>((ref) => movableNavIds);

/// StateNotifier owning the 3-element primary middle-slot id list.
///
/// Exposes [NavPrimaryIdsNotifier.setPrimaryIds] (normalizes + writes through)
/// and [NavPrimaryIdsNotifier.resetToDefaults].
final navPrimaryIdsNotifierProvider =
    StateNotifierProvider<NavPrimaryIdsNotifier, List<String>>((ref) {
      return NavPrimaryIdsNotifier(
        repository: ref.watch(appSettingsRepositoryProvider),
        movableIds: ref.watch(movableNavIdsProvider),
        defaults: kDefaultPrimaryIds,
      );
    });

/// Convenience alias — reads the current normalized primary ids.
final navPrimaryIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(navPrimaryIdsNotifierProvider);
});

/// The full 5-entry primary list: [dashboard, slot2, slot3, slot4, more].
final navPrimaryDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final all = ref.watch(navDestinationsProvider);
  final byId = {for (final d in all) d.id: d};
  final home = byId['dashboard']!;
  final more = byId['more']!;
  final middle = ref
      .watch(navPrimaryIdsProvider)
      .map((id) => byId[id])
      .whereType<NavDestination>()
      .toList(growable: false);
  return [home, ...middle, more];
});

/// Movable destinations that are NOT currently primary, in canonical order.
final navOverflowDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final primaryIds = ref.watch(navPrimaryIdsProvider).toSet();
  return ref
      .watch(navDestinationsProvider)
      .where((d) => !d.isPinned && !primaryIds.contains(d.id))
      .toList(growable: false);
});

class NavPrimaryIdsNotifier extends StateNotifier<List<String>> {
  NavPrimaryIdsNotifier({
    required this.repository,
    required this.movableIds,
    required this.defaults,
  }) : super(defaults) {
    _load();
  }

  final AppSettingsRepository repository;
  final List<String> movableIds;
  final List<String> defaults;

  Future<void> _load() async {
    final raw = await repository.getNavPrimaryIdsRaw();
    final normalized = normalizeNavPrimaryIds(
      stored: raw ?? const [],
      movableIds: movableIds,
      defaults: defaults,
    );
    if (mounted) state = normalized;
  }

  /// Normalizes [ids], persists, and updates state.
  Future<void> setPrimaryIds(List<String> ids) async {
    final normalized = normalizeNavPrimaryIds(
      stored: ids,
      movableIds: movableIds,
      defaults: defaults,
    );
    await repository.setNavPrimaryIds(normalized);
    if (mounted) state = normalized;
  }

  /// Restores the default primary ids.
  Future<void> resetToDefaults() => setPrimaryIds(defaults);
}
