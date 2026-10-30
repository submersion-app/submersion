import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/battery_cycles.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';

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
