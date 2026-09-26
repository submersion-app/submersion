import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The tank detail page's doorway to the passport: a QR thumbnail once the
/// cylinder has a passport id, the newest mix, and Open passport.
class PassportEntryCard extends ConsumerWidget {
  const PassportEntryCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
    final newest = ref.watch(newestFillProvider(equipment.id)).value;
    final clocks =
        ref.watch(serviceClockStatusesProvider(equipment.id)).value ??
        const <ServiceClockStatus>[];
    final records =
        ref.watch(serviceRecordsForEquipmentProvider(equipment.id)).value ??
        const <ServiceRecord>[];
    final payload = currentPayloadFor(
      equipment,
      passportId: passportId,
      clocks: clocks,
      records: records,
      now: DateTime.now(),
    );
    return Card(
      child: InkWell(
        onTap: () => context.push('/equipment/${equipment.id}/passport'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (payload != null)
                PassportQrView(
                  data: PassportPayloadCodec.httpsUrl(payload),
                  semanticLabel: l10n.passport_tag_qrSemantics,
                  size: 72,
                )
              else
                const Icon(Icons.qr_code_2, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.passport_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      newest == null
                          ? l10n.passport_entry_noFill
                          : newest.pressureBar == null
                          ? l10n.passport_entry_lastFillNoPressure(
                              newest.gasMix.name,
                              units.formatDate(newest.filledAt),
                            )
                          : l10n.passport_entry_lastFill(
                              newest.gasMix.name,
                              units.formatPressure(newest.pressureBar),
                              units.formatDate(newest.filledAt),
                            ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.push('/equipment/${equipment.id}/passport'),
                child: Text(l10n.passport_open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
