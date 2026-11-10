import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_health_record_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_health_record.dart';
import 'package:submersion/features/dive_log/domain/services/merge_heart_rate.dart';

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

/// [points], the profile a chart draws for [dive], with the dive's Apple
/// Health heart rate merged in where the profile has none (issue #637). Every
/// chart of a dive (the detail page, the list panel, full screen) draws
/// through this, so none of them loses the line. Watches the record, so the
/// chart redraws when it is read; the length and order of [points] are
/// unchanged, so analysis indexes stay aligned.
List<DiveProfilePoint> withHealthHeartRate(
  WidgetRef ref,
  Dive dive,
  List<DiveProfilePoint> points,
) => mergeHeartRate(
  points,
  ref.watch(diveHealthRecordProvider(dive.id)).value?.heartRateSamples ??
      const [],
  entryEpochSeconds:
      fromWallClockUtc(
        dive.entryTime ?? dive.dateTime,
      ).millisecondsSinceEpoch ~/
      1000,
);
