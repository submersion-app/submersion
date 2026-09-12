import 'package:flutter/material.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
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
}) async {
  final choice = await showExportDestinationSheetWithOptions(
    context,
    title: title,
  );
  return choice?.destination;
}

/// What the user chose in an export destination sheet: where to deliver the
/// file, and the UDDF content checkboxes as options.
typedef ExportChoice = ({
  ExportDestination destination,
  UddfExportOptions options,
});

/// The destination sheet, plus the UDDF content checkboxes.
///
/// [showRawDataToggle] is false for every export that has no raw bytes to
/// carry, which is every format except UDDF. [showDiveContentToggles] adds
/// the participants and gear checkboxes, which only the dives only UDDF
/// export honours; the full backup always carries both. Every checkbox
/// starts from [initialOptions], whose defaults are all on, so the code
/// level default and what the user sees never diverge.
Future<ExportChoice?> showExportDestinationSheetWithOptions(
  BuildContext context, {
  required String title,
  bool showRawDataToggle = false,
  bool showDiveContentToggles = false,
  UddfExportOptions initialOptions = const UddfExportOptions(),
}) {
  var options = initialOptions;

  return showModalBottomSheet<ExportChoice>(
    context: context,
    // Up to three checkboxes above the two destinations outgrow the default
    // cap of 9/16 of the screen height on a phone, so the sheet sizes to its
    // content and scrolls when even that does not fit.
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (builderContext, setSheetState) => SafeArea(
        child: SingleChildScrollView(
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
              if (showRawDataToggle) ...[
                CheckboxListTile(
                  value: options.includeRawData,
                  onChanged: (value) => setSheetState(
                    () => options = options.copyWith(includeRawData: value),
                  ),
                  title: Text(sheetContext.l10n.transfer_export_includeRawData),
                  subtitle: Text(
                    sheetContext.l10n.transfer_export_includeRawDataSubtitle,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (!showDiveContentToggles) const Divider(height: 1),
              ],
              if (showDiveContentToggles) ...[
                CheckboxListTile(
                  value: options.includeParticipants,
                  onChanged: (value) => setSheetState(
                    () =>
                        options = options.copyWith(includeParticipants: value),
                  ),
                  title: Text(
                    sheetContext.l10n.transfer_export_includeParticipants,
                  ),
                  subtitle: Text(
                    sheetContext
                        .l10n
                        .transfer_export_includeParticipantsSubtitle,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: options.includeGear,
                  onChanged: (value) => setSheetState(
                    () => options = options.copyWith(includeGear: value),
                  ),
                  title: Text(sheetContext.l10n.transfer_export_includeGear),
                  subtitle: Text(
                    sheetContext.l10n.transfer_export_includeGearSubtitle,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: Text(sheetContext.l10n.transfer_export_optionSaveTitle),
                subtitle: Text(
                  sheetContext.l10n.transfer_export_optionSaveSubtitle,
                ),
                onTap: () => Navigator.pop(sheetContext, (
                  destination: ExportDestination.saveToFile,
                  options: options,
                )),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(sheetContext.l10n.transfer_export_optionShareTitle),
                subtitle: Text(
                  sheetContext.l10n.transfer_export_optionShareSubtitle,
                ),
                onTap: () => Navigator.pop(sheetContext, (
                  destination: ExportDestination.share,
                  options: options,
                )),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
