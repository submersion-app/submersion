import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_fetch.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

/// Exports every dive shared with [buddyId] as UDDF, via the share sheet or
/// a save panel depending on the user's choice.
///
/// Split out of [BuddyDetailPage] (pure export logic, no UI beyond the
/// destination sheet and a couple of snackbars) to keep that file under the
/// project's 800-line guideline.
Future<void> shareDivesWithBuddy(
  BuildContext context,
  WidgetRef ref,
  String buddyId,
) async {
  // Capture the scaffold messenger and l10n before any async gaps
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final choice = await showExportDestinationSheetWithOptions(
    context,
    title: l10n.buddies_action_shareDives,
    showRawDataToggle: true,
    showDiveContentToggles: true,
  );
  if (choice == null) return;
  final destination = choice.destination;
  final options = choice.options;

  // Show preparing message
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Text(l10n.buddies_message_preparingExport),
      duration: const Duration(seconds: 1),
    ),
  );

  // Get all dive IDs for this buddy
  final diveIds = await ref.read(diveIdsForBuddyProvider(buddyId).future);

  if (diveIds.isEmpty) {
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(l10n.buddies_message_noDivesToShare)),
    );
    return;
  }

  try {
    // Fetch all dives
    final diveRepository = ref.read(diveRepositoryProvider);
    final dives = <Dive>[];
    for (final diveId in diveIds) {
      final dive = await diveRepository.getDiveById(diveId);
      if (dive != null) {
        dives.add(dive);
      }
    }

    if (dives.isEmpty) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.buddies_message_noDivesFound)),
      );
      return;
    }

    // Get unique sites from dives
    final sites = dives
        .where((d) => d.site != null)
        .map((d) => d.site!)
        .toSet()
        .toList();

    scaffoldMessenger.hideCurrentSnackBar();

    // Hand the UDDF to the share sheet, or to a save panel on the user's
    // request. Either way no success snackbar follows: the share sheet and
    // the save panel each provide their own feedback.
    final exportService = ref.read(exportServiceProvider);
    final dataSources = await ref.read(uddfSourceFetchProvider)(
      dives.map((d) => d.id).toList(growable: false),
      options,
    );
    final extras = await ref.read(uddfDivesExtrasFetchProvider)(
      dives.map((d) => d.id).toList(growable: false),
      options,
    );
    switch (destination) {
      case ExportDestination.share:
        await exportService.exportDivesToUddf(
          dives,
          sites: sites,
          dataSources: dataSources,
          extras: extras,
          options: options,
        );
      case ExportDestination.saveToFile:
        await exportService.saveDivesToUddfFile(
          dives,
          sites: sites,
          dataSources: dataSources,
          extras: extras,
          options: options,
        );
    }
  } catch (e) {
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(l10n.buddies_message_exportFailed(e.toString()))),
    );
  }
}
