import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// How long typing rests before the dive list re-runs the search (#2773).
const Duration kDiveSearchDebounce = Duration(milliseconds: 300);

/// Rows in the inline jump-to-dive list under the search field.
const int kDiveJumpResultLimit = 5;

const _log = LoggerService('DiveSearch');

/// The diver opened the search row (the search icon, Cmd/Ctrl+F, or
/// focusing the field). The row also shows whenever anything is filtered;
/// see [diveSearchBarVisibleProvider].
final diveSearchBarOpenProvider = StateProvider<bool>((ref) => false);

/// Set by whatever opens the row and wants the caret in it; the row takes
/// the request (and clears it) once it is built.
final diveSearchFocusPendingProvider = StateProvider<bool>((ref) => false);

/// Bumped by every close or clear of the search ([closeDiveSearch]), so
/// the row drops text still waiting on its debounce, which would otherwise
/// land after the clear. Clear all, Close, Esc and the empty state's Clear
/// filters all go through it.
final diveSearchClearTickProvider = StateProvider<int>((ref) => 0);

/// Whether the search row is on screen: opened, or anything filtered, so a
/// search is never active out of sight.
final diveSearchBarVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(diveSearchBarOpenProvider) ||
      ref.watch(diveFilterProvider).hasActiveFilters,
);

/// The jump-to-dive rows for [query]: the typed query ALONE over every dive
/// of the diver, ignoring the list's other axes, newest first. A failure
/// hides the rows rather than surfacing an error over the list.
final diveJumpResultsProvider = FutureProvider.autoDispose
    .family<List<DiveSummary>, QueryNode>((ref, query) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      try {
        return await repository.getDiveSummaries(
          diverId: diverId,
          filter: DiveFilterState(query: query),
          limit: kDiveJumpResultLimit,
          disabledSafetyRules: ref.watch(safetyReviewDisabledRulesProvider),
        );
      } catch (e, stackTrace) {
        _log.error(
          'Jump-to-dive query failed',
          error: e,
          stackTrace: stackTrace,
        );
        return const <DiveSummary>[];
      }
    });
