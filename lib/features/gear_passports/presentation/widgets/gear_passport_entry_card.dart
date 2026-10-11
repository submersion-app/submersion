import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_rules.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The detail page's doorway to a gear passport: the QR once the item has a
/// passport id, the last service date, and Open passport.
class GearPassportEntryCard extends ConsumerWidget {
  const GearPassportEntryCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
    final records =
        ref.watch(serviceRecordsForEquipmentProvider(equipment.id)).value ??
        const <ServiceRecord>[];
    final last = lastServiceDate(records);
    final location = gearPassportLocation(equipment.id);
    return Card(
      child: InkWell(
        onTap: () => context.push(location),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (passportId != null)
                PassportQrView(
                  data: GearTagCodec.httpsUrl(
                    GearTagFit.fitForLabel(
                      gearPayloadForItem(
                        item: equipment,
                        passportId: passportId,
                        now: DateTime.now(),
                        lastService: last,
                      ),
                    ),
                  ),
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
                      l10n.gearPassport_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      last == null
                          ? l10n.gearPassport_entry_noService
                          : l10n.gearPassport_entry_lastService(
                              units.formatDate(last),
                            ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(location),
                child: Text(l10n.passport_open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
