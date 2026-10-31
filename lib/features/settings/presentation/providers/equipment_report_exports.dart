import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_report_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The two equipment report exports, kept beside [ExportNotifier] rather than
/// inside it. Each sets [ExportState] the way the maintenance log does.
mixin EquipmentReportExports on StateNotifier<ExportState> {
  Ref get reportRef;
  ExportService get reportExportService;
  AppLocalizations get reportL10n;

  /// Shares the inventory, or saves it to a chosen place when [save] is true.
  Future<void> exportEquipmentInventory(
    InventoryReportOptions options, {
    required bool save,
  }) {
    final l10n = reportL10n;
    final service = reportExportService;
    return _runReportExport<InventoryReport>(
      save: save,
      progress: l10n.settings_export_progress_inventory,
      shared: l10n.settings_export_success_inventory,
      saved: l10n.settings_export_saved_inventory,
      load: inventoryReportProvider(options).future,
      isEmpty: (report) => report.isEmpty,
      deliver: (report, print) => save
          ? service.saveEquipmentInventoryToFile(
              report,
              options: options,
              print: print,
            )
          : service.exportEquipmentInventory(
              report,
              options: options,
              print: print,
            ),
    );
  }

  /// Shares the service report, or saves it when [save] is true.
  Future<void> exportServiceReport(
    ServiceReportOptions options, {
    required bool save,
  }) {
    final l10n = reportL10n;
    final service = reportExportService;
    return _runReportExport<ServiceReport>(
      save: save,
      progress: l10n.settings_export_progress_serviceReport,
      shared: l10n.settings_export_success_serviceReport,
      saved: l10n.settings_export_saved_serviceReport,
      load: serviceReportProvider(options).future,
      isEmpty: (report) => report.isEmpty,
      deliver: (report, print) => save
          ? service.saveServiceReportToFile(
              report,
              options: options,
              print: print,
            )
          : service.exportServiceReport(report, options: options, print: print),
    );
  }

  Future<void> _runReportExport<R>({
    required bool save,
    required String progress,
    required String shared,
    required String saved,
    required ProviderListenable<Future<R>> load,
    required bool Function(R report) isEmpty,
    required Future<String?> Function(R report, ReportPrintSettings print)
    deliver,
  }) async {
    final l10n = reportL10n;
    state = state.copyWith(status: ExportStatus.exporting, message: progress);
    // A notifier's ref outlives each export, so the released report's
    // listener is closed here rather than left to pile up.
    final sub = reportRef.listen(load, (_, _) {});
    try {
      final report = await sub.read();
      if (isEmpty(report)) {
        state = state.copyWith(
          status: ExportStatus.error,
          message: l10n.settings_export_empty_data,
        );
        return;
      }
      final diver = await reportRef.read(currentDiverProvider.future);
      if (save) {
        state = state.copyWith(
          message: l10n.settings_export_progress_chooseLocation,
        );
      }
      final path = await deliver(
        report,
        ReportPrintSettings(
          diverName: diver?.name,
          units: UnitFormatter(reportRef.read(settingsProvider)),
          printedAt: DateTime.now(),
          localization: PdfLocalization.forLanguageCode(l10n.localeName),
        ),
      );
      // Null means the diver cancelled the save panel, which is a no-op and
      // must never be reported as success.
      state = path == null
          ? state.copyWith(
              status: ExportStatus.idle,
              message: l10n.settings_export_cancelled_save,
            )
          : state.copyWith(
              status: ExportStatus.success,
              message: save ? saved : shared,
              filePath: path,
            );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: save
            ? l10n.settings_export_saveFailed('$e')
            : l10n.settings_data_export_failed('$e'),
      );
    } finally {
      sub.close();
    }
  }
}
