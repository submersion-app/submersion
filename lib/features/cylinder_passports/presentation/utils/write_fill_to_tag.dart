import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/fill_summary.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('writeFillToTag');

/// What an NFC write for [equipmentId] carries right now: the full payload
/// with the newest fill, as the Tag card builds it (spec section 11).
final tagPayloadProvider = FutureProvider.autoDispose
    .family<CylinderPassportPayload?, String>((ref, equipmentId) async {
      final item = await ref.watch(equipmentItemProvider(equipmentId).future);
      if (item == null) return null;
      return fullPayloadFor(
        item,
        passportId: await ref.watch(passportIdProvider(equipmentId).future),
        clocks: await ref.watch(
          serviceClockStatusesProvider(equipmentId).future,
        ),
        records: await ref.watch(
          serviceRecordsForEquipmentProvider(equipmentId).future,
        ),
        now: DateTime.now(),
        newestFill: await ref.watch(newestFillProvider(equipmentId).future),
      );
    });

/// After Log a fill (spec section 11): on a phone with NFC turned on, offer
/// to write the fill to the tank's tag straight away.
Future<void> offerWriteFillToTag(
  BuildContext context,
  WidgetRef ref, {
  required String equipmentId,
  required CylinderFill fill,
}) async {
  if (!nfcPlatform()) return;
  if (await ref.read(nfcSupportProvider.future) != NfcSupport.enabled) return;
  if (!context.mounted) return;
  // The tag carries the cylinder's newest fill. A backdated fill is not it,
  // so offering to write it would write a different fill from the one
  // named. The fills tick may not have reached the list yet, so it is
  // re-read first.
  ref.invalidate(fillsForEquipmentProvider(equipmentId));
  final CylinderFill? newest;
  try {
    newest = await ref.read(newestFillProvider(equipmentId).future);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to read the newest fill before offering a tag write',
      error: e,
      stackTrace: stackTrace,
    );
    return;
  }
  if (newest?.id != fill.id || !context.mounted) return;
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final summary = fillSummary(fill.gasMix, fill.pressureBar, units);
  final write = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.passport_fill_writeToTagTitle),
      content: Text('$summary\n\n${l10n.passport_fill_writeToTagBody}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.passport_fill_notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.passport_fill_writeToTag),
        ),
      ],
    ),
  );
  if (write != true || !context.mounted) return;
  // Listened to while it builds: an auto-dispose provider that is only read
  // is disposed at its first await.
  final listening = ref.listenManual(
    tagPayloadProvider(equipmentId),
    (_, _) {},
  );
  final CylinderPassportPayload? payload;
  try {
    payload = await ref.read(tagPayloadProvider(equipmentId).future);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to build the tag payload for a fill',
      error: e,
      stackTrace: stackTrace,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passport_nfc_writeFailed)));
    }
    return;
  } finally {
    listening.close();
  }
  if (payload == null || !context.mounted) return;
  await showNfcWriteSheet(context, payload: payload);
}
