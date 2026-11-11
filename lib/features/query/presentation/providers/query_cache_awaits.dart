import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';

/// Each local cache of engine verdicts a query can read, by its table, with
/// the writer that mirrors it: the service-due verdicts `serviceDue` reads
/// (#2365) and the computed deco verdicts `deco` reads (#4461).
final Map<String, ProviderListenable<Future<void>>> _cacheWriters = {
  serviceStatusTable: equipmentServiceStatusCacheProvider.future,
  kDiveDecoStatusTable: diveDecoStatusCacheProvider.future,
};

/// The tables of the caches [awaitQueryCachesIfRead] waits for, for a
/// reader whose own change tick does not follow them.
Set<String> get queryCacheTables => _cacheWriters.keys.toSet();

Iterable<ProviderListenable<Future<void>>> _writersFor(
  Set<String> tablesTouched,
) => [
  for (final MapEntry(key: table, value: writer) in _cacheWriters.entries)
    if (tablesTouched.contains(table)) writer,
];

/// Waits for every local cache of engine verdicts a compiled query reads
/// (its `tablesTouched`). Each is mirrored from a Dart engine the SQL cannot
/// run, so a query that reads one before it is written would answer from an
/// empty or stale cache, or another diver's verdicts. A query that reads
/// none returns at once. The writers run in parallel.
///
/// Listens rather than watches: a writer run that changes no verdict must
/// not re-run the query, and one that does writes its table, whose tick the
/// caller follows. A provider [hold]s each writer for its own life; a
/// notifier, whose ref outlives each load, passes `hold: false` so repeated
/// loads add no listeners.
Future<void> awaitQueryCachesIfRead(
  Ref ref,
  Set<String> tablesTouched, {
  bool hold = true,
}) async {
  final subs = [
    for (final writer in _writersFor(tablesTouched))
      ref.listen(writer, (_, _) {}),
  ];
  try {
    await Future.wait<void>([for (final sub in subs) sub.read()]);
  } finally {
    if (!hold) {
      for (final sub in subs) {
        sub.close();
      }
    }
  }
}

/// [awaitQueryCachesIfRead] for a query run outside a provider's build on
/// behalf of [diverId]: a rule run, an agent's query.
///
/// For another profile than the active one, its dives' deco verdicts are
/// judged under its own settings (#4461). The service-due cache holds the
/// active profile's verdicts only; the agent's query tool overlays another
/// profile's itself.
///
/// Waits through the container, not a listener on [ref]: the caller is a
/// long-lived service provider that is usually paused (read, never
/// watched), and a paused provider's listener does not count as active, so
/// a writer invalidated mid-load by a table tick would never complete
/// (see `AwaitFuture`). No listener is kept past the wait.
///
/// [diveIds], when given, are the only dives whose deco verdicts the query
/// reads (a rule run over an import's dives, whose conditions read `deco`
/// on the dive itself): just those are analyzed, rather than the logbook.
Future<void> prepareQueryCachesFor(
  Ref ref,
  String diverId,
  Set<String> tables, {
  Set<String>? diveIds,
}) async {
  final readsDeco = tables.contains(kDiveDecoStatusTable);
  final active = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId != active) {
    if (readsDeco) {
      await refreshDiveDecoStatusFor(ref, diverId, diveIds, isActive: false);
    }
    return;
  }
  final targeted = readsDeco && diveIds != null;
  await Future.wait<void>([
    for (final writer in _writersFor(tables.difference({kDiveDecoStatusTable})))
      ref.container.awaitFuture(writer),
    if (targeted)
      refreshDiveDecoStatusFor(ref, diverId, diveIds, isActive: true)
    else if (readsDeco)
      _awaitCurrentDecoPass(ref.container),
  ]);
}

/// Waits for a deco writer pass that has seen every write before this call.
/// The writer re-runs on a debounced tick, so a query just after a write (an
/// agent's query after its own edit) could otherwise read the pass from
/// before it. A pass already current is not re-run while something else
/// holds the writer (a live `deco` filter's keeper). With nothing holding
/// it, the writer is released once this wait ends, so the next query starts
/// a fresh pass: a scan and a classification cache read, not a second
/// analysis.
Future<void> _awaitCurrentDecoPass(ProviderContainer container) async {
  final startedFrom = await container.awaitFuture(
    diveDecoStatusCacheProvider.future,
  );
  if (container.read(diveDecoInputWritesProvider) == startedFrom) return;
  container.invalidate(diveDecoStatusCacheProvider);
  await container.awaitFuture(diveDecoStatusCacheProvider.future);
}

/// [awaitQueryCachesIfRead] for a widget, which has a [WidgetRef] rather
/// than a provider's [Ref]: a one-off wait, so the listeners are always
/// released.
Future<void> awaitQueryCachesIfReadFromWidget(
  WidgetRef ref,
  Set<String> tablesTouched,
) async {
  final subs = [
    for (final writer in _writersFor(tablesTouched))
      ref.listenManual(writer, (_, _) {}),
  ];
  try {
    await Future.wait<void>([for (final sub in subs) sub.read()]);
  } finally {
    for (final sub in subs) {
      sub.close();
    }
  }
}
