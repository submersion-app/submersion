import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_list_pending.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The Service clocks card's editor on an unlocked gear item page (issue
/// #4527, phase 3, plan 6): the clocks as the sitting holds them, each
/// added, changed, paused, resumed or removed there; a service logged from
/// one, held as a service record; and the item's own reminder days. The
/// due rows stay as stored until Save: a clock the sitting changed shows
/// the changed dot instead.
class GearItemClocksEditor extends ConsumerStatefulWidget {
  const GearItemClocksEditor({super.key, required this.session});

  final EditSession<EquipmentItem> session;

  @override
  ConsumerState<GearItemClocksEditor> createState() =>
      _GearItemClocksEditorState();
}

class _GearItemClocksEditorState extends ConsumerState<GearItemClocksEditor> {
  EditSession<EquipmentItem> get _session => widget.session;

  @override
  void initState() {
    super.initState();
    // Read now, unless the page already has.
    if (gearItemClocksList.loaded(_session) == null) {
      gearItemClocksList.load(_session);
    }
    if (gearItemServiceRecordsList.loaded(_session) == null) {
      gearItemServiceRecordsList.load(_session);
    }
  }

  Future<void> _addClock(List<ServiceSchedule> clocks) => showServiceKindPicker(
    context,
    ref,
    equipmentId: _session.stored.id,
    equipmentType: _session.working.type,
    attachedKindIds: {for (final s in clocks) s.serviceKindId},
    onHold: (schedule) => holdClock(_session, schedule),
    records: gearItemServiceRecordsList.current(_session),
  );

  Future<void> _onAction(
    String action,
    ServiceSchedule schedule,
    ServiceKind? kind,
  ) async {
    switch (action) {
      case 'log':
        await showLogServiceDialog(
          context,
          ref,
          equipmentId: _session.stored.id,
          serviceKindId: schedule.serviceKindId,
          onHold: (record) => holdServiceRecord(_session, record),
        );
      case 'edit':
        if (kind == null) return;
        await showScheduleOverrideDialog(
          context,
          ref,
          schedule: schedule,
          kind: kind,
          onHold: (next) => holdClock(_session, next),
          records: gearItemServiceRecordsList.current(_session),
        );
      case 'pause':
        holdClock(_session, schedule.copyWith(enabled: false));
      case 'resume':
        holdClock(_session, schedule.copyWith(enabled: true));
      case 'remove':
        removeHeldClock(_session, schedule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final statuses = {
      for (final status
          in ref
                  .watch(serviceClockStatusesProvider(_session.stored.id))
                  .value ??
              const <ServiceClockStatus>[])
        status.schedule.id: status,
    };
    final kindsById = {
      ...?ref.watch(allServiceKindsByIdProvider).value,
      for (final k in ref.watch(serviceKindsProvider).value ?? <ServiceKind>[])
        k.id: k,
    };
    return ListenableBuilder(
      listenable: Listenable.merge([
        _session,
        gearItemClocksList.changes(_session),
        gearItemServiceRecordsList.changes(_session),
      ]),
      builder: (context, _) {
        final clocks = gearItemClocksList.current(_session);
        // A service logged from a clock is held among the service records,
        // so it waits for them as well.
        final canLog = gearItemServiceRecordsList.current(_session) != null;
        final loaded = {
          for (final s
              in gearItemClocksList.loaded(_session) ??
                  const <ServiceSchedule>[])
            s.id: s,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const ValueKey('gear-clocks-add'),
                onPressed: clocks == null ? null : () => _addClock(clocks),
                icon: const Icon(Icons.add),
                label: Text(l10n.equipment_serviceClocks_addClock),
              ),
            ),
            ?gearItemListPending(gearItemClocksList, _session) ??
                gearItemListPending(gearItemServiceRecordsList, _session),
            if (clocks != null && clocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.equipment_serviceClocks_empty),
              ),
            if (clocks != null)
              for (final schedule in clocks)
                _ClockRow(
                  schedule: schedule,
                  kind: kindsById[schedule.serviceKindId],
                  // The stored row's verdict, while the sitting has not
                  // changed the clock.
                  status: loaded[schedule.id] == schedule
                      ? statuses[schedule.id]
                      : null,
                  changed: loaded[schedule.id] != schedule,
                  canLog: canLog,
                  units: units,
                  onAction: (action) => _onAction(
                    action,
                    schedule,
                    kindsById[schedule.serviceKindId],
                  ),
                ),
            const Divider(height: 24),
            _CustomReminderEditor(session: _session),
          ],
        );
      },
    );
  }
}

class _ClockRow extends StatelessWidget {
  const _ClockRow({
    required this.schedule,
    required this.kind,
    required this.status,
    required this.changed,
    required this.canLog,
    required this.units,
    required this.onAction,
  });

  final ServiceSchedule schedule;
  final ServiceKind? kind;
  final ServiceClockStatus? status;
  final bool changed;

  /// Whether Log service may be chosen: the sitting has read the service
  /// records the logged one is held among.
  final bool canLog;
  final UnitFormatter units;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = this.status;
    return ListTile(
      key: ValueKey('gear-clock-${schedule.id}'),
      contentPadding: EdgeInsets.zero,
      leading: !schedule.enabled
          ? Icon(
              Icons.pause_circle_outline,
              size: 18,
              color: Theme.of(context).colorScheme.outline,
            )
          : Icon(
              Icons.circle,
              size: 14,
              color: status == null
                  ? Theme.of(context).colorScheme.outline
                  : serviceSeverityDotColor(context, status.severity),
            ),
      title: Row(
        children: [
          Flexible(child: Text(kind?.name ?? schedule.serviceKindId)),
          if (changed) ...[const SizedBox(width: 6), const RecordChangedDot()],
        ],
      ),
      subtitle: !schedule.enabled
          ? Text(l10n.equipment_serviceClocks_paused)
          : status == null
          ? null
          : Text(
              formatServiceTriggerLines(
                context,
                units: units,
                now: status.now,
                dueDate: status.dueDate,
                usageByUnit: status.usageByUnit,
              ).join('\n'),
            ),
      trailing: PopupMenuButton<String>(
        key: ValueKey('gear-clock-menu-${schedule.id}'),
        onSelected: onAction,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'log',
            enabled: canLog,
            child: Text(l10n.equipment_serviceClocks_logService),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Text(l10n.equipment_serviceClocks_edit),
          ),
          PopupMenuItem(
            value: schedule.enabled ? 'pause' : 'resume',
            child: Text(
              schedule.enabled
                  ? l10n.equipment_serviceClocks_pause
                  : l10n.equipment_serviceClocks_resume,
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            child: Text(l10n.equipment_serviceClocks_remove),
          ),
        ],
      ),
    );
  }
}

/// The item's own reminder days, or none, over the diver's settings, as the
/// form edited them (#2025: owned gear only, which is all that shows clocks).
class _CustomReminderEditor extends StatelessWidget {
  const _CustomReminderEditor({required this.session});

  final EditSession<EquipmentItem> session;

  static const _defaultDays = [7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reminder = session.valueOf(gearCustomReminderField);
    final days = reminder.days ?? _defaultDays;
    void set(bool? enabled, List<int>? next) => session.set(
      gearCustomReminderField,
      (enabled: enabled, days: enabled == true ? (next ?? days) : null),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('gear-reminders-custom'),
          title: Text(l10n.equipment_edit_useCustomReminders),
          subtitle: Text(l10n.equipment_edit_useCustomRemindersSubtitle),
          value: reminder.enabled == true,
          onChanged: (on) => set(on ? true : null, null),
          contentPadding: EdgeInsets.zero,
        ),
        if (reminder.enabled == true) ...[
          Text(
            l10n.equipment_edit_remindMeBeforeServiceDue,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final d in _defaultDays)
                FilterChip(
                  key: ValueKey('gear-reminders-day-$d'),
                  label: Text(l10n.equipment_edit_reminderDays(d)),
                  selected: days.contains(d),
                  onSelected: (_) =>
                      set(true, gearReminderDaysToggled(days, d)),
                ),
            ],
          ),
        ],
        SwitchListTile(
          key: const ValueKey('gear-reminders-off'),
          title: Text(l10n.equipment_edit_disableReminders),
          subtitle: Text(l10n.equipment_edit_disableRemindersSubtitle),
          value: reminder.enabled == false,
          onChanged: (off) => set(off ? false : null, null),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// The row a set custom reminder gets on the closed Service clocks card,
/// or null when the item follows the diver's settings: the value is edited
/// on the card, so it is shown there ("Values shown nowhere today").
String? gearCustomReminderText(
  BuildContext context,
  ({bool? enabled, List<int>? days}) reminder,
) {
  final l10n = context.l10n;
  return switch (reminder.enabled) {
    null => null,
    false => l10n.equipment_serviceClocks_remindersOff,
    true => l10n.equipment_serviceClocks_remindersOwn(
      [
        for (final d in [...?reminder.days]..sort())
          l10n.equipment_edit_reminderDays(d),
      ].join(', '),
    ),
  };
}
