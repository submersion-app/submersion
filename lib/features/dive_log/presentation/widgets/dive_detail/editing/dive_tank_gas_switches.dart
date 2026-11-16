import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/detected_gas_switch_edits.dart';
import 'package:submersion/features/dive_log/presentation/providers/cylinder_breath_starts_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/detected_gas_switches_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switch_time_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The gas switch list on the open Tanks card (issue #32, #4527): the dive
/// form's [GasSwitchesEditor], over the switches the sitting holds.
///
/// Draws nothing until the switches are loaded, or while they are hidden
/// (one breathing cylinder, gauge, a planned dive).
class DiveTankGasSwitches extends ConsumerWidget {
  const DiveTankGasSwitches({
    super.key,
    required this.session,
    required this.units,
  });

  final EditSession<Dive> session;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = sittingGasSwitches(session);
    if (held == null || !gasSwitchesShown(session)) {
      return const SizedBox.shrink();
    }
    final dive = session.working;
    final diveId = session.stored.id;
    final profile = session.stored.profile;
    final limits = gasSwitchTimeLimits(session);
    final detected = _detectedEdits(ref, held.current);
    return GasSwitchesEditor(
      switches: held.current,
      tanks: dive.tanks,
      units: units,
      maxTimestamp: limits.max,
      minTimestamp: limits.min,
      startingTank: gasSwitchStartingTank(session),
      removedWithTankCount: held.removedWithTank,
      invalidAsStoredIds: gasSwitchesInvalidAsStored(session),
      onChanged: (updated, field) => changeGasSwitch(session, updated, field),
      onRemove: (id) => removeGasSwitch(session, id),
      onAdd: () => addGasSwitch(session),
      onTimeSettled: (id) => gasSwitchTimeSettled(session, id),
      // .value keeps the last result through a reload, so the chips stay
      // put while a pressure write is read back. A held reassign has moved
      // the readings, so the chips go with them.
      breathStarts:
          tankReadingsInSitting(
            session,
            ref.watch(cylinderBreathStartsProvider(diveId)).value,
          ) ??
          const {},
      onPickTime: canPickOnProfile(profile)
          ? (sw) => _pickTime(context, ref, sw)
          : null,
      detectedEditCount: detected == null ? 0 : gasSwitchEditCount(detected),
      onFillDetected: detected == null
          ? null
          : () => fillDetectedGasSwitches(session, detected),
    );
  }

  /// What the editor changes to match the cylinder pressures (#4335), on
  /// open circuit only, as the form offers it. Not while a reassign is held:
  /// the switches are found from the readings with the gas of the cylinder
  /// they are stored on, which is not the one holding them until Save.
  GasSwitchEdits? _detectedEdits(WidgetRef ref, List<GasSwitch> switches) {
    final dive = session.working;
    if (dive.diveMode != DiveMode.oc) return null;
    if (heldTankSeriesExchanges(session).isNotEmpty) return null;
    final found = ref
        .watch(detectedGasSwitchesProvider(session.stored.id))
        .value;
    if (found == null) return null;
    final profile = session.stored.profile;
    final firstSample = profile.isEmpty
        ? 0
        : profile.map((p) => p.timestamp).reduce((a, b) => a < b ? a : b);
    return detectedGasSwitchEdits(
      switches: switches,
      tanks: dive.tanks,
      detected: found,
      diveStart: firstSample > 0 ? firstSample : 0,
    );
  }

  /// Picks [sw]'s time on the profile: the same edit as a typed time
  /// followed by leaving the field (`_pickGasSwitchTime`).
  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    GasSwitch sw,
  ) async {
    final diveId = session.stored.id;
    final recorded = await ref
        .read(tankPressuresProvider(diveId).future)
        .then<Map<String, List<TankPressurePoint>>?>(
          (value) => value,
          onError: (Object _) => null,
        );
    if (!context.mounted || session.isDisposed || session.isFrozen) return;
    // Where a held reassign has moved them.
    final held = tankReadingsInSitting(session, recorded);
    final tanks = session.working.tanks;
    final others = sittingGasSwitches(session)?.current ?? const [];
    final seconds = await showGasSwitchTimeSheet(
      context,
      profile: session.stored.profile,
      initialSeconds: sw.timestamp,
      units: units,
      tanks: tanks,
      tankId: sw.tankId,
      tankPressures: {for (final tank in tanks) tank.id: ?held?[tank.id]},
      gasSwitches: [
        for (final other in others)
          if (other.id != sw.id)
            if (tanks.where((t) => t.id == other.tankId).firstOrNull
                case final tank?)
              GasSwitchWithTank(
                gasSwitch: other,
                tankName: tank.name ?? '',
                gasMix: tank.gasMix.name,
                o2Fraction: tank.gasMix.o2 / 100,
                heFraction: tank.gasMix.he / 100,
              ),
      ],
    );
    if (seconds == null || seconds == sw.timestamp) return;
    if (session.isDisposed || session.isFrozen) return;
    changeGasSwitch(
      session,
      sw.copyWith(timestamp: seconds),
      GasSwitchField.time,
    );
    gasSwitchTimeSettled(session, sw.id);
  }
}
