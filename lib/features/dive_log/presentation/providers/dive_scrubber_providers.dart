import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Fewer dives than this barely fill three phone viewports, so their list
/// fetches no index and shows no scrubber.
const diveScrubberMinDives = 20;

/// The scrubber index and the diver, filter and sort it was built for.
class DiveScrubberIndex {
  const DiveScrubberIndex({
    required this.entries,
    required this.diverId,
    required this.filter,
    required this.sort,
  });

  final List<DiveScrubberEntry> entries;
  final String? diverId;
  final DiveFilterState filter;
  final SortState<DiveSortField> sort;

  /// Whether these entries are the list order for these inputs. A refetch
  /// for the same inputs leaves the order intact, so the old index stays
  /// usable until it lands.
  ///
  /// The filter compares by value, as the list's own reload listener does:
  /// an equal filter set again reloads nothing, so nothing would refetch an
  /// index dropped for it.
  bool builtFor({
    required String? diverId,
    required DiveFilterState filter,
    required SortState<DiveSortField> sort,
  }) => diverId == this.diverId && filter == this.filter && sort == this.sort;
}

// no-tick: refetches on every list reload via the list's revision, which
// follows the list's own change ticks.
/// Every dive the dive list shows, in its order, for the list scrubber.
///
/// Refetched whenever the list reloads from the top, which already covers
/// diver, filter and sort changes and the list's table ticks. Empty for a
/// list of fewer than [diveScrubberMinDives] dives.
final diveScrubberIndexProvider = FutureProvider.autoDispose<DiveScrubberIndex>(
  (ref) async {
    final revision = ref.watch(
      paginatedDiveListProvider.select((s) {
        final list = s.valueOrNull;
        return list == null || list.totalCount < diveScrubberMinDives
            ? null
            : list.revision;
      }),
    );
    final diverId = ref.read(currentDiverIdProvider);
    final filter = ref.read(diveFilterProvider);
    final sort = ref.read(diveSortProvider);
    final entries = revision == null
        ? const <DiveScrubberEntry>[]
        : await ref
              .read(diveRepositoryProvider)
              .getDiveScrubberIndex(
                diverId: diverId,
                filter: filter,
                sort: sort,
              );
    return DiveScrubberIndex(
      entries: entries,
      diverId: diverId,
      filter: filter,
      sort: sort,
    );
  },
);

/// Whether the dive list's scrubber is active, which hides the add-dive
/// button.
final diveListScrubbingProvider = StateProvider<bool>((ref) => false);
