import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/misplaced_logbook.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Dive count per diver id. Refreshes on every write to dives or divers, so
/// a sync that brings in another device's logbook updates it.
final diveCountsByDiverProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(diverRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDiveCountChanges());
  return repository.getDiveCountsByDiver();
});

/// SharedPreferences key for the (active, target) pairs the user chose to
/// keep apart. Device-local on purpose: the active profile is per device, so
/// a choice made on one device says nothing about another.
const String misplacedLogbookKeptBothKey = 'misplaced_logbook_kept_both';

final misplacedLogbookKeptBothProvider =
    StateNotifierProvider<MisplacedLogbookKeptBothNotifier, Set<String>>((ref) {
      return MisplacedLogbookKeptBothNotifier(
        ref.watch(sharedPreferencesProvider),
      );
    });

class MisplacedLogbookKeptBothNotifier extends StateNotifier<Set<String>> {
  final SharedPreferences _prefs;

  MisplacedLogbookKeptBothNotifier(this._prefs)
    : super({...?_prefs.getStringList(misplacedLogbookKeptBothKey)});

  Future<void> keepBoth(String activeId, String targetId) async {
    final next = {...state, misplacedLogbookPairKey(activeId, targetId)};
    state = next;
    await _prefs.setStringList(misplacedLogbookKeptBothKey, next.toList());
  }
}

/// The misplaced logbook for this device's active profile, or null when
/// there is nothing to offer (issue #3549). Drives the banner on the Dives
/// list.
final misplacedLogbookProvider = FutureProvider<MisplacedLogbook?>((ref) async {
  final activeDiverId = ref.watch(currentDiverIdProvider);
  final keptBoth = ref.watch(misplacedLogbookKeptBothProvider);
  if (activeDiverId == null) return null;
  // The counts are one GROUP BY; the profiles are hydrated rows (contacts,
  // documents, photo). Settle the common case, an active profile with dives
  // or no other profile with any, before loading them.
  final counts = await ref.watch(diveCountsByDiverProvider.future);
  if ((counts[activeDiverId] ?? 0) > 0) return null;
  if (otherDiveHolderIds(counts, activeDiverId).isEmpty) return null;
  final divers = await ref.watch(allDiversProvider.future);
  return findMisplacedLogbook(
    activeDiverId: activeDiverId,
    divers: divers,
    diveCounts: counts,
    keptBoth: keptBoth,
  );
});
