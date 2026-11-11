import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_source_stamp.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/dive_deco_status_repository.dart';
import 'package:submersion/features/insights/data/services/deco_classification_service.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/settings/presentation/providers/diver_pinned_container.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
///
/// Its value is the [diveDecoInputWritesProvider] count the pass began
/// from: a one-off reader compares the two to tell whether a write landed
/// after the pass it would read (`prepareQueryCachesFor`).
final diveDecoStatusCacheProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  // Any analysis setting can move a verdict; the classification keys its
  // cache by this same fingerprint.
  ref.watch(diverAnalysisSettingsProvider.select((s) => s.fingerprint));
  final db = DatabaseService.instance.database;
  final inputWrites = db.tableUpdates(
    TableUpdateQuery.allOf([
      for (final table in diveSourceStampTables(db))
        TableUpdateQuery.onTable(table),
      TableUpdateQuery.onTable(db.diveProfileEvents),
    ]),
  );
  // Undebounced, so the count moves the moment a write lands, while the
  // pass itself waits out a burst of writes before it re-runs.
  final counting = inputWrites.listen((_) {
    ref.read(diveDecoInputWritesProvider.notifier).state++;
  });
  ref.onDispose(counting.cancel);
  ref.invalidateSelfWhen(
    inputWrites.debounce(QueryIdSetRunner.changeTickDebounce),
  );
  final startedFrom = ref.read(diveDecoInputWritesProvider);
  final startedAt = DateTime.now().millisecondsSinceEpoch;

  // Every dive the diver logged, not only those statistics count: a dive
  // excluded from the card's rate is still one a deco search should find.
  final judged = await _judgeDiverDives(ref, diverId);
  // A rebuild replaced this pass part way through: its verdicts are
  // incomplete, and the pass that replaced it writes the whole set.
  if (judged == null) return startedFrom;
  await ref
      .read(diveDecoStatusRepositoryProvider)
      .replaceFor(
        judged.verdicts,
        // This diver's dives only: another profile's rows, prepared for a
        // query on that profile, are not this pass's to remove.
        diveIds: judged.scanned,
        computedAt: DateTime.now().millisecondsSinceEpoch,
        // A targeted refresh may have written newer verdicts meanwhile.
        keepWrittenAfter: startedAt,
      );
  return startedFrom;
});

/// Classifies [diverId]'s dives (or [onlyDiveIds] of them) as the Insights
/// deco card does, under the settings [ref]'s container holds: the dives the
/// scan covered, and the verdict of each the analysis could judge. Null when
/// [ref] was rebuilt part way through, whose verdicts are incomplete.
Future<({Map<String, bool> verdicts, Set<String> scanned})?> _judgeDiverDives(
  Ref ref,
  String? diverId, {
  Set<String>? onlyDiveIds,
}) async {
  // Every dive the diver logged, not only those statistics count: a dive
  // excluded from the card's rate is still one a deco search should find.
  final scan = await ref
      .read(insightsRepositoryProvider)
      .scanRecordedDecoSignals(
        diverId: diverId,
        statsScoped: false,
        onlyDiveIds: onlyDiveIds,
      );
  final verdicts = await const DecoClassificationService().classify(
    ref,
    scan.needsCompute,
  );
  if (!ref.mounted) return null;
  return (
    verdicts: verdicts,
    scanned: {
      ...scan.recordedDeco,
      ...scan.recordedNoDeco,
      ...scan.needsCompute.keys,
      ...scan.noProfile,
    },
  );
}

/// A probe for the [Ref] of a throwaway container, for the services that
/// take one.
final _containerRefProvider = Provider<Ref>((ref) => ref);

/// How many writes to the tables a deco verdict derives from the running
/// [diveDecoStatusCacheProvider] has seen. Counted only while it runs; a
/// pass started afresh reads every write before it.
final diveDecoInputWritesProvider = StateProvider<int>((ref) => 0);

/// Brings the cached verdicts of [diverId]'s dives up to date, or of
/// [diveIds] of them when given, leaving every other row as it is.
///
/// For a rule run over a few dives (an import's), which on a library nothing
/// has analyzed would otherwise wait for every dive in the logbook (#3807),
/// and for a query on a profile other than the active one (an agent's, a
/// multi-diver import's rules): that profile's dives are judged in a
/// throwaway container pinned to its own settings, so its gradient factors,
/// not the active diver's, decide (#4461). [ref] must outlive the call: a
/// service provider's.
Future<void> refreshDiveDecoStatusFor(
  Ref ref,
  String diverId,
  Set<String>? diveIds,
) async {
  if (diveIds != null && diveIds.isEmpty) return;
  final active = await ref.read(validatedCurrentDiverIdProvider.future);
  final judged = diverId == active
      ? await _judgeDiverDives(ref, diverId, onlyDiveIds: diveIds)
      : await runInDiverContainer(
          ref,
          diverId: diverId,
          settingsRepository: ref.read(diverSettingsRepositoryProvider),
          body: (container) => _judgeDiverDives(
            container.read(_containerRefProvider),
            diverId,
            onlyDiveIds: diveIds,
          ),
        );
  // A rebuild stopped the analysis part way through: writing its partial
  // verdicts would delete the rows of the dives it skipped.
  if (judged == null) return;
  await ref
      .read(diveDecoStatusRepositoryProvider)
      .replaceFor(
        judged.verdicts,
        diveIds: diveIds ?? judged.scanned,
        computedAt: DateTime.now().millisecondsSinceEpoch,
      );
}
