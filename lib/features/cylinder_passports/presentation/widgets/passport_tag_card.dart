import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The payload a label written right now should carry: the row's spec, the
/// recorded hydro and VIP dates (never a clock's fallback anchor), and O2
/// clean only when a cleaning is on record and its clock is not overdue.
/// Null until the passport id exists.
CylinderPassportPayload? currentPayloadFor(
  EquipmentItem item, {
  required String? passportId,
  required List<ServiceClockStatus> clocks,
  required Iterable<ServiceRecord> records,
  required DateTime now,
}) {
  if (passportId == null) return null;
  ServiceClockStatus? clock(String kindId) =>
      clocks.where((c) => c.kind.id == kindId).firstOrNull;
  final o2 = clock('o2-clean');
  // Bounded so every QR drawn from it (on screen and on the printed label)
  // stays inside the label's designed density.
  return NdefFit.fitForLabel(
    payloadForItem(
      item: item,
      passportId: passportId,
      writtenOn: DateTime(now.year, now.month, now.day),
      hydroAnchor: recordedServiceDate(clock: clock('hydro'), records: records),
      vipAnchor: recordedServiceDate(clock: clock('vip'), records: records),
      o2Clean:
          o2 != null &&
          o2.severity != ServiceClockSeverity.overdue &&
          recordedServiceDate(clock: o2, records: records) != null,
    ),
  );
}

/// QR of the current tag string, print and link actions, and the stale-tag
/// hint when a scanned tag predates the row (spec section 8, Tag card).
class PassportTagCard extends ConsumerWidget {
  const PassportTagCard({
    super.key,
    required this.equipment,
    this.scannedTag,
    this.onPrintLabel,
  });

  final EquipmentItem equipment;

  /// The tag that opened this passport, when it was opened by a scan or a
  /// link; drives the stale hint.
  final CylinderPassportPayload? scannedTag;

  /// Wired by the label printer; null disables the button.
  /// Called with the Print button's own context, so the share sheet can
  /// point at the button rather than at the whole page.
  final Future<void> Function(BuildContext buttonContext)? onPrintLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
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
    final warn = StatusColors.of(context).warn;
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warn.container,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: warn.onContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passport_tag_stale,
                        style: TextStyle(color: warn.onContainer),
                      ),
                    ),
                  ],
                ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
