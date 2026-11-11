import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_cache_awaits.dart';

/// Whether the dive list's or Insights' live filter reads the cache whose
/// table is [table]: a query naming `gear.serviceDue` (#2365) or `deco`
/// (#4461). Only these two filters: the paged dive list is a notifier that
/// re-runs on the cache table's tick rather than holding the writer, and
/// Insights stays filtered while its tab is away. Every other reader (the
/// site, trip and equipment id sets, Connections, the search rows) holds the
/// writer itself exactly while it is shown, so a filter left on those does
/// not keep an engine running.
final queryCacheDemandProvider = Provider.family<bool, String>((ref, table) {
  bool reads(Set<String> tables) => tables.contains(table);
  return reads(diveFilterTablesTouched(ref.watch(diveFilterProvider))) ||
      reads(diveFilterTablesTouched(ref.watch(insightsFilterProvider)));
});

/// Keeps the writer of each cache in [queryCacheWriters] running while
/// [queryCacheDemandProvider] says a live filter reads it, and idle
/// otherwise, so a diver who never filters on one pays for no engine run.
/// The app root listens to this all session; readers that can wait also
/// await the write themselves (`awaitQueryCachesIfRead`).
final queryCachesKeeperProvider = FutureProvider<void>((ref) async {
  await Future.wait<void>([
    for (final MapEntry(key: table, value: writer) in queryCacheWriters.entries)
      if (ref.watch(queryCacheDemandProvider(table))) ref.watch(writer),
  ]);
});
