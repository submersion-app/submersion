import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The diver's latest dive, which the trim calculator opens on when it is
/// not handed one (issue #5028); null for an empty log.
final trimCalculatorLatestDiveIdProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final summaries = await repository.getDiveSummaries(
    diverId: diverId,
    limit: 1,
  );
  return summaries.firstOrNull?.id;
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
