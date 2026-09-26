import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(PassportResolver);

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
    switch (await resolveScannedTag(ref, text)) {
      case OwnCylinder(:final equipmentId, :final tag):
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
