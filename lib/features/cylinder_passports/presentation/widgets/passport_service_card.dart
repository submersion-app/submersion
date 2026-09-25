import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three cylinder clocks the passport cares about, in this order.
const List<String> kPassportServiceKinds = ['hydro', 'vip', 'o2-clean'];

/// Hydro, VIP and O2 clean read from the service clocks, never from the
/// catalog date attributes, so the passport cannot contradict the reminders
/// (spec section 8, Service card).
class PassportServiceCard extends ConsumerWidget {
  const PassportServiceCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  Future<void> _trackO2Clean(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    await ref
        .read(serviceScheduleRepositoryProvider)
        .createSchedule(
          ServiceSchedule(
            id: '',
            equipmentId: equipment.id,
            serviceKindId: 'o2-clean',
            createdAt: now,
            updatedAt: now,
          ),
        );
    invalidateServiceClockProviders(ref, equipment.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final clocks =
        ref.watch(serviceClockStatusesProvider(equipment.id)).value ??
        const <ServiceClockStatus>[];
    final byKind = {for (final c in clocks) c.kind.id: c};
    final records =
        ref.watch(serviceRecordsForEquipmentProvider(equipment.id)).value ??
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
            Text(
              l10n.passport_service_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final kindId in kPassportServiceKinds)
              if (byKind[kindId] case final status?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(status.kind.name),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(kindNames[kindId] ?? kindId),
                  subtitle: Text(l10n.passport_service_notTracked),
                  trailing: TextButton(
                    onPressed: () => _trackO2Clean(context, ref),
                    child: Text(l10n.passport_service_trackO2Clean),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
