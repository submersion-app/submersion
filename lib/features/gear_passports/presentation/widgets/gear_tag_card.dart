import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/nfc_availability_text.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/tag_stale_banner.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_rules.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_tag_write.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// QR of the current gear tag, print and link actions, NFC write, and the
/// stale hint when a scanned tag no longer matches (gear tag spec 9).
class GearTagCard extends ConsumerWidget {
  const GearTagCard({
    super.key,
    required this.equipment,
    this.scannedTag,
    this.onPrintLabel,
  });

  final EquipmentItem equipment;
  final GearTagPayload? scannedTag;
  final Future<void> Function(BuildContext buttonContext)? onPrintLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
    final recordsState = ref.watch(
      serviceRecordsForEquipmentProvider(equipment.id),
    );
    final records = recordsState.value ?? const <ServiceRecord>[];
    final last = lastServiceDate(records);
    // The NFC write starts from the full payload and lets the tag's capacity
    // decide; the QR and the printed label carry the label-bounded one.
    final payload = passportId == null
        ? null
        : gearPayloadForItem(
            item: equipment,
            passportId: passportId,
            now: DateTime.now(),
            lastService: last,
          );
    final nfc = ref.watch(nfcSupportProvider).value;
    // A tag carries the last service date, so the write waits for the
    // records; one that failed to load is written without it.
    final canWriteNfc =
        payload != null && nfc == NfcSupport.enabled && !recordsState.isLoading;
    final scanned = scannedTag;
    final stale =
        scanned != null &&
        gearTagIsStale(tag: scanned, item: equipment, lastService: last);
    void write() =>
        showTagWriteSheet(context, request: gearTagWriteRequest(payload!));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.passport_tag_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (payload != null)
              Center(
                child: PassportQrView(
                  data: GearTagCodec.httpsUrl(GearTagFit.fitForLabel(payload)),
                  semanticLabel: l10n.passport_tag_qrSemantics,
                  size: 200,
                ),
              ),
            if (scanned?.writtenOn case final written?) ...[
              const SizedBox(height: 8),
              Text(l10n.passport_tag_written(units.formatDate(written))),
            ],
            if (stale) ...[
              const SizedBox(height: 8),
              TagStaleBanner(
                rewriteKey: const Key('gearTag_rewrite'),
                reprintKey: const Key('gearTag_reprint'),
                onRewrite: canWriteNfc ? write : null,
                onReprint: payload == null || onPrintLabel == null
                    ? null
                    : onPrintLabel,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Builder(
                  builder: (b) => FilledButton.tonalIcon(
                    onPressed: payload == null || onPrintLabel == null
                        ? null
                        : () => onPrintLabel!(b),
                    icon: const Icon(Icons.print),
                    label: Text(l10n.passport_tag_printLabel),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final diverId = await ref.read(
                      validatedCurrentDiverIdProvider.future,
                    );
                    if (!context.mounted) return;
                    final linked = await showLinkExistingTagDialog(
                      context,
                      equipmentId: equipment.id,
                      diverId: diverId,
                      passportIdOf: tagPassportIdOf,
                      invalidText: (l10n) => l10n.tagScan_linkInvalid,
                    );
                    if (linked != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.passport_tag_linked)),
                      );
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: Text(l10n.passport_tag_linkExisting),
                ),
                OutlinedButton.icon(
                  key: const Key('gearTag_writeNfc'),
                  onPressed: canWriteNfc ? write : null,
                  icon: const Icon(Icons.nfc),
                  label: Text(l10n.passport_nfc_write),
                ),
              ],
            ),
            if (nfcUnavailableReason(l10n, nfc) case final reason?) ...[
              const SizedBox(height: 4),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
