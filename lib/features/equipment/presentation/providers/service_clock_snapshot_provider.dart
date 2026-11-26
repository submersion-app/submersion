import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/services/loaded_service_clocks.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

const _log = LoggerService('ServiceClockSnapshot');

/// Evaluates clocks over one item's loaded usage, kinds and window.
typedef ServiceClockEvaluator =
    List<ServiceClockStatus> Function(
      List<ServiceSchedule> schedules,
      List<ServiceRecord> records,
    );

/// One read of an item's clocks: its stored schedules and service records,
/// their verdicts, and an [evaluate] over the same usage for clocks and
/// records a sitting holds instead (issue #5042).
///
/// The Service clocks card draws its rows and their verdicts from one of
/// these, so it never pairs a schedule list from after a write with verdicts
/// from before it.
class ServiceClockSnapshot {
  ServiceClockSnapshot({
    required List<ServiceSchedule> schedules,
    required List<ServiceRecord> records,
    required this.evaluate,
  }) : schedules = List.unmodifiable(schedules),
       records = List.unmodifiable(records),
       statuses = List.unmodifiable(evaluate(schedules, records));

  /// The item's clocks as stored, paused ones included.
  final List<ServiceSchedule> schedules;

  /// The item's service records as stored.
  final List<ServiceRecord> records;

  /// The verdicts on [schedules] given [records]: one per enabled clock with
  /// an interval.
  final List<ServiceClockStatus> statuses;

  /// The engine over this read's usage, kinds, window and moment.
  final ServiceClockEvaluator evaluate;

  /// The verdicts on [schedules] given [records], each the stored list when
  /// null: the stored verdicts when both are, else evaluated afresh.
  List<ServiceClockStatus> statusesFor({
    List<ServiceSchedule>? schedules,
    List<ServiceRecord>? records,
  }) {
    if (schedules == null && records == null) return statuses;
    return evaluate(schedules ?? this.schedules, records ?? this.records);
  }
}

/// [ServiceClockSnapshot] of one equipment item, or null when it has no row.
///
/// Unlike [serviceClockStatusesProvider] it reads the usage and kinds even
/// for an item with no clock, so a clock a sitting adds can be evaluated.
/// It refreshes on the same inputs.
final serviceClockSnapshotProvider =
    FutureProvider.family<ServiceClockSnapshot?, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      final scheduleRepository = ref.watch(serviceScheduleRepositoryProvider);
      final recordRepository = ref.watch(serviceRecordRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      ref.invalidateSelfWhen(repository.watchAttributeChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      ref.invalidateSelfWhen(recordRepository.watchServiceRecordsChanges());
      ref.invalidateSelfWhen(scheduleRepository.watchSchedulesChanges());

      final item = await repository.getEquipmentById(equipmentId);
      if (item == null) return null;
      // A transmitter's dives include the tanks that carried its registered
      // serials, and assigning a serial writes only the registry.
      if (item.type == EquipmentType.transmitter) {
        ref.invalidateSelfWhen(
          ref.watch(transmitterRepositoryProvider).watchTransmittersChanges(),
        );
      }
      final schedules = await scheduleRepository.getSchedulesForEquipment(
        item.id,
      );
      final records = await recordRepository.getRecordsForEquipment(item.id);
      // Every kind, whoever made it: a shared item's clock can be on its
      // owner's custom kind (issue #2046).
      final kindsById = await ref.watch(allServiceKindsByIdProvider.future);
      final exposure = await repository.getItemExposure(item);
      final window = await ref.watch(serviceDueSoonWindowDaysProvider.future);
      final thresholds = ref.watch(exposureThresholdsProvider);
      final now = DateTime.now();
      return ServiceClockSnapshot(
        schedules: schedules,
        records: records,
        evaluate: (schedules, records) => evaluateLoadedServiceClocks(
          item,
          schedules: schedules,
          kindsById: kindsById,
          records: records,
          exposure: exposure,
          thresholds: thresholds,
          dueSoonWindowDays: window,
          now: now,
        ),
      );
    });

/// Reads [equipmentId]'s [serviceClockSnapshotProvider] again and waits for
/// the read, for at most [timeout]: for a Save that wrote the item's clocks,
/// so the card showing the clocks the sitting held goes on to the ones
/// stored, not to a read from before the write (issue #5042).
///
/// Best effort: a read that fails or takes longer is logged, and the card
/// then follows the stored clocks when they land.
Future<void> rereadServiceClockSnapshot(
  ProviderContainer container,
  String equipmentId, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final provider = serviceClockSnapshotProvider(equipmentId);
  container.invalidate(provider);
  try {
    await container.read(provider.future).timeout(timeout);
  } catch (error, stackTrace) {
    _log.warning(
      'Reading the service clocks again after a save failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
