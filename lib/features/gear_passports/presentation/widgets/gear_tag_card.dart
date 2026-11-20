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
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_rules.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_tag_write.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// QR of the current gear tag, print and link actions, NFC write, and the
/// stale hint when a scanned tag no longer matches (gear tag spec 9).
class GearTagCard extends ConsumerWidget {
  const GearTagCard({
    super.key,
    required this.equipment,
    this.scannedTag,
    this.onPrintLabel,
    this.editing,
  });

  final EquipmentItem equipment;
  final GearTagPayload? scannedTag;
  final Future<void> Function(BuildContext buttonContext)? onPrintLabel;

  /// The open card's sitting (issue #4527, phase 3): Link existing tag is held
  /// there until Save. With no sitting given, the tag cannot be linked; during
  /// a sitting every view shows the linked tag. Writing the tag and printing
  /// are not changes.
  final EditSession<EquipmentItem>? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = RecordEditScope.maybeOf<EquipmentItem>(context);
    final session = editing ?? scope?.session;
    final canLink = scope == null || editing != null;
    if (session == null) return _build(context, ref, null, canLink);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _build(context, ref, session, canLink),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? session,
    bool canLink,
  ) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final storedId = ref.watch(passportIdProvider(equipment.id)).value;
    final passportId = session == null
        ? storedId
        : passportIdInSitting(session, storedId);
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
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.passport_tag_title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (session != null && holdsPassportTag(session)) ...[
                        const SizedBox(width: 6),
                        const RecordChangedDot(),
                      ],
                    ],
                  ),
                ),
                RecordCardPencil(cardTitle: l10n.passport_tag_title),
              ],
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
                if (canLink)
                  OutlinedButton.icon(
                    onPressed: () => linkExistingTag(
                      context,
                      ref,
                      equipment,
                      passportIdOf: tagPassportIdOf,
                      invalidText: (l10n) => l10n.tagScan_linkInvalid,
                      editing: editing,
                    ),
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
