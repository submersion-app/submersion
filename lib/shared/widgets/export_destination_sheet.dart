import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Where an export should be delivered.
enum ExportDestination {
  /// Hand the file to the system share sheet (email, messages, AirDrop).
  share,

  /// Prompt for a location on disk and write the file there.
  ///
  /// This is the idiom desktop users expect; the share sheet is a mobile one.
  saveToFile,
}

/// Asks the user whether an export should be shared or saved to disk.
///
/// Returns the chosen destination, or null if the sheet was dismissed.
///
/// Every export surface should offer both: exports that only share leave
/// desktop users with no way to put the file where they want it, and exports
/// that only save lose the mobile share flow.
Future<ExportDestination?> showExportDestinationSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<ExportDestination>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(sheetContext.l10n.transfer_export_optionSaveTitle),
              subtitle: Text(
                sheetContext.l10n.transfer_export_optionSaveSubtitle,
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, ExportDestination.saveToFile),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(sheetContext.l10n.transfer_export_optionShareTitle),
              subtitle: Text(
                sheetContext.l10n.transfer_export_optionShareSubtitle,
              ),
              onTap: () => Navigator.pop(sheetContext, ExportDestination.share),
            ),
          ],
        ),
      ),
    ),
  );
}
