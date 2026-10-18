import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/presentation/widgets/use_as_bailout_dialog.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Runs a repair and reports it with an undo; [note] adds to the message.
typedef RepairRunner =
    Future<void> Function(
      Future<RepairResult> Function() run, {
      String? Function()? note,
    });

/// The inbox's "Use as bailout" (issue #3307): confirm, apply, report.
///
/// The confirmation shows the tank by the number the dive page gives it,
/// and the report says when the transmitter was registered and how many
/// other dives kept their mix.
Future<void> runUseAsBailoutRepair(
  BuildContext context, {
  required QualityFinding finding,
  required UseAsBailoutRepair action,
  required QualityRepairExecutor executor,
  required RepairRunner withUndo,
  DiveRepository? diveRepository,
  Future<bool> Function(String diveId, String tankId)? hasPressureSeries,
}) async {
  final dive = await (diveRepository ?? DiveRepository()).getDiveById(
    action.diveId,
  );
  if (dive == null || !context.mounted) return;
  final tanks = [...dive.tanks]..sort((a, b) => a.order.compareTo(b.order));
  final index = tanks.indexWhere((t) => t.id == action.tankId);
  if (index < 0) return;
  final tank = tanks[index];
  final ocHasSeries =
      await (hasPressureSeries ?? TankPressureRepository().hasTankSeries)(
        action.diveId,
        action.ocTankId,
      );
  if (!context.mounted) return;
  final choice = await showUseAsBailoutDialog(
    context,
    tank: tank,
    tankNumber: index + 1,
    ocTank: tanks.where((t) => t.id == action.ocTankId).firstOrNull,
    ocHasPressureSeries: ocHasSeries,
  );
  if (choice == null || !context.mounted) return;

  final l10n = context.l10n;
  var mixesKept = 0;
  var registered = false;
  TankRole? role;
  await withUndo(
    () async {
      final outcome = await executor.useAsBailout(
        diveId: action.diveId,
        tankId: action.tankId,
        ocTankId: action.ocTankId,
        findingId: finding.id,
        registerTransmitter: choice.register,
        serial: tank.transmitterSerial,
        label: tank.name,
        diverId: dive.diverId,
      );
      mixesKept = outcome.mixesKept;
      registered = outcome.registered;
      role = outcome.role;
      return outcome.result;
    },
    note: () => registered
        ? [
            l10n.dataQuality_useAsBailout_registered(
              (role ?? TankRole.bailout).localizedName(l10n),
            ),
            if (mixesKept > 0)
              l10n.dataQuality_useAsBailout_mixesKept(mixesKept),
          ].join(' ')
        : null,
  );
}
