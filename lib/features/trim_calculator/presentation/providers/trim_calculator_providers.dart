import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The first dive in [newestFirst] that was dived: not a plan (which can be
/// dated ahead) and not a draft still being logged.
String? latestLoggedDiveId(List<DiveSummary> newestFirst) =>
    newestFirst.where((d) => !d.isPlanned && !d.isOpenDraft).firstOrNull?.id;

/// How many of the newest dives are searched for one that was dived.
const kTrimLatestDiveScan = 50;

/// The diver's latest logged dive, which the trim calculator opens on when
/// it is not handed one (issue #5028); null for a log with none.
final trimCalculatorLatestDiveIdProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final summaries = await repository.getDiveSummaries(
    diverId: diverId,
    limit: kTrimLatestDiveScan,
  );
  return latestLoggedDiveId(summaries);
});

/// How many recent dives the trim calculator's dive picker offers before the
/// diver searches.
const kTrimDivePickerRecentCount = 50;

/// The recent dives the trim calculator's dive picker offers as its default
/// list. Summaries: the rows show only number, site and date.
final trimCalculatorRecentDivesProvider =
    FutureProvider.autoDispose<List<DiveSummary>>((ref) async {
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      final diverId = ref.watch(currentDiverIdProvider);
      return repository.getDiveSummaries(
        diverId: diverId,
        limit: kTrimDivePickerRecentCount,
      );
    });
