import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Invalidate every provider that reflects clock state for [equipmentId].
void invalidateServiceClockProviders(WidgetRef ref, String equipmentId) {
  ref.invalidate(serviceClockStatusesProvider(equipmentId));
  ref.invalidate(serviceSchedulesForEquipmentProvider(equipmentId));
  ref.invalidate(dueClocksProvider);
  ref.invalidate(equipmentWorstClockProvider);
}

/// Bottom sheet listing service kinds that apply to [equipmentType] and are
/// not yet attached; tapping one creates an enabled schedule with no
/// overrides (kind defaults apply).
Future<void> showServiceKindPicker(
  BuildContext context,
  WidgetRef ref, {
  required String equipmentId,
  required EquipmentType equipmentType,
}) async {
  final kinds = await ref.read(serviceKindsProvider.future);
  final existing = await ref.read(
    serviceSchedulesForEquipmentProvider(equipmentId).future,
  );
  final attached = existing.map((s) => s.serviceKindId).toSet();
  final candidates = kinds
      .where((k) => k.appliesTo(equipmentType) && !attached.contains(k.id))
      .toList();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in candidates)
              Semantics(
                button: true,
                label: kind.name,
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(kind.name),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final now = DateTime.now();
                    await ref
                        .read(serviceScheduleRepositoryProvider)
                        .createSchedule(
                          ServiceSchedule(
                            id: '',
                            equipmentId: equipmentId,
                            serviceKindId: kind.id,
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                    invalidateServiceClockProviders(ref, equipmentId);
                  },
                ),
              ),
            const Divider(height: 1),
            Semantics(
              button: true,
              label: sheetContext.l10n.equipment_serviceClocks_manageKinds,
              child: ListTile(
                leading: const Icon(Icons.settings),
                title: Text(
                  sheetContext.l10n.equipment_serviceClocks_manageKinds,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/equipment/service-types');
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Edits one schedule's interval overrides and baseline date.
Future<void> showScheduleOverrideDialog(
  BuildContext context,
  WidgetRef ref, {
  required ServiceClockStatus status,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _ScheduleOverrideDialog(status: status, ref: ref),
  );
}

class _ScheduleOverrideDialog extends StatefulWidget {
  final ServiceClockStatus status;
  final WidgetRef ref;

  const _ScheduleOverrideDialog({required this.status, required this.ref});

  @override
  State<_ScheduleOverrideDialog> createState() =>
      _ScheduleOverrideDialogState();
}

class _ScheduleOverrideDialogState extends State<_ScheduleOverrideDialog> {
  late final TextEditingController _days;
  late final TextEditingController _dives;
  late final TextEditingController _hours;
  DateTime? _anchorDate;

  @override
  void initState() {
    super.initState();
    final s = widget.status.schedule;
    _days = TextEditingController(text: s.intervalDays?.toString() ?? '');
    _dives = TextEditingController(text: s.intervalDives?.toString() ?? '');
    _hours = TextEditingController(text: s.intervalHours?.toString() ?? '');
    _anchorDate = s.anchorDate;
  }

  @override
  void dispose() {
    _days.dispose();
    _dives.dispose();
    _hours.dispose();
    super.dispose();
  }

  String _hint(num? kindDefault) => kindDefault == null ? '' : '$kindDefault';

  @override
  Widget build(BuildContext context) {
    final kind = widget.status.kind;
    final l10n = context.l10n;
    return AlertDialog(
      title: Text('${l10n.equipment_scheduleDialog_title}: ${kind.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.equipment_scheduleDialog_intervalDays,
                hintText: kind.defaultIntervalDays == null
                    ? null
                    : l10n.equipment_scheduleDialog_inheritHint(
                        _hint(kind.defaultIntervalDays),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dives,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.equipment_scheduleDialog_intervalDives,
                hintText: kind.defaultIntervalDives == null
                    ? null
                    : l10n.equipment_scheduleDialog_inheritHint(
                        _hint(kind.defaultIntervalDives),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.equipment_scheduleDialog_intervalHours,
                hintText: kind.defaultIntervalHours == null
                    ? null
                    : l10n.equipment_scheduleDialog_inheritHint(
                        _hint(kind.defaultIntervalHours),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: l10n.equipment_scheduleDialog_anchorDate,
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _anchorDate ?? DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _anchorDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.equipment_scheduleDialog_anchorDate,
                    helperText: l10n.equipment_scheduleDialog_anchorHint,
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _anchorDate == null
                        ? null
                        : IconButton(
                            tooltip: l10n.equipment_scheduleDialog_clearAnchor,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _anchorDate = null),
                          ),
                  ),
                  child: Text(
                    _anchorDate == null
                        ? '-'
                        : MaterialLocalizations.of(
                            context,
                          ).formatShortDate(_anchorDate!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.equipment_scheduleDialog_cancel),
        ),
        FilledButton(
          onPressed: () async {
            final schedule = widget.status.schedule;
            // copyWith cannot null a field; build the updated entity directly.
            final updated = ServiceSchedule(
              id: schedule.id,
              equipmentId: schedule.equipmentId,
              serviceKindId: schedule.serviceKindId,
              intervalDays: int.tryParse(_days.text.trim()),
              intervalDives: int.tryParse(_dives.text.trim()),
              intervalHours: double.tryParse(_hours.text.trim()),
              anchorDate: _anchorDate,
              enabled: schedule.enabled,
              createdAt: schedule.createdAt,
              updatedAt: schedule.updatedAt,
            );
            await widget.ref
                .read(serviceScheduleRepositoryProvider)
                .updateSchedule(updated);
            invalidateServiceClockProviders(widget.ref, schedule.equipmentId);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.equipment_scheduleDialog_save),
        ),
      ],
    );
  }
}
