import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// Canonical list of every nav destination, including the `more` sentinel.
final navDestinationsProvider = Provider<List<NavDestination>>((ref) {
  return kNavDestinations;
});

/// Ids of destinations the user can reorder on either surface.
final movableNavIdsProvider = Provider<List<String>>((ref) => movableNavIds);

/// The phone nav order: bottom-bar slots first, then the More menu, in order.
final navPhoneOrderNotifierProvider =
    StateNotifierProvider<NavOrderNotifier, List<String>>((ref) {
      final repository = ref.watch(appSettingsRepositoryProvider);
      return NavOrderNotifier(
        read: repository.getNavPrimaryIdsRaw,
        write: repository.setNavPrimaryIds,
        movableIds: ref.watch(movableNavIdsProvider),
      );
    });

/// The wide-screen rail order, below the pinned Home destination.
///
/// Independent of the phone order: a rail is long enough to show everything,
/// so the sequence that reads well there is rarely the one that decides which
/// three destinations earn a bottom-bar slot.
final navRailOrderNotifierProvider =
    StateNotifierProvider<NavOrderNotifier, List<String>>((ref) {
      final repository = ref.watch(appSettingsRepositoryProvider);
      return NavOrderNotifier(
        read: repository.getNavRailIdsRaw,
        write: repository.setNavRailIds,
        movableIds: ref.watch(movableNavIdsProvider),
      );
    });

/// Convenience alias -- reads the current normalized phone order.
final navPhoneOrderProvider = Provider<List<String>>((ref) {
  return ref.watch(navPhoneOrderNotifierProvider);
});

/// Convenience alias -- reads the current normalized rail order.
final navRailOrderProvider = Provider<List<String>>((ref) {
  return ref.watch(navRailOrderNotifierProvider);
});

/// The 5-entry phone primary list: [dashboard, slot2, slot3, slot4, more].
final navPrimaryDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final byId = _destinationsById(ref);
  final middle = ref
      .watch(navPhoneOrderProvider)
      .take(kPhonePrimarySlotCount)
      .map((id) => byId[id])
      .whereType<NavDestination>()
      .toList(growable: false);
  return [byId['dashboard']!, ...middle, byId['more']!];
});

/// Phone overflow ("More") destinations, in the order the user chose.
final navOverflowDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final byId = _destinationsById(ref);
  return ref
      .watch(navPhoneOrderProvider)
      .skip(kPhonePrimarySlotCount)
      .map((id) => byId[id])
      .whereType<NavDestination>()
      .toList(growable: false);
});

/// Wide-screen rail destinations: pinned Home, then the user's rail order.
///
/// The `more` sentinel never appears here; a rail shows every destination, so
/// it has no overflow.
final navRailDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final byId = _destinationsById(ref);
  final rest = ref
      .watch(navRailOrderProvider)
      .map((id) => byId[id])
      .whereType<NavDestination>()
      .toList(growable: false);
  return [byId['dashboard']!, ...rest];
});

Map<String, NavDestination> _destinationsById(Ref ref) {
  return {for (final d in ref.watch(navDestinationsProvider)) d.id: d};
}

/// Owns one persisted nav order: the full list of movable ids, in the order
/// the user arranged them.
///
/// Two instances exist, one per surface, differing only in which settings key
/// [read] and [write] address.
class NavOrderNotifier extends StateNotifier<List<String>> {
  NavOrderNotifier({
    required this.read,
    required this.write,
    required this.movableIds,
  }) : super(normalizeNavOrder(stored: const [], movableIds: movableIds)) {
    _load();
  }

  static final _log = LoggerService.forClass(NavOrderNotifier);

  /// Reads the raw stored order, or `null` when the key has never been written.
  final Future<List<String>?> Function() read;

  /// Persists a normalized order.
  final Future<void> Function(List<String>) write;

  final List<String> movableIds;

  Future<void> _load() async {
    List<String>? raw;
    try {
      raw = await read();
    } catch (e, stackTrace) {
      // The repository already logs and swallows its own read errors, so this
      // only fires if the read itself could not be attempted. Keep the
      // canonical order rather than failing the provider: an unreadable
      // preference should cost the user their customization, not their nav.
      _log.error('Failed to load nav order', error: e, stackTrace: stackTrace);
      return;
    }
    final normalized = normalizeNavOrder(
      stored: raw ?? const [],
      movableIds: movableIds,
    );
    if (mounted) state = normalized;
  }

  /// Normalizes [ids], persists, and updates state.
  ///
  /// Rethrows a write failure so the caller can roll its optimistic UI back.
  Future<void> setOrder(List<String> ids) async {
    final normalized = normalizeNavOrder(stored: ids, movableIds: movableIds);
    await write(normalized);
    if (mounted) state = normalized;
  }

  /// Restores the canonical order.
  Future<void> resetToDefaults() => setOrder(movableIds);
}
