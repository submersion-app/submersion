import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

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
      // A transmitter's dives include the tanks that carried its registered
      // serials, and assigning a serial writes only the registry.
      if (item.type == EquipmentType.transmitter) {
        ref.invalidateSelfWhen(
          ref.watch(transmitterRepositoryProvider).watchTransmittersChanges(),
        );
      }
      // The repository's one wiring: the clocks, the reminders and the
      // condition engine read the same parent dives, install dates,
      // fitted parts and successor cutoff.
      final exposure = await repository.getItemExposure(item);
      final children = exposure.fittedChildren;
      final samples = exposure.samples;
      final classifier = ExposureClassifier(
        thresholds: ref.watch(exposureThresholdsProvider),
        loopTimeOnly: exposure.isRebreather,
        hasBatteryChild: children.any((c) => c.type == EquipmentType.battery),
      );
      return (
        item: item,
        parent: exposure.parent,
        children: children,
        samples: samples,
        classifier: classifier,
      );
    });

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
