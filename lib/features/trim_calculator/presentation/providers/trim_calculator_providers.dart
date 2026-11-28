import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Whether [d] was dived: not a plan (which can be dated ahead, and has no
/// logged profile) and not a draft still being logged.
bool _logged(DiveSummary d) => !d.isPlanned && !d.isOpenDraft;

/// The dives in [summaries] that were dived, in order.
List<DiveSummary> loggedDives(List<DiveSummary> summaries) => [
  for (final d in summaries)
    if (_logged(d)) d,
];

/// The first dive in [newestFirst] that was dived.
String? latestLoggedDiveId(List<DiveSummary> newestFirst) =>
    newestFirst.where(_logged).firstOrNull?.id;

/// How many summaries are read at a time while looking for the latest
/// logged dive.
const kTrimLatestDiveScan = 50;

/// The latest logged dive, reading [page] (summaries newest first, after a
/// cursor; null for the first page) a page at a time until one is found or
/// the log ends, so any run of plans and drafts ahead of it is passed over.
/// The date-sorted list pages by cursor: it ignores an offset.
Future<String?> findLatestLoggedDiveId(
  Future<List<DiveSummary>> Function(DiveSummaryCursor? after) page,
) async {
  DiveSummaryCursor? after;
  while (true) {
    final rows = await page(after);
    final id = latestLoggedDiveId(rows);
    if (id != null) return id;
    if (rows.length < kTrimLatestDiveScan) return null;
    final last = rows.last;
    after = DiveSummaryCursor(
      sortTimestamp: last.sortTimestamp,
      diveNumber: last.diveNumber ?? 0,
      id: last.id,
    );
  }
}

/// The diver's latest logged dive, which the trim calculator opens on when
/// it is not handed one (issue #5028); null for a log with none.
final trimCalculatorLatestDiveIdProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  return findLatestLoggedDiveId(
    (after) => repository.getDiveSummaries(
      diverId: diverId,
      cursor: after,
      limit: kTrimLatestDiveScan,
    ),
  );
});

/// How many recent dives the trim calculator's dive picker reads before the
/// diver searches.
const kTrimDivePickerRecentCount = 50;

/// The recent logged dives the trim calculator's dive picker offers as its
/// default list: plans and open drafts have no logged model to weigh.
/// Summaries: the rows show only number, site and date.
final trimCalculatorRecentDivesProvider =
    FutureProvider.autoDispose<List<DiveSummary>>((ref) async {
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      return loggedDives(
        await repository.getDiveSummaries(
          diverId: diverId,
          limit: kTrimDivePickerRecentCount,
        ),
      );
    });
