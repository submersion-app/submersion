import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_source_stamp.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/data/repositories/dive_deco_status_repository.dart';
import 'package:submersion/features/insights/data/services/deco_classification_service.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

final diveDecoStatusRepositoryProvider = Provider<DiveDecoStatusRepository>(
  (ref) => DiveDecoStatusRepository(),
);

/// Mirrors the computed deco verdicts into the local cache the `deco` query
/// field reads (issue #4461): every one of the active diver's dives the
/// recorded data cannot classify, judged by [DecoClassificationService], the
/// pass behind the Insights deco card. Both share that service's persistent
/// cache, so a library either has analyzed costs one cache read here, not a
/// second analysis.
///
/// Re-runs on a diver switch, an analysis settings edit, and any write that
/// can move a dive's verdict or its revision (the tables of
/// [diveSourceStampSql], plus the stop events the recorded signal reads). It
/// runs only on demand: every provider whose query reads the cache awaits it
/// through `awaitQueryCachesIfRead`, and `diveDecoStatusKeeperProvider`
/// keeps it alive while a live filter names `deco`, so a diver who never
/// filters on deco pays for no analysis.
// no-tick: a WRITE of derived data, not a cached query. It follows the
// tables a verdict is derived from (below); its only repository call writes
// the cache and renders nothing.
// autoDispose: once no reader or keeper watches it, it is released and
// stops following those tables.
final diveDecoStatusCacheProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  // Any analysis setting can move a verdict; the classification keys its
  // cache by this same fingerprint.
  ref.watch(diverAnalysisSettingsProvider.select((s) => s.fingerprint));
  final db = DatabaseService.instance.database;
  ref.invalidateSelfWhen(
    db
        .tableUpdates(
          TableUpdateQuery.allOf([
            for (final table in diveSourceStampTables(db))
              TableUpdateQuery.onTable(table),
            TableUpdateQuery.onTable(db.diveProfileEvents),
          ]),
        )
        .debounce(QueryIdSetRunner.changeTickDebounce),
  );

  // Every dive the diver logged, not only those statistics count: a dive
  // excluded from the card's rate is still one a deco search should find.
  final scan = await ref
      .read(insightsRepositoryProvider)
      .scanRecordedDecoSignals(diverId: diverId, statsScoped: false);
  final computed = await const DecoClassificationService().classify(
    ref,
    scan.needsCompute,
  );
  // A rebuild replaced this pass part way through: its verdicts are
  // incomplete, and the pass that replaced it writes the whole set.
  if (!ref.mounted) return;
  await ref
      .read(diveDecoStatusRepositoryProvider)
      .replaceAll(computed, computedAt: DateTime.now().millisecondsSinceEpoch);
});

/// Waits for the deco verdict cache to mirror the analysis before a query
/// that reads it, so the query never sees an empty cache or another
/// diver's verdicts. Listens rather than watches: a writer run that changes
/// no verdict must not re-run the query, and one that does writes the
/// table, whose tick the caller follows. A provider [hold]s the writer for
/// its own life; a notifier, whose ref outlives each load, passes
/// `hold: false` so repeated loads add no listeners.
Future<void> awaitDiveDecoStatusIfRead(
  Ref ref,
  Set<String> tablesTouched, {
  bool hold = true,
}) async {
  if (!tablesTouched.contains(kDiveDecoStatusTable)) return;
  final sub = ref.listen(diveDecoStatusCacheProvider.future, (_, _) {});
  try {
    await sub.read();
  } finally {
    if (!hold) sub.close();
  }
}

/// [awaitDiveDecoStatusIfRead] for a widget, which has a [WidgetRef] rather
/// than a provider's [Ref]: a one-off wait, so the listener is always
/// released.
Future<void> awaitDiveDecoStatusIfReadFromWidget(
  WidgetRef ref,
  Set<String> tablesTouched,
) async {
  if (!tablesTouched.contains(kDiveDecoStatusTable)) return;
  final sub = ref.listenManual(diveDecoStatusCacheProvider.future, (_, _) {});
  try {
    await sub.read();
  } finally {
    sub.close();
  }
}
