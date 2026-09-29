import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/fill_summary.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('scanCylinderTag');

/// Resolves [text] against the active diver's cylinders.
Future<PassportResolution> resolveScannedTag(WidgetRef ref, String text) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final repository = ref.read(cylinderPassportRepositoryProvider);
  return PassportResolver(
    findEquipmentId: (passportId) =>
        repository.findEquipmentIdByPassportId(passportId, diverId: diverId),
  ).resolve(text);
}

/// Opens what [text] points at: the diver's own passport (carrying the
/// scanned tag, for the stale-tag hint), the foreign passport, or a message.
Future<void> openScannedTag(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final resolution = await resolveScannedTag(ref, text);
    // The diver left the page while the tag was looked up: open nothing.
    if (!context.mounted) return;
    switch (resolution) {
      case OwnCylinder(:final equipmentId, :final tag):
        // The fill the tag carries joins the history once (spec section 11).
        // It is an extra: a failed import is logged and the passport opens.
        CylinderFill? added;
        try {
          final diverId = await ref.read(
            validatedCurrentDiverIdProvider.future,
          );
          added = await ref
              .read(tagFillImporterProvider)
              .importIfNew(
                tag: tag,
                equipmentId: equipmentId,
                diverId: diverId,
              );
        } catch (e, stackTrace) {
          _log.error(
            'Failed to import the fill on a scanned tag',
            error: e,
            stackTrace: stackTrace,
          );
        }
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
        router.push('/equipment/$equipmentId/passport', extra: tag);
      case ForeignCylinder(:final tag):
        router.push(foreignPassportLocation(tag));
      case NotACylinderTag():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.passport_tag_linkInvalid)),
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
Future<void> scanAndOpenCylinderTag(BuildContext context, WidgetRef ref) async {
  final text = await ref.read(passportScanLauncherProvider)(context);
  if (text == null || !context.mounted) return;
  await openScannedTag(context, ref, text);
}
