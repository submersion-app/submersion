import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/export_service.dart';
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

  /// Awaits a released provider's value. A notifier's ref outlives each
  /// export, so the listener is closed here rather than left to pile up.
  Future<T> _readOnce<T>(ProviderListenable<Future<T>> provider) async {
    final sub = reportRef.listen(provider, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  /// Shares the inventory, or saves it to a chosen place when [save] is true.
  Future<void> exportEquipmentInventory(
    InventoryReportOptions options, {
    required bool save,
  }) {
    final l10n = reportL10n;
    return _runReportExport(
      save: save,
      progress: l10n.settings_export_progress_inventory,
      shared: l10n.settings_export_success_inventory,
      saved: l10n.settings_export_saved_inventory,
      deliver: (context) async {
        final report = await _readOnce(inventoryReportProvider(options).future);
        if (report.isEmpty) return const _NothingToExport();
        context.beforeDelivery();
        return _Delivered(
          save
              ? await reportExportService.saveEquipmentInventoryToFile(
                  report,
                  options: options,
                  diverName: context.diverName,
                  units: context.units,
                  printedAt: context.printedAt,
                  localization: context.localization,
                )
              : await reportExportService.exportEquipmentInventory(
                  report,
                  options: options,
                  diverName: context.diverName,
                  units: context.units,
                  printedAt: context.printedAt,
                  localization: context.localization,
                ),
        );
      },
    );
  }

  /// Shares the service report, or saves it when [save] is true.
  Future<void> exportServiceReport(
    ServiceReportOptions options, {
    required bool save,
  }) {
    final l10n = reportL10n;
    return _runReportExport(
      save: save,
      progress: l10n.settings_export_progress_serviceReport,
      shared: l10n.settings_export_success_serviceReport,
      saved: l10n.settings_export_saved_serviceReport,
      deliver: (context) async {
        final report = await _readOnce(serviceReportProvider(options).future);
        if (report.isEmpty) return const _NothingToExport();
        context.beforeDelivery();
        return _Delivered(
          save
              ? await reportExportService.saveServiceReportToFile(
                  report,
                  options: options,
                  diverName: context.diverName,
                  units: context.units,
                  printedAt: context.printedAt,
                  localization: context.localization,
                )
              : await reportExportService.exportServiceReport(
                  report,
                  options: options,
                  diverName: context.diverName,
                  units: context.units,
                  printedAt: context.printedAt,
                  localization: context.localization,
                ),
        );
      },
    );
  }

  Future<void> _runReportExport({
    required bool save,
    required String progress,
    required String shared,
    required String saved,
    required Future<_ReportOutcome> Function(_ReportContext context) deliver,
  }) async {
    final l10n = reportL10n;
    state = state.copyWith(status: ExportStatus.exporting, message: progress);
    try {
      final diver = await reportRef.read(currentDiverProvider.future);
      final outcome = await deliver(
        _ReportContext(
          diverName: diver?.name,
          units: UnitFormatter(reportRef.read(settingsProvider)),
          printedAt: DateTime.now(),
          localization: PdfLocalization.forLanguageCode(l10n.localeName),
          beforeDelivery: () {
            if (save) {
              state = state.copyWith(
                message: l10n.settings_export_progress_chooseLocation,
              );
            }
          },
        ),
      );
      state = switch (outcome) {
        _NothingToExport() => state.copyWith(
          status: ExportStatus.error,
          message: l10n.settings_export_empty_data,
        ),
        // Null means the diver cancelled the save panel, which is a no-op
        // and must never be reported as success.
        _Delivered(path: null) => state.copyWith(
          status: ExportStatus.idle,
          message: l10n.settings_export_cancelled_save,
        ),
        _Delivered(:final path) => state.copyWith(
          status: ExportStatus.success,
          message: save ? saved : shared,
          filePath: path,
        ),
      };
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        message: save
            ? l10n.settings_export_saveFailed('$e')
            : l10n.settings_data_export_failed('$e'),
      );
    }
  }
}

class _ReportContext {
  const _ReportContext({
    required this.diverName,
    required this.units,
    required this.printedAt,
    required this.localization,
    required this.beforeDelivery,
  });

  final String? diverName;
  final UnitFormatter units;
  final DateTime printedAt;
  final PdfLocalization localization;

  /// Runs once the report is known to have something in it.
  final void Function() beforeDelivery;
}

sealed class _ReportOutcome {
  const _ReportOutcome();
}

class _NothingToExport extends _ReportOutcome {
  const _NothingToExport();
}

class _Delivered extends _ReportOutcome {
  const _Delivered(this.path);

  final String? path;
}
