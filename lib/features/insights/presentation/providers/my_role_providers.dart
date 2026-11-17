import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/retain_for.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

/// Dives per role the diver held, plus Not set (issue #4409). Ticks, stays
/// alive and waits for the filter's caches as the cards in
/// `insights_providers.dart` do through their keep-alive helper.
final diverRoleDistributionProvider = FutureProvider<List<DistributionSegment>>(
  (ref) async {
    final repository = ref.watch(insightsRepositoryProvider);
    final diverId = ref.watch(currentDiverIdProvider);
    final filter = ref.watch(insightsFilterProvider);
    ref.invalidateSelfWhen(repository.watchInsightsChanges(filter: filter));
    retainFor(ref, const Duration(minutes: 5));
    await awaitInsightsFilterCaches(ref);
    return repository.getDiverRoleDistribution(
      diverId: diverId,
      filter: filter,
    );
  },
);
