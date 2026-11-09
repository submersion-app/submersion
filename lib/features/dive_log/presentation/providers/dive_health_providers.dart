import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_health_record_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_health_record.dart';

final diveHealthRecordRepositoryProvider = Provider<DiveHealthRecordRepository>(
  (ref) => DiveHealthRecordRepository(),
);

/// The dive's Apple Health readings (issue #637), or null. Re-read when a
/// health record changes.
final diveHealthRecordProvider = FutureProvider.autoDispose
    .family<DiveHealthRecord?, String>((ref, diveId) {
      final repository = ref.watch(diveHealthRecordRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.forDive(diveId);
    });
