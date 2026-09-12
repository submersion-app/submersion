import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

final diveSensorSummaryRepositoryProvider =
    Provider<DiveSensorSummaryRepository>(
      (ref) => DiveSensorSummaryRepository(),
    );

/// Compute-through-cache: the stored summary when it is current for the
/// dive's version, otherwise a fresh one, stored before it is returned.
/// Null when the dive does not exist. Mirrors `safetyReviewProvider`.
///
/// Self-invalidates on the dive detail-change stream, which includes the
/// summaries table itself, so a sweep or a restore writing rows directly
/// reaches an open dive page without a restart.
final diveSensorSummaryProvider =
    FutureProvider.family<DiveSensorSummary?, String>((ref, diveId) async {
      final repo = ref.watch(diveSensorSummaryRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return repo.ensureCurrent(diveId);
    });
