import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';

/// Currently highlighted dive ID in the list view.
///
/// Set on single-tap, cleared when entering bulk selection mode. A filter
/// change leaves it alone; read [listedHighlightedDiveIdProvider] where a
/// highlight the filter has excluded must not show.
final highlightedDiveIdProvider = StateProvider<String?>((ref) => null);

/// [highlightedDiveIdProvider], but only while the active filter lists its
/// dive.
///
/// Nothing clears the highlight when [diveFilterProvider] is replaced, and it
/// must not be cleared there: a filter the dive still satisfies (a tag chip
/// tapped in the master-detail pane, say) should keep the diver's place. So
/// the highlight is ignored rather than dropped, and comes back if the filter
/// is relaxed. Watched by [DiveProfilePanel], which loads the dive by id and
/// would otherwise preview one the table does not show. Consumers that match
/// the id against their own rows already ignore an excluded one.
///
/// Before the filtered list has loaded there is nothing to check against, so
/// the highlight passes through rather than flashing the empty state.
final listedHighlightedDiveIdProvider = Provider<String?>((ref) {
  final id = ref.watch(highlightedDiveIdProvider);
  if (id == null) return null;
  final dives = ref.watch(allDivesForTableProvider).value;
  if (dives == null) return id;
  return dives.any((d) => d.id == id) ? id : null;
});

/// How many dive rows the list loads while looking for the remembered dive
/// before it gives up and starts at the top, when the list's scrubber index
/// cannot say whether the dive is in the list at all (a short list has no
/// index, and a new one is still loading).
const int kRememberedDiveSearchLimit = 1000;

/// The dive the list comes back to: [highlightedDiveIdProvider], once the
/// paged list has loaded it (#3301).
///
/// The list loads 50 dives at a time, so the dive last opened can sit beyond
/// the rows loaded so far. While it might still be on a later page this is
/// loading, and the list pages forward. The list's scrubber index, which
/// holds every dive the filter selects, settles the question up front: a
/// dive it does not hold (deleted, filtered out, another diver's) resolves
/// to null without paging, and one it does hold is paged for however far
/// down it sits. Without an index the search stops at
/// [kRememberedDiveSearchLimit] rows. A failed page load also resolves to
/// null.
final rememberedDiveIdProvider = Provider<AsyncValue<String?>>((ref) {
  final id = ref.watch(highlightedDiveIdProvider);
  if (id == null) return const AsyncData(null);
  final list = ref.watch(paginatedDiveListProvider);
  if (list.hasError) return const AsyncData(null);
  final state = list.value;
  if (state == null) return const AsyncLoading();
  if (state.dives.any((d) => d.id == id)) return AsyncData(id);
  // Whether the whole list holds the dive: unknown while the index loads or
  // when the list is too short to have one.
  final index = ref.watch(diveScrubberIndexProvider);
  final entries = index.isLoading ? null : index.value?.entries;
  final listed = entries == null || entries.isEmpty
      ? null
      : entries.any((entry) => entry.id == id);
  if (listed == false) return const AsyncData(null);
  final mightBeLater =
      state.hasMore &&
      !state.loadMoreFailed &&
      (listed == true || state.dives.length < kRememberedDiveSearchLimit);
  return mightBeLater ? const AsyncLoading() : const AsyncData(null);
});

/// Whether the profile chart preview panel is visible above the dive list.
///
/// Defaults to true. Initialized from persisted settings in
/// [_DiveListContentState.initState] via [initProfilePanelFromSettings].
/// Can be toggled at runtime via the toolbar button.
final showProfilePanelProvider = StateProvider<bool>((ref) => true);
