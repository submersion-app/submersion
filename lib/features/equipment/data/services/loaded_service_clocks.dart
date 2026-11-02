import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/battery_cycles.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Runs the engine over one item's already loaded inputs. The in-app clocks
/// and the reminders both end here, so a reminder fires on exactly the usage
/// the clock shows and the classifier is wired once.
List<ServiceClockStatus> evaluateLoadedServiceClocks(
  EquipmentItem item, {
  required List<ServiceSchedule> schedules,
  required Map<String, ServiceKind> kindsById,
  required List<ServiceRecord> records,
  required ItemExposure exposure,
  required ExposureThresholds thresholds,
  required int dueSoonWindowDays,
  required DateTime now,
}) {
  final classifier = ExposureClassifier(
    thresholds: thresholds,
    loopTimeOnly: exposure.isRebreather,
    countsCycles: accruesBatteryCycles(
      type: item.type,
      schedules: schedules,
      kindsById: kindsById,
    ),
    hasBatteryChild: exposure.fittedChildren.any(
      (c) => c.type == EquipmentType.battery,
    ),
  );
  return const ServiceDueEngine().evaluate(
    schedules: schedules,
    kindsById: kindsById,
    records: records,
    usage: exposure.samples,
    classifier: classifier,
    purchaseDate: item.purchaseDate,
    equipmentCreatedAt: item.createdAt ?? now,
    dueSoonWindowDays: dueSoonWindowDays,
    now: now,
  );
}

/// [items]' clocks keyed by equipment id, for the diver [settings] belong to:
/// their reminder window and exposure thresholds. An item without a clock is
/// absent. The reads are batched, so they grow by chunk rather than by item.
/// For a caller outside the provider graph, which follows the active diver
/// only.
Future<Map<String, List<ServiceClockStatus>>> evaluateServiceClocksForItems(
  List<EquipmentItem> items, {
  required Map<String, ServiceKind> kindsById,
  required AppSettings settings,
  required ServiceScheduleRepository schedules,
  required ServiceRecordRepository records,
  required EquipmentRepository equipment,
  required DateTime now,
}) async {
  final schedulesById = await schedules.getSchedulesForEquipmentIds([
    for (final i in items) i.id,
  ]);
  final scheduled = [
    for (final item in items)
      if (schedulesById.containsKey(item.id)) item,
  ];
  final recordsById = await records.getRecordsForEquipmentIds([
    for (final i in scheduled) i.id,
  ]);
  // The repository's one wiring, shared with the in-app clocks, so a
  // reminder fires on exactly the usage the clock shows: fitted parts
  // only, and a replaced part's dives stop at its successor.
  final exposures = await equipment.getItemExposures(scheduled);
  final thresholds = exposureThresholdsFromSettings(settings);
  final window = settings.serviceReminderDays.isEmpty
      ? 30
      : settings.serviceReminderDays.reduce((a, b) => a > b ? a : b);
  return {
    for (final item in scheduled)
      item.id: evaluateLoadedServiceClocks(
        item,
        schedules: schedulesById[item.id]!,
        kindsById: kindsById,
        records: recordsById[item.id] ?? const [],
        exposure: exposures[item.id]!,
        thresholds: thresholds,
        dueSoonWindowDays: window,
        now: now,
      ),
  };
}
