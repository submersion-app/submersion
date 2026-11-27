import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/service_clock_snapshot_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The three cylinder clocks the passport cares about, in this order.
const List<String> kPassportServiceKinds = ['hydro', 'vip', 'o2-clean'];

/// Hydro, VIP and O2 clean read from the service clocks, never from the
/// catalog date attributes, so the passport cannot contradict the reminders
/// (spec section 8, Service card).
class PassportServiceCard extends ConsumerWidget {
  const PassportServiceCard({super.key, required this.equipment, this.editing});

  final EquipmentItem equipment;

  /// The open card's sitting (issue #4527, phase 3): Track O2 clean holds the
  /// clock in the item's service clocks until Save. With no sitting given,
  /// nothing is offered. While the sitting holds clock or service record
  /// changes, the rows show them evaluated over the item's usage, as the
  /// Service clocks card does (issue #5042).
  final EditSession<EquipmentItem>? editing;

  /// The built-in O2 clean clock for this item.
  ServiceSchedule _o2Clock() {
    final now = DateTime.now();
    return ServiceSchedule(
      id: 'auto-o2-clean-${equipment.id}',
      equipmentId: equipment.id,
      serviceKindId: 'o2-clean',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Whether the sitting tracks O2 clean.
  static bool _heldO2(EditSession<EquipmentItem>? session) =>
      session != null &&
      (gearItemClocksList.current(session) ?? const []).any(
        (s) => s.serviceKindId == 'o2-clean',
      );

  /// Attaches the built-in O2 clean schedule once. The id is derived from
  /// the item, as auto-attach does, so a second tap (or a peer doing the
  /// same) collides with the first instead of adding a duplicate clock.
  Future<void> _trackO2Clean(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedText = context.l10n.passport_service_trackFailed;
    final repository = ref.read(serviceScheduleRepositoryProvider);
    try {
      final existing = await repository.getSchedulesForEquipment(equipment.id);
      if (existing.any((s) => s.serviceKindId == 'o2-clean')) return;
      try {
        await repository.createSchedule(_o2Clock());
      } catch (_) {
        // Only the other tap winning the race is harmless; anything else is
        // a real failure.
        final attached = await repository.getSchedulesForEquipment(
          equipment.id,
        );
        if (!attached.any((s) => s.serviceKindId == 'o2-clean')) rethrow;
      }
      invalidateServiceClockProviders(ref, equipment.id);
    } catch (_) {
      // The button's Future is not awaited by anyone; a failure must reach
      // the diver here or not at all.
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = RecordEditScope.maybeOf<EquipmentItem>(context);
    final session = editing ?? scope?.session;
    final mayAct = scope == null || editing != null;
    if (session == null) return _build(context, ref, null, mayAct);
    return ListenableBuilder(
      listenable: Listenable.merge([
        gearItemClocksList.changes(session),
        gearItemServiceRecordsList.changes(session),
      ]),
      builder: (context, _) => _build(context, ref, session, mayAct),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? session,
    bool mayAct,
  ) {
    final l10n = context.l10n;
    final editing = this.editing;
    final canAct =
        mayAct &&
        (editing == null || gearItemClocksList.current(editing) != null);
    final heldO2 = _heldO2(session);
    final units = ref.watch(unitFormatterProvider);
    final heldClocks = session != null && gearItemClocksList.isChanged(session)
        ? gearItemClocksList.current(session)
        : null;
    final heldRecords =
        session != null && gearItemServiceRecordsList.isChanged(session)
        ? gearItemServiceRecordsList.current(session)
        : null;
    // The clocks the sitting changed, which carry the changed dot.
    final loaded = {
      for (final s
          in session == null
              ? const <ServiceSchedule>[]
              : gearItemClocksList.loaded(session) ?? const [])
        s.id: s,
    };
    final changedKinds = {
      for (final s in heldClocks ?? const <ServiceSchedule>[])
        if (loaded[s.id] != s) s.serviceKindId,
    };
    // The held clocks and records evaluated over the item's usage, from the
    // one read the verdicts and the records both come from (issue #5042).
    final snapshot = heldClocks == null && heldRecords == null
        ? null
        : ref.watch(serviceClockSnapshotProvider(equipment.id)).value;
    final held = snapshot?.statusesFor(
      schedules: heldClocks,
      records: heldRecords,
    );
    final stored =
        ref.watch(serviceClockStatusesProvider(equipment.id)).value ??
        const <ServiceClockStatus>[];
    // Until that read lands, only the stored clocks the sitting kept as they
    // were: a removed clock does not come back, and a changed one waits for
    // its verdict rather than showing the old one.
    final kept = {
      for (final s in heldClocks ?? const <ServiceSchedule>[])
        if (loaded[s.id] == s) s.id,
    };
    final clocks =
        held ??
        (heldClocks == null
            ? stored
            : [
                for (final c in stored)
                  if (kept.contains(c.schedule.id)) c,
              ]);
    final byKind = {for (final c in clocks) c.kind.id: c};
    final records = snapshot != null
        ? (heldRecords ?? snapshot.records)
        : ref.watch(serviceRecordsForEquipmentProvider(equipment.id)).value ??
              const <ServiceRecord>[];
    // The untracked row names the built-in kind the way the rest of the app
    // does, falling back to its id before the kind list has loaded.
    final kindNames = {
      for (final k in ref.watch(serviceKindsProvider).value ?? const [])
        k.id: k.name,
    };
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.passport_service_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // On the passport this is the item's Service clocks card.
                RecordCardPencil(
                  cardTitle: GearItemCardId.serviceClocks.localizedDisplayName(
                    l10n,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final kindId in kPassportServiceKinds)
              if (byKind[kindId] case final status?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: changedKinds.contains(kindId)
                      ? Row(
                          children: [
                            Flexible(child: Text(status.kind.name)),
                            const SizedBox(width: 6),
                            const RecordChangedDot(),
                          ],
                        )
                      : Text(status.kind.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(switch (recordedServiceDate(
                        clock: status,
                        records: records,
                      )) {
                        final done? => l10n.passport_service_lastDone(
                          units.formatDate(done),
                        ),
                        null => l10n.passport_service_neverRecorded,
                      }),
                      Text(
                        formatServiceTriggerText(
                          context,
                          units: units,
                          now: now,
                          dueDate: status.dueDate,
                          usageByUnit: status.usageByUnit,
                        ),
                      ),
                    ],
                  ),
                  trailing: ServiceStatusIndicator(
                    clock: (
                      ownerId: equipment.id,
                      ownerName: equipment.name,
                      status: status,
                    ),
                    subjectId: equipment.id,
                    density: ServiceIndicatorDensity.dot,
                  ),
                )
              else if (kindId == 'o2-clean')
                // The action sits on its own line under the status rather
                // than in trailing: a ListTile lays trailing out at its
                // natural width first, so a translated label there starves
                // the kind name (issue #2717).
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: heldO2
                      ? Row(
                          children: [
                            Flexible(child: Text(kindNames[kindId] ?? kindId)),
                            const SizedBox(width: 6),
                            const RecordChangedDot(),
                          ],
                        )
                      : Text(kindNames[kindId] ?? kindId),
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!heldO2) Text(l10n.passport_service_notTracked),
                      if (canAct && !heldO2)
                        TileSubtitleAction(
                          onPressed: () => switch (editing) {
                            final s? => holdClock(s, _o2Clock()),
                            null => _trackO2Clean(context, ref),
                          },
                          label: l10n.passport_service_trackO2Clean,
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
