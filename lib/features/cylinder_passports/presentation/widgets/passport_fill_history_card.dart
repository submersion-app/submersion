import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/data/services/twin_fill_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/tied_fill_dialogs.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every fill, newest first, with the count since the last hydro
/// (spec section 8, Fill history card).
class PassportFillHistoryCard extends ConsumerWidget {
  const PassportFillHistoryCard({super.key, required this.equipmentId});

  final String equipmentId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CylinderFill fill,
  ) async {
    final l10n = context.l10n;
    // One fill of a twin set fill (issue #4242): ask whether its other fill
    // goes too, unless that row is already gone.
    final tied = await ref
        .read(cylinderFillRepositoryProvider)
        .tiedFillOf(fill);
    if (!context.mounted) return;
    if (tied != null) {
      final both = await askDeleteTiedFill(context);
      if (both == null) return;
      await ref.read(twinFillServiceProvider).delete(fill, tiedToo: both);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.passport_history_delete),
        content: Text(l10n.passport_history_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.forms_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.passport_history_delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(cylinderFillRepositoryProvider).delete(fill.id);
    }
  }

  /// "Filled with `partner`" for one fill of a twin set fill, or null.
  String? _filledWith(BuildContext context, WidgetRef ref, CylinderFill fill) {
    if (fill.filledTogetherId == null) return null;
    final tied = ref
        .watch(tiedFillProvider((id: fill.id, together: fill.filledTogetherId)))
        .value;
    if (tied == null) return null;
    final partnerId = tied.equipmentId;
    final name = partnerId == null
        ? null
        : ref.watch(equipmentItemProvider(partnerId)).value?.name;
    return context.l10n.passport_history_filledWith(
      name ?? context.l10n.passport_history_anotherCylinder,
    );
  }

  Future<void> _edit(BuildContext context, CylinderFill fill) =>
      showLogFillSheet(
        context,
        passportId: fill.passportId,
        equipmentId: equipmentId,
        editing: fill,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final fills =
        ref.watch(fillsForEquipmentProvider(equipmentId)).value ??
        const <CylinderFill>[];
    final clocks = ref.watch(serviceClockStatusesProvider(equipmentId)).value;
    final records =
        ref.watch(serviceRecordsForEquipmentProvider(equipmentId)).value ??
        const <ServiceRecord>[];
    // Counted only from a hydro that really happened; with none on record
    // the count would be meaningless and is not shown.
    final hydroDone = recordedServiceDate(
      clock: clocks?.where((c) => c.kind.id == 'hydro').firstOrNull,
      records: records,
    );
    final sinceHydro = hydroDone == null
        ? null
        : fills.where((f) => !f.filledAt.isBefore(hydroDone)).length;
    final tripCopies =
        ref.watch(tripCopyFillIdsProvider(equipmentId)).value ??
        const <String>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.passport_history_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (sinceHydro != null)
              Text(l10n.passport_history_sinceHydro(sinceHydro)),
            const SizedBox(height: 8),
            for (final fill in fills)
              ListTile(
                contentPadding: EdgeInsets.zero,
                // A fill the diver typed in opens for editing (issue #4242).
                onTap: isEditableFill(fill, tripCopyIds: tripCopies)
                    ? () => _edit(context, fill)
                    : null,
                title: Text(fill.gasMix.name),
                subtitle: Text(
                  [
                    units.formatDate(fill.filledAt),
                    if (fill.pressureBar != null)
                      units.formatPressure(fill.pressureBar),
                    if (fill.stationName != null) fill.stationName!,
                    ?_filledWith(context, ref, fill),
                  ].join(', '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FillSourceBadge(fill: fill),
                    if (isEditableFill(fill, tripCopyIds: tripCopies))
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.passport_history_edit,
                        onPressed: () => _edit(context, fill),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.passport_history_delete,
                      onPressed: () => _confirmDelete(context, ref, fill),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
