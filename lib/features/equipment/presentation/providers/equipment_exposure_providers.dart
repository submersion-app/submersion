import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';

/// One item's exposure samples with the classifier that reads them, wired
/// exactly as the service clocks wire theirs (same link semantics, same
/// install-date scoping, same rebreather contact rule), so the exposure
/// card, the trend chart and the clocks never disagree about a dive.
typedef ExposureInputs = ({
  EquipmentItem item,
  EquipmentItem? parent,
  List<EquipmentItem> children,
  List<EquipmentExposureSample> samples,
  ExposureClassifier classifier,
});

/// Null for an unknown item. Refreshes when the equipment table, the
/// attribute table (the install date decides which dives count) or any
/// dive detail table (links, tanks, summaries) changes.
final equipmentExposureInputsProvider =
    FutureProvider.family<ExposureInputs?, String>((ref, equipmentId) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      ref.invalidateSelfWhen(repository.watchAttributeChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      final item = await repository.getEquipmentById(equipmentId);
      if (item == null) return null;
      final parentId = item.parentEquipmentId;
      final parent = parentId == null
          ? null
          : await repository.getEquipmentById(parentId);
      // Fitted parts only: a legacy row can be retired or sold with
      // isActive left true, and must not switch the battery path off.
      final children = [
        for (final c in await repository.getChildEquipment(item.id))
          if (c.isFitted) c,
      ];
      final isRebreather =
          item.type == EquipmentType.rebreather ||
          parent?.type == EquipmentType.rebreather;
      final inherited = await repository.getExposureSamplesForEquipment(
        item.id,
        parentEquipmentId: parentId,
        installedSince: item.parentDivesFrom,
        rebreatherContact: isRebreather,
      );
      // A part that was replaced left its slot when its successor went in;
      // without this bound its page kept growing with the successor's
      // dives. Only a part no longer fitted can have one.
      final until = parentId == null || item.isFitted
          ? null
          : _successorStart(
              item,
              await repository.getChildEquipment(
                parentId,
                includeRetired: true,
              ),
            );
      final samples = until == null
          ? inherited
          : [
              for (final s in inherited)
                if (s.date.isBefore(until)) s,
            ];
      final classifier = ExposureClassifier(
        thresholds: ref.watch(exposureThresholdsProvider),
        loopTimeOnly: isRebreather,
        hasBatteryChild: children.any((c) => c.type == EquipmentType.battery),
      );
      return (
        item: item,
        parent: parent,
        children: children,
        samples: samples,
        classifier: classifier,
      );
    });

/// When the next part of [item]'s type went into the same slot after it,
/// or null when none has. Batteries carry no slot, so the next battery
/// of the same parent is the successor.
DateTime? _successorStart(EquipmentItem item, List<EquipmentItem> siblings) {
  final from = item.parentDivesFrom;
  if (from == null) return null;
  final slot = item.attrNum(EquipmentAttrKeys.cellSlot)?.round();
  DateTime? earliest;
  for (final s in siblings) {
    if (s.id == item.id || s.type != item.type) continue;
    if (s.attrNum(EquipmentAttrKeys.cellSlot)?.round() != slot) continue;
    final start = s.parentDivesFrom;
    if (start == null || !start.isAfter(from)) continue;
    if (earliest == null || start.isBefore(earliest)) earliest = start;
  }
  return earliest;
}

/// Totals per unit for the exposure card. [EquipmentExposureTotals.empty]
/// for an unknown item or one with no dives.
final equipmentExposureTotalsProvider =
    FutureProvider.family<EquipmentExposureTotals, String>((
      ref,
      equipmentId,
    ) async {
      final inputs = await ref.watch(
        equipmentExposureInputsProvider(equipmentId).future,
      );
      if (inputs == null || inputs.samples.isEmpty) {
        return EquipmentExposureTotals.empty;
      }
      final byUnit = <ExposureUnit, double>{};
      for (final unit in ExposureUnit.values) {
        if (unit == ExposureUnit.days) continue;
        var total = 0.0;
        for (final sample in inputs.samples) {
          total += inputs.classifier.contribution(sample, unit);
        }
        if (total > 0) byUnit[unit] = total;
      }
      DateTime? first;
      DateTime? last;
      for (final sample in inputs.samples) {
        if (first == null || sample.date.isBefore(first)) first = sample.date;
        if (last == null || sample.date.isAfter(last)) last = sample.date;
      }
      return EquipmentExposureTotals(
        byUnit: byUnit,
        diveCount: inputs.samples.length,
        firstDive: first,
        lastDive: last,
      );
    });
