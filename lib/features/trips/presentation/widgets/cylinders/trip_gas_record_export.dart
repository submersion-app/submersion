import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/settings/presentation/providers/csv_unit_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

/// The Record header's export: the destination sheet (share or save, with
/// the CSV units toggle), then the record's rows as a CSV through the
/// export facade, so tests can override it like every export surface.
class TripGasRecordExportButton extends ConsumerWidget {
  const TripGasRecordExportButton({
    super.key,
    required this.record,
    required this.tripName,
    required this.centerNames,
  });

  final TripGasRecord record;
  final String tripName;
  final Map<String, String> centerNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return TextButton.icon(
      key: const Key('record-export'),
      icon: const Icon(Icons.ios_share),
      label: Text(l10n.transfer_csvExport_exportButton),
      onPressed: () async {
        final choice = await showExportDestinationSheetWithOptions(
          context,
          title: l10n.transfer_csvExport_dialogTitle,
          showCsvUnitsToggle: true,
          initialCsvUnitMode: ref.read(csvUnitModeProvider),
        );
        if (choice == null || !context.mounted) return;
        // Remembered on this device, as every CSV export does.
        unawaited(
          ref.read(csvUnitModeProvider.notifier).set(choice.csvUnitMode),
        );
        final units = CsvExportUnits.forMode(
          choice.csvUnitMode,
          ref.read(settingsProvider),
        );
        final service = ref.read(exportServiceProvider);
        // This widget adds no render object of its own, so its context
        // resolves to the button: the iPad share popover points at it.
        final anchor = shareAnchorFrom(context);
        // No progress dialog around the save path: the native save panel
        // must not open while a modal route is up.
        final messenger = ScaffoldMessenger.of(context);
        try {
          final path = choice.destination == ExportDestination.share
              ? await service.exportTripGasRecordToCsv(
                  record,
                  tripName: tripName,
                  centerNames: centerNames,
                  units: units,
                  sharePositionOrigin: anchor,
                )
              : await service.saveTripGasRecordCsvToFile(
                  record,
                  tripName: tripName,
                  centerNames: centerNames,
                  dialogTitle: l10n.transfer_csvExport_dialogTitle,
                  units: units,
                );
          // A null path means the save panel was dismissed: not a failure,
          // and nothing was exported.
          if (path == null) return;
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.trips_cylinders_record_exported)),
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.diveLog_export_failed('$e'))),
          );
        }
      },
    );
  }
}
