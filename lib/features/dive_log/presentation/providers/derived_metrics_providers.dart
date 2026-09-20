import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

final derivedMetricsRepositoryProvider = Provider<DerivedMetricsRepository>(
  (ref) => DerivedMetricsRepository(),
);

/// Compute-through-cache: the stored metrics when they are current for the
/// dive's version, otherwise fresh ones, stored before they are returned.
/// Null when the dive does not exist. Mirrors `diveSensorSummaryProvider`.
///
/// Self-invalidates on the dive detail-change stream, which includes the
/// derived tables, so a sweep or a restore writing rows directly reaches an
/// open dive page without a restart.
final diveDerivedMetricsProvider =
    FutureProvider.family<DiveDerivedMetrics?, String>((ref, diveId) async {
      final repo = ref.watch(derivedMetricsRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return repo.ensureCurrent(diveId);
    });
