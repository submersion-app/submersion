import 'package:flutter/material.dart';

import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/nfc_availability_text.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/tag_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/tag_stale_banner.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The payload a tag written right now carries in full: the row's spec, the
/// recorded hydro and VIP dates (never a clock's fallback anchor), and O2
/// clean only when a cleaning is on record and its clock is not overdue.
/// Null until the passport id exists. An NFC write starts here and lets the
/// tag's capacity decide what is left off; [newestFill] rides along on an
/// NFC tag only (spec section 11), never on a printed label.
CylinderPassportPayload? fullPayloadFor(
  EquipmentItem item, {
  required String? passportId,
  required List<ServiceClockStatus> clocks,
  required Iterable<ServiceRecord> records,
  required DateTime now,
  CylinderFill? newestFill,
}) {
  if (passportId == null) return null;
  ServiceClockStatus? clock(String kindId) =>
      clocks.where((c) => c.kind.id == kindId).firstOrNull;
  final o2 = clock('o2-clean');
  final payload = payloadForItem(
    item: item,
    passportId: passportId,
    writtenOn: DateTime(now.year, now.month, now.day),
    hydroAnchor: recordedServiceDate(clock: clock('hydro'), records: records),
    vipAnchor: recordedServiceDate(clock: clock('vip'), records: records),
    o2Clean:
        o2 != null &&
        o2.severity != ServiceClockSeverity.overdue &&
        recordedServiceDate(clock: o2, records: records) != null,
  );
  return newestFill == null
      ? payload
      : payload.copyWith(fill: TagFill.fromFill(newestFill));
}

/// [full], bounded so every QR drawn from it (on screen and on the printed
/// label) stays inside the label's designed density.
CylinderPassportPayload? labelPayloadOf(CylinderPassportPayload? full) =>
    full == null ? null : NdefFit.fitForLabel(full);

/// The payload a label written right now carries: [fullPayloadFor] bounded
/// by [labelPayloadOf].
CylinderPassportPayload? currentPayloadFor(
  EquipmentItem item, {
  required String? passportId,
  required List<ServiceClockStatus> clocks,
  required Iterable<ServiceRecord> records,
  required DateTime now,
}) => labelPayloadOf(
  fullPayloadFor(
    item,
    passportId: passportId,
    clocks: clocks,
    records: records,
    now: now,
  ),
);

/// QR of the current tag string, print and link actions, and the stale-tag
/// hint when a scanned tag predates the row (spec section 8, Tag card).
class PassportTagCard extends ConsumerWidget {
  const PassportTagCard({
    super.key,
    required this.equipment,
    this.scannedTag,
    this.onPrintLabel,
    this.editing,
  });

  final EquipmentItem equipment;

  /// The tag that opened this passport, when it was opened by a scan or a
  /// link; drives the stale hint.
  final CylinderPassportPayload? scannedTag;

  /// Wired by the label printer; null disables the button.
  /// Called with the Print button's own context, so the share sheet can
  /// point at the button rather than at the whole page.
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
    final clocks =
        ref.watch(serviceClockStatusesProvider(equipment.id)).value ??
        const <ServiceClockStatus>[];
    final records =
        ref.watch(serviceRecordsForEquipmentProvider(equipment.id)).value ??
        const <ServiceRecord>[];
    // The label and QR carry the bounded payload; an NFC write starts from
    // the full one and lets the tag's capacity decide what is left off.
    final newestState = ref.watch(newestFillProvider(equipment.id));
    final newest = newestState.value;
    final full = fullPayloadFor(
      equipment,
      passportId: passportId,
      clocks: clocks,
      records: records,
      now: DateTime.now(),
      newestFill: newest,
    );
    // A printed label never carries a fill: it changes every fill.
    final payload = labelPayloadOf(full?.copyWith(clearFill: true));
    final nfc = ref.watch(nfcSupportProvider).value;
    // Every write carries the newest fill, so the write waits for it; a fill
    // that fails to load is an extra, and the passport is still written.
    final canWriteNfc =
        full != null && nfc == NfcSupport.enabled && !newestState.isLoading;
    ServiceClockStatus? clock(String kindId) =>
        clocks.where((c) => c.kind.id == kindId).firstOrNull;
    final scanned = scannedTag;
    final stale =
        scanned != null &&
        tagIsStale(
          tag: scanned,
          hydroAnchor: recordedServiceDate(
            clock: clock('hydro'),
            records: records,
          ),
          vipAnchor: recordedServiceDate(clock: clock('vip'), records: records),
          volumeL: equipment.volumeL,
          workingPressureBar: equipment.workingPressureBar?.round(),
          material: equipment.tankMaterial,
        );
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
                  data: PassportPayloadCodec.httpsUrl(payload),
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
                rewriteKey: const Key('passportTag_rewrite'),
                reprintKey: const Key('passportTag_reprint'),
                onRewrite: canWriteNfc
                    ? () => showNfcWriteSheet(context, payload: full)
                    : null,
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
                  builder: (buttonContext) => FilledButton.tonalIcon(
                    onPressed: payload == null || onPrintLabel == null
                        ? null
                        : () => onPrintLabel!(buttonContext),
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
                      editing: editing,
                    ),
                    icon: const Icon(Icons.link),
                    label: Text(l10n.passport_tag_linkExisting),
                  ),
                OutlinedButton.icon(
                  key: const Key('passportTag_writeNfc'),
                  onPressed: canWriteNfc
                      ? () => showNfcWriteSheet(context, payload: full)
                      : null,
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
