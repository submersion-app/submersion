import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The buddy list's query (#2365): typed, built or applied from a saved
/// query in the filter sheet; null lists every buddy.
final buddyQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The buddy list: every visible buddy with its dive count, narrowed to the
/// query's ids. The list, compact pane and table all read this.
final filteredBuddiesWithDiveCountProvider =
    Provider<AsyncValue<List<BuddyWithDiveCount>>>(
      (ref) => narrowByQuery(
        ref,
        ref.watch(allBuddiesWithDiveCountProvider),
        buddyQueryEntity,
        ref.watch(buddyQueryProvider),
        (b) => b.buddy.id,
      ),
    );
