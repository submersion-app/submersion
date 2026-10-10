import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

/// The parts of a clone copied after its row is saved (issue #3184).
enum CloneExtrasStep { serviceClocks, sets, documents }

/// Copies a cloned item's service clocks, set memberships and documents from
/// its source.
///
/// Best effort, like the auto-attached clocks in `createEquipment`: the clone
/// is already committed, so a failing step is logged and reported, never
/// rethrown (a rethrow would invite a retry that duplicates the item). Each
/// step is caught on its own, so one failing does not skip the others.
class EquipmentCloneService {
  EquipmentCloneService({
    ServiceScheduleRepository? schedules,
    ServiceKindRepository? kinds,
    EquipmentSetRepository? sets,
    MediaRepository? media,
  }) : _schedules = schedules ?? ServiceScheduleRepository(),
       _kinds = kinds ?? ServiceKindRepository(),
       _sets = sets ?? EquipmentSetRepository(),
       _media = media ?? MediaRepository();

  final ServiceScheduleRepository _schedules;
  final ServiceKindRepository _kinds;
  final EquipmentSetRepository _sets;
  final MediaRepository _media;

  static final _log = LoggerService.forClass(EquipmentCloneService);

  /// Copies the extras of [sourceId] onto [cloneId], scoped to [diverId]
  /// (the clone's owner), and returns the steps that failed.
  Future<Set<CloneExtrasStep>> copyExtras({
    required String sourceId,
    required String cloneId,
    required String? diverId,
  }) async {
    final failed = <CloneExtrasStep>{};
    Future<void> run(CloneExtrasStep step, Future<void> Function() body) async {
      try {
        await body();
      } catch (e, stackTrace) {
        _log.error(
          'Copying ${step.name} from equipment $sourceId to its clone '
          '$cloneId failed; the clone was still created',
          error: e,
          stackTrace: stackTrace,
        );
        failed.add(step);
      }
    }

    await run(
      CloneExtrasStep.serviceClocks,
      () => _copyClocks(sourceId, cloneId, diverId),
    );
    await run(
      CloneExtrasStep.sets,
      () => _copySets(sourceId, cloneId, diverId),
    );
    await run(CloneExtrasStep.documents, () => _copyMedia(sourceId, cloneId));
    return failed;
  }

  /// The source's clocks without their baseline, so the clone counts from
  /// its own purchase or creation. A kind the clone already has (an
  /// auto-attached clock) takes the source's settings instead of a second
  /// clock; another diver's custom kind is skipped, as auto-attach does.
  Future<void> _copyClocks(
    String sourceId,
    String cloneId,
    String? diverId,
  ) async {
    final source = await _schedules.getSchedulesForEquipment(sourceId);
    if (source.isEmpty) return;
    final kinds = {for (final k in await _kinds.getAllKinds()) k.id: k};
    final onClone = {
      for (final s in await _schedules.getSchedulesForEquipment(cloneId))
        s.serviceKindId: s,
    };
    for (final schedule in source) {
      final kind = kinds[schedule.serviceKindId];
      if (kind == null) continue;
      if (!kind.isBuiltIn && kind.diverId != null && kind.diverId != diverId) {
        continue;
      }
      final existing = onClone[schedule.serviceKindId];
      if (existing != null) {
        await _schedules.updateSchedule(_withSettingsOf(existing, schedule));
      } else {
        final now = DateTime.now();
        onClone[schedule.serviceKindId] = await _schedules.createSchedule(
          _withSettingsOf(
            ServiceSchedule(
              id: '',
              equipmentId: cloneId,
              serviceKindId: schedule.serviceKindId,
              createdAt: now,
              updatedAt: now,
            ),
            schedule,
          ),
        );
      }
    }
  }

  /// [target] carrying [source]'s settings and no baseline.
  static ServiceSchedule _withSettingsOf(
    ServiceSchedule target,
    ServiceSchedule source,
  ) => target.copyWith(
    intervalDays: source.intervalDays,
    intervalDives: source.intervalDives,
    intervalHours: source.intervalHours,
    exposureIntervals: source.exposureIntervals,
    defaultCost: source.defaultCost,
    defaultCurrency: source.defaultCurrency,
    anchorDate: null,
    anchorSetAt: null,
    enabled: source.enabled,
  );

  Future<void> _copySets(
    String sourceId,
    String cloneId,
    String? diverId,
  ) async {
    for (final setId in await _sets.getSetIdsContaining(
      sourceId,
      diverId: diverId,
    )) {
      await _sets.addItemToSet(setId, cloneId);
    }
  }

  /// A new row per document or photo, on the clone only (no dive or site
  /// link, so a dive photo is not shown twice). The stored file is shared:
  /// the media store is content-addressed and keeps it while any row holds
  /// its hash.
  Future<void> _copyMedia(String sourceId, String cloneId) async {
    for (final item in await _media.getMediaForEquipment(sourceId)) {
      await _media.createMedia(
        item.copyWith(id: '', equipmentId: cloneId, diveId: null, siteId: null),
      );
    }
  }
}
