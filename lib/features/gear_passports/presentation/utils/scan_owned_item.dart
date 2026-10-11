import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/fill_summary.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/import_tag_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_departed_status.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_resolver.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('scanOwnedItem');

/// Scans a tag and returns the diver's own item it names, cylinder or other
/// gear, for a flow that adds the item somewhere (a dive, a trip). Returns
/// null after telling the diver why not: someone else's gear (with View),
/// gear out of the kit (wanted, retired, sold or lost), or text that is no
/// tag.
Future<EquipmentItem?> scanOwnedItem(
  BuildContext context,
  WidgetRef ref,
) async {
  final text = await ref.read(passportScanLauncherProvider)(context);
  if (text == null || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  // Null where no router hosts the caller (an embedded editor in a test);
  // the "not yours" message then offers no View.
  final router = GoRouter.maybeOf(context);
  final l10n = context.l10n;
  try {
    final resolution = await resolveAnyTag(ref, text);
    if (!context.mounted) return null;
    switch (resolution) {
      case OwnTaggedItem(:final equipmentId, :final type, :final link):
        final item = await ref
            .read(equipmentRepositoryProvider)
            .getEquipmentById(equipmentId);
        if (item == null || !context.mounted) return null;
        // Refused before anything is written: gear out of the kit gains no
        // fill and joins no dive or trip, as the pickers never offer it.
        if (_outOfKitMessage(l10n, item) case final message?) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return null;
        }
        if (type == EquipmentType.tank && link is CylinderTagLink) {
          // The fill the tag carries joins the history once, and the diver
          // hears so, as on the Equipment list's scan (spec section 11).
          final added = await importTagFill(
            ref,
            tag: link.payload,
            equipmentId: equipmentId,
          );
          if (!context.mounted) return null;
          if (added != null) {
            final units = UnitFormatter(ref.read(settingsProvider));
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n.passport_fill_addedFromTag(
                    fillSummary(added.gasMix, added.pressureBar, units),
                  ),
                ),
              ),
            );
          }
        }
        return item;
      case ForeignCylinderTag(:final tag):
        _notYours(
          messenger,
          l10n.gearPassport_scan_notYours,
          l10n.gearPassport_scan_view,
          router == null
              ? null
              : () => router.push(foreignPassportLocation(tag)),
        );
      case ForeignGearTag(:final tag):
        _notYours(
          messenger,
          l10n.gearPassport_scan_notYours,
          l10n.gearPassport_scan_view,
          router == null ? null : () => router.push(foreignGearLocation(tag)),
        );
      case UnreadableTag():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.tagScan_linkInvalid)),
        );
    }
  } catch (e, stackTrace) {
    _log.error('Failed to scan an item', error: e, stackTrace: stackTrace);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passport_scan_openFailed)),
      );
    }
  }
  return null;
}

/// Why [item] cannot be added, named by the status the app shows for it
/// ([departedStatusOf]: an inactive item reads as Retired), or null for gear
/// in the kit. The same test as the active-equipment list the pickers read.
/// Spare gear is added although the dive and trip pickers hide it
/// (`hideSpare`): they hide spares to keep the list short, and a spare
/// whose tag the diver scans is one they mean to use. Lost gear still
/// marked active is added, as the pickers offer it.
String? _outOfKitMessage(AppLocalizations l10n, EquipmentItem item) {
  if (item.isFitted) return null;
  return switch (departedStatusOf(item)) {
    EquipmentStatus.wanted => l10n.gearPassport_scan_wishlist(item.name),
    EquipmentStatus.sold => l10n.gearPassport_scan_sold(item.name),
    EquipmentStatus.lost => l10n.gearPassport_scan_lost(item.name),
    _ => l10n.gearPassport_scan_retired(item.name),
  };
}

void _notYours(
  ScaffoldMessengerState messenger,
  String text,
  String viewLabel,
  VoidCallback? view,
) => messenger.showSnackBar(
  SnackBar(
    content: Text(text),
    action: view == null
        ? null
        : SnackBarAction(label: viewLabel, onPressed: view),
  ),
);
