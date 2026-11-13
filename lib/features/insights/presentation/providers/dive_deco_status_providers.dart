import 'dart:async';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_source_stamp.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/sql/analysis_inputs_stamp_sql.dart';
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
/// [diveSourceStampSql], plus the analysis inputs and the stop events the
/// recorded signal reads). It runs only on demand: every provider whose
/// query reads the cache awaits it through `awaitQueryCachesIfRead`, and
/// `queryCachesKeeperProvider` keeps it alive while a live filter names
/// `deco`, so a diver who never filters on deco pays for no analysis.
///
/// Its value is the [diveDecoInputWritesProvider] count the pass began
/// from: a one-off reader compares the two to tell whether a write landed
/// after the pass it would read (`prepareQueryCachesFor`).
// no-tick: a WRITE of derived data, not a cached query. It follows the
// tables a verdict is derived from (below); its only repository call writes
// the cache and renders nothing.
// autoDispose: once no reader or keeper watches it, it is released and
// stops following those tables.
final diveDecoStatusCacheProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  // The id every reader scopes its query by, and that
  // `prepareQueryCachesFor` compares against: the raw id can be null or a
  // removed diver's, which would judge every profile's dives (or none of the
  // list's) under the active settings.
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  // Any analysis setting can move a verdict; the classification keys its
  // cache by this same fingerprint.
  ref.watch(diverAnalysisSettingsProvider.select((s) => s.fingerprint));
  ref.invalidateSelfWhen(
    _verdictInputWrites(
      DatabaseService.instance.database,
    ).debounce(QueryIdSetRunner.changeTickDebounce),
  );
  final startedFrom = ref.read(diveDecoInputWritesProvider);
  final startedAt = nextDecoWriteStamp();

  // Every reader waits for this pass, and a cold library's first one runs
  // for minutes on a phone (#3807): the dive list and the Insights deco card
  // show how far it has got rather than a bare spinner.
  final progressState = ref.read(diveDecoStatusProgressProvider.notifier);
  DiveDecoAnalysisProgress? shown;
  void publish(DiveDecoAnalysisProgress? progress) {
    if (ref.mounted) progressState.state = shown = progress;
  }

  final ({Map<String, bool> verdicts, Set<String> scanned, bool complete})?
  judged;
  try {
    judged = await _judgeDiverDives(
      ref,
      diverId,
      onProgress: (analyzed, total) =>
          publish((analyzed: analyzed, total: total)),
    );
  } finally {
    if (ref.mounted) {
      publish(null);
    } else if (progressState.mounted && progressState.state == shown) {
      // Released part way through (its last reader gone): no newer pass
      // has shown a count of its own, so this pass's last one must not
      // stay on screen.
      progressState.state = null;
    }
  }
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
        computedAt: nextDecoWriteStamp(),
        // A targeted refresh may have written newer verdicts meanwhile.
        keepWrittenAfter: startedAt,
      );
  return startedFrom;
});

/// Classifies [diverId]'s dives (or [onlyDiveIds] of them) as the Insights
/// deco card does, under the settings [ref]'s container holds: the dives the
/// scan covered, the verdict of each the analysis could judge, and whether
/// it could judge every one that needed it. Null when
/// [ref] was rebuilt part way through, whose verdicts are incomplete.
Future<({Map<String, bool> verdicts, Set<String> scanned, bool complete})?>
_judgeDiverDives(
  Ref ref,
  String? diverId, {
  Set<String>? onlyDiveIds,
  void Function(int analyzed, int total)? onProgress,
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
  final total = scan.needsCompute.length;
  final verdicts = await const DecoClassificationService().classify(
    ref,
    scan.needsCompute,
    onProgress: onProgress == null
        ? null
        : (_, pending) {
            if (pending > 0) onProgress(total - pending, total);
          },
  );
  if (!ref.mounted) return null;
  return (
    verdicts: verdicts,
    // Every dive needing the analysis got a verdict: none failed or was
    // dropped, so nothing is left to retry.
    complete: verdicts.length == total,
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

/// How far a pass of [diveDecoStatusCacheProvider] has got: [analyzed] of
/// the [total] dives it has to analyze.
typedef DiveDecoAnalysisProgress = ({int analyzed, int total});

/// The progress of the running [diveDecoStatusCacheProvider] pass, or null
/// when none is analyzing (a warm library's pass analyzes nothing).
final diveDecoStatusProgressProvider = StateProvider<DiveDecoAnalysisProgress?>(
  (ref) => null,
);

/// The tables a dive's deco verdict derives from: those of
/// [diveSourceStampSql] and [diveAnalysisInputsStampSql] (the site's water,
/// the gas switches, the primary computer), plus the stop events the
/// recorded signal reads.
List<TableUpdateQuery> _verdictInputTables(AppDatabase db) => [
  for (final table in {
    ...diveSourceStampTables(db),
    ...diveAnalysisInputsStampTables(db),
  })
    TableUpdateQuery.onTable(table),
  TableUpdateQuery.onTable(db.diveProfileEvents),
];

/// Writes to [_verdictInputTables].
Stream<void> _verdictInputWrites(AppDatabase db) =>
    db.tableUpdates(TableUpdateQuery.allOf(_verdictInputTables(db)));

/// Counts every write to the tables a cached deco verdict derives from.
/// Settings are not counted: the active diver's pass follows its own
/// analysis fingerprint, and another profile's memo keys on its settings
/// row, so a units change re-runs nothing. Undebounced, so the count moves the moment a write lands, while
/// a pass waits out a burst before it re-runs. A pass records the count it
/// began from, so a reader can tell whether anything changed since.
class DecoInputWritesCounter extends StateNotifier<int> {
  DecoInputWritesCounter(Stream<void> writes) : super(0) {
    _subscription = writes.listen((_) => state++);
  }

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// The [DecoInputWritesCounter] count. Kept alive once first read, so no
/// write after a pass is missed while nothing else is listening.
final diveDecoInputWritesProvider =
    StateNotifierProvider<DecoInputWritesCounter, int>((ref) {
      final db = DatabaseService.instance.database;
      return DecoInputWritesCounter(
        db.tableUpdates(TableUpdateQuery.allOf(_verdictInputTables(db))),
      );
    });

/// For each profile other than the active one, the input-write count and
/// the settings row stamp its verdicts were last fully prepared from: a
/// query on that profile skips the re-scan while neither has moved.
final _profileDecoPassesProvider =
    StateProvider<Map<String, ({int writes, int? settings})>>(
      (ref) => const {},
    );

/// The stamp of [diverId]'s stored settings, which moves on any edit to
/// them (its gradient factors among them), or null with no row.
Future<int?> _settingsStamp(String diverId) async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT MAX(updated_at) AS stamp FROM diver_settings WHERE diver_id = ?',
        variables: [Variable<String>(diverId)],
      )
      .getSingle();
  return row.read<int?>('stamp');
}

/// Brings the cached verdicts of [diverId]'s dives up to date, or of
/// [diveIds] of them when given, leaving every other row as it is.
///
/// For a rule run over a few dives (an import's), which on a library nothing
/// has analyzed would otherwise wait for every dive in the logbook (#3807),
/// and for a query on a profile other than the active one (an agent's, a
/// multi-diver import's rules): that profile's dives are judged in a
/// throwaway container pinned to its own settings, so its gradient factors,
/// not the active diver's, decide (#4461). [isActive] says whether
/// [diverId] is the active profile, as the caller already resolved it. [ref]
/// must outlive the call: a service provider's.
Future<void> refreshDiveDecoStatusFor(
  Ref ref,
  String diverId,
  Set<String>? diveIds, {
  required bool isActive,
}) async {
  if (diveIds != null && diveIds.isEmpty) return;
  // A whole profile other than the active one, unchanged since its last
  // full pass (an agent paging through queries on it), needs no re-scan.
  final memoized = !isActive && diveIds == null;
  final startedFrom = (
    writes: ref.read(diveDecoInputWritesProvider),
    settings: memoized ? await _settingsStamp(diverId) : null,
  );
  if (memoized &&
      ref.read(_profileDecoPassesProvider)[diverId] == startedFrom) {
    return;
  }
  Future<({Map<String, bool> verdicts, Set<String> scanned, bool complete})?>
  judge() => isActive
      ? _judgeDiverDives(ref, diverId, onlyDiveIds: diveIds)
      : runInDiverContainer(
          ref,
          diverId: diverId,
          settingsRepository: ref.read(diverSettingsRepositoryProvider),
          body: (container) => _judgeDiverDives(
            container.read(_containerRefProvider),
            diverId,
            onlyDiveIds: diveIds,
          ),
        );

  // An input written while the analysis ran (a dive edit, a sync) can move
  // a verdict it judged from the older inputs, and nothing re-runs this
  // path afterwards: judge again, a bounded number of times, so the caller
  // does not act on a verdict from before its own write.
  var writesAtStart = startedFrom.writes;
  var stampAtStart = nextDecoWriteStamp();
  var judged = await judge();
  for (
    var retry = 0;
    judged != null &&
        retry < 3 &&
        ref.read(diveDecoInputWritesProvider) != writesAtStart;
    retry++
  ) {
    writesAtStart = ref.read(diveDecoInputWritesProvider);
    stampAtStart = nextDecoWriteStamp();
    judged = await judge();
  }
  // A rebuild stopped the analysis part way through: writing its partial
  // verdicts would delete the rows of the dives it skipped.
  if (judged == null) return;
  await ref
      .read(diveDecoStatusRepositoryProvider)
      .replaceFor(
        judged.verdicts,
        // The scan already kept to [diveIds] and to [diverId]'s dives, so a
        // named dive of another profile keeps its own verdict.
        diveIds: judged.scanned,
        computedAt: nextDecoWriteStamp(),
        // A pass or refresh that began after this one, and wrote meanwhile,
        // judged newer inputs: its verdicts stand.
        keepWrittenAfter: stampAtStart,
      );
  // A dive the analysis could not judge is retried by the next query, not
  // skipped until some unrelated write.
  if (memoized && judged.complete) {
    final passes = ref.read(_profileDecoPassesProvider.notifier);
    passes.state = {
      ...passes.state,
      diverId: (writes: writesAtStart, settings: startedFrom.settings),
    };
  }
}
