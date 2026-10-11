import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_resolver.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/fill_summary.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/import_tag_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('scanCylinderTag');

/// Resolves [text] against the active diver's cylinders only: the tank
/// editor and the blender take nothing else (issue #2652).
Future<PassportResolution> resolveScannedTag(WidgetRef ref, String text) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final repository = ref.read(cylinderPassportRepositoryProvider);
  return PassportResolver(
    findEquipmentId: (passportId) => repository.findEquipmentIdByPassportId(
      passportId,
      diverId: diverId,
      type: EquipmentType.tank,
    ),
  ).resolve(text);
}

/// Resolves [text] against every item the active diver can see.
Future<TagResolution> resolveAnyTag(WidgetRef ref, String text) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final repository = ref.read(cylinderPassportRepositoryProvider);
  return TagResolver(
    findHolder: (passportId) =>
        repository.findHolderByPassportId(passportId, diverId: diverId),
  ).resolve(text);
}

/// Opens what [text] points at, for either kind of tag: the own item's
/// passport (cylinder or gear, carrying the scanned tag for the stale-tag
/// hint), the foreign page for its kind, or a message.
Future<void> openScannedTag(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final resolution = await resolveAnyTag(ref, text);
    // The diver left the page while the tag was looked up: open nothing.
    if (!context.mounted) return;
    switch (resolution) {
      case OwnTaggedItem(:final equipmentId, :final type, :final link)
          when type == EquipmentType.tank:
        final tag = link is CylinderTagLink ? link.payload : null;
        if (tag != null) {
          // The fill the tag carries joins the history once (spec section 11).
          final added = await importTagFill(
            ref,
            tag: tag,
            equipmentId: equipmentId,
          );
          if (!context.mounted) return;
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
        router.push('/equipment/$equipmentId/passport', extra: tag);
      case OwnTaggedItem(:final equipmentId, :final link):
        router.push(
          gearPassportLocation(equipmentId),
          extra: link is GearTagLink ? link.payload : null,
        );
      case ForeignCylinderTag(:final tag):
        router.push(foreignPassportLocation(tag));
      case ForeignGearTag(:final tag):
        router.push(foreignGearLocation(tag));
      case UnreadableTag():
        // Any tag kind is welcome here, so the message names none.
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.tagScan_linkInvalid)),
        );
    }
  } catch (e, stackTrace) {
    _log.error(
      'Failed to open a scanned tag',
      error: e,
      stackTrace: stackTrace,
    );
    // Leaving mid-lookup disposes the ref the lookup reads; that is not a
    // failure worth telling the diver about.
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.passport_scan_openFailed)),
    );
  }
}

/// The scan button's whole flow: open the sheet, then open the result.
Future<void> scanAndOpenTag(BuildContext context, WidgetRef ref) async {
  final text = await ref.read(passportScanLauncherProvider)(context);
  if (text == null || !context.mounted) return;
  await openScannedTag(context, ref, text);
}
