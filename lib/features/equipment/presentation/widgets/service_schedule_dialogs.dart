import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Invalidate every provider that reflects clock state for [equipmentId].
void invalidateServiceClockProviders(WidgetRef ref, String equipmentId) {
  ref.invalidate(serviceClockStatusesProvider(equipmentId));
  ref.invalidate(serviceSchedulesForEquipmentProvider(equipmentId));
  // dueClocks/worstClock (badges, dashboard, trip) and serviceUrgency (Service
  // Due sort + table forecast columns) all derive from this single per-item
  // evaluation, so invalidating it refreshes them all with one re-eval.
  // Schedule writes touch only service_schedules, so its
  // invalidateSelfWhen(watchEquipmentChanges) never fires for them -- it must
  // be invalidated explicitly here.
  ref.invalidate(activeEquipmentClocksProvider);
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
                    final created = await ref
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
                    // A kind with no default interval yields an invisible
                    // clock until an interval is set, so configure it now.
                    final needsInterval =
                        kind.defaultIntervalDays == null &&
                        kind.defaultIntervalDives == null &&
                        kind.defaultIntervalHours == null;
                    if (needsInterval && context.mounted) {
                      await showScheduleOverrideDialog(
                        context,
                        ref,
                        schedule: created,
                        kind: kind,
                      );
                    }
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

/// Edits one schedule's interval overrides and baseline date. Accepts the
/// schedule and its kind directly so it serves brand-new and unconfigured
/// clocks as well as existing ones.
Future<void> showScheduleOverrideDialog(
  BuildContext context,
  WidgetRef ref, {
  required ServiceSchedule schedule,
  required ServiceKind kind,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) =>
        _ScheduleOverrideDialog(schedule: schedule, kind: kind, ref: ref),
  );
}

class _ScheduleOverrideDialog extends StatefulWidget {
  final ServiceSchedule schedule;
  final ServiceKind kind;
  final WidgetRef ref;

  const _ScheduleOverrideDialog({
    required this.schedule,
    required this.kind,
    required this.ref,
  });

  @override
  State<_ScheduleOverrideDialog> createState() =>
      _ScheduleOverrideDialogState();
}

class _ScheduleOverrideDialogState extends State<_ScheduleOverrideDialog> {
  late final TextEditingController _days;
  late final TextEditingController _dives;
  late final TextEditingController _hours;
  late final TextEditingController _defaultCost;

  /// Null means "inherit": the kind's currency, else the diver's default.
  String? _defaultCurrency;

  /// The interval fields are plain TextFields with no validation, but a
  /// negative price would prefill the record dialog and immediately fail
  /// validation there, so the cost field gets a real Form to validate in.
  final _formKey = GlobalKey<FormState>();

  DateTime? _anchorDate;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _days = TextEditingController(text: s.intervalDays?.toString() ?? '');
    _dives = TextEditingController(text: s.intervalDives?.toString() ?? '');
    // Fractional, so the seed uses the diver's decimal separator to match how
    // the field is read back (#1091).
    final hours = s.intervalHours;
    _hours = TextEditingController(
      text: hours == null ? '' : formatDecimalForInput(hours),
    );
    // Same decimal-separator pairing as the hours field above (#1091).
    final cost = s.defaultCost;
    _defaultCost = TextEditingController(
      text: cost == null ? '' : formatDecimalForInput(cost),
    );
    _defaultCurrency = s.defaultCurrency;
    _anchorDate = s.anchorDate;
  }

  @override
  void dispose() {
    _days.dispose();
    _dives.dispose();
    _hours.dispose();
    _defaultCost.dispose();
    super.dispose();
  }

  String _hint(num? kindDefault) => kindDefault == null ? '' : '$kindDefault';

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final l10n = context.l10n;
    return AlertDialog(
      title: Text('${l10n.equipment_scheduleDialog_title}: ${kind.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
              // Per-item price override. Blank inherits the kind's value, shown
              // as the hint, exactly like the interval fields above (#829).
              TextFormField(
                key: const Key('service-schedule-default-cost'),
                controller: _defaultCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.equipment_scheduleDialog_defaultCostLabel,
                  hintText: kind.defaultCost == null
                      ? l10n.equipment_serviceKinds_defaultCostHint
                      : l10n.equipment_scheduleDialog_inheritHint(
                          formatDecimalForInput(kind.defaultCost!),
                        ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final parsed = parseUserDecimal(value);
                  if (parsed == null || parsed < 0) {
                    return l10n.equipment_serviceDialog_costValidation;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // The currency this item's price is in. Null inherits the kind's,
              // then the diver's default, matching how the cost resolves.
              DropdownButtonFormField<String?>(
                key: const Key('service-schedule-default-currency'),
                initialValue: _defaultCurrency,
                decoration: InputDecoration(
                  labelText: l10n.equipment_scheduleDialog_defaultCurrencyLabel,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      l10n.equipment_serviceKinds_defaultCurrencyInherit,
                    ),
                  ),
                  for (final code in currencyCodesWith(_defaultCurrency))
                    DropdownMenuItem<String?>(value: code, child: Text(code)),
                ],
                onChanged: (value) => setState(() => _defaultCurrency = value),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: l10n.equipment_scheduleDialog_anchorDate,
                child: InkWell(
                  onTap: () async {
                    final picked = await showAppDatePicker(
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
                              tooltip:
                                  l10n.equipment_scheduleDialog_clearAnchor,
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _anchorDate = null),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.equipment_scheduleDialog_cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? true)) return;
            final schedule = widget.schedule;
            // copyWith cannot null a field; build the updated entity directly.
            final updated = ServiceSchedule(
              id: schedule.id,
              equipmentId: schedule.equipmentId,
              serviceKindId: schedule.serviceKindId,
              intervalDays: parseUserInt(_days.text),
              intervalDives: parseUserInt(_dives.text),
              intervalHours: parseUserDecimal(_hours.text),
              defaultCost: parseUserDecimal(_defaultCost.text),
              defaultCurrency: _defaultCurrency,
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
