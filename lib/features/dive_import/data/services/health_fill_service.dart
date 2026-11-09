import 'package:submersion/features/dive_import/data/services/health_dive_writer.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';

/// Fills a plan or a draft (issue #637) from an Apple Health workout.
///
/// The workout is saved as a dive through [HealthDiveWriter] (numbered and
/// attributed to the Apple Watch), and the plan or draft is then merged into
/// it as a consolidation does: the watch's readings stay the main profile,
/// and what the diver typed on the plan or draft (notes, name, site,
/// rating, buddies, gear, positions) fills what the workout lacks. The
/// result keeps the workout's own id, so two devices filling the same
/// workout converge on one dive. A plan's sketched profile and switches are
/// dropped first: they are not readings.
class HealthFillService {
  HealthFillService({
    required DiveRepository dives,
    required HealthDiveWriter writer,
    ProfileSeriesRepository? series,
    DiveConsolidationService? consolidation,
  }) : _dives = dives,
       _writer = writer,
       _series = series ?? ProfileSeriesRepository(),
       _consolidation = consolidation ?? DiveConsolidationService(dives);

  final DiveRepository _dives;
  final HealthDiveWriter _writer;
  final ProfileSeriesRepository _series;
  final DiveConsolidationService _consolidation;

  /// Fills [targetDiveId] from [workout] and returns the filled dive's id.
  Future<String> fill({
    required String targetDiveId,
    required ImportedDive workout,
    required String diverId,
  }) async {
    final target = await _dives.getDiveById(targetDiveId);
    if (target == null || !(target.isPlanned || target.isDraft)) {
      throw StateError('Dive $targetDiveId is neither a plan nor a draft');
    }
    if (target.isPlanned && !target.isDraft) {
      await _series.deleteForDive(targetDiveId);
      await _dives.deleteGasSwitchesForDive(targetDiveId);
    }
    final watchDive = await _writer.importAsNew(workout, diverId: diverId);
    await _consolidation.apply(
      targetDiveId: watchDive.id,
      secondaryDiveIds: [targetDiveId],
    );
    return watchDive.id;
  }
}
