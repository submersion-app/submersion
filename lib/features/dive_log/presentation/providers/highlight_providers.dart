import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

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

/// Whether the profile chart preview panel is visible above the dive list.
///
/// Defaults to true. Initialized from persisted settings in
/// [_DiveListContentState.initState] via [initProfilePanelFromSettings].
/// Can be toggled at runtime via the toolbar button.
final showProfilePanelProvider = StateProvider<bool>((ref) => true);
