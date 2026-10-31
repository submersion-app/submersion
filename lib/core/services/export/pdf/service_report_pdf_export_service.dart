import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/core/services/export/pdf/equipment_report_pdf_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/utils/service_category_label.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Renders the service report: what needs doing on page one, then each item's
/// service history, for a dive shop, a trip check or a sale.
class ServiceReportPdfExportService
    extends EquipmentReportPdfService<ServiceReport, ServiceReportOptions> {
  ServiceReportPdfExportService({super.loadTheme})
    : super(fileStem: 'submersion_service_report');

  @override
  Future<List<int>> generateBytes(
    ServiceReport report, {
    required ServiceReportOptions options,
    required ReportPrintSettings settings,
  }) async {
    final loc = settings.localization ?? PdfLocalization.english();
    final units = settings.units;
    final l10n = loc.l10n;
    final pdf = pw.Document(theme: await loadTheme(loc));
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: loc.textDirection,
        margin: reportMargin,
        maxPages: reportMaxPages,
        build: (context) => [
          reportHeader(
            title: l10n.equipmentReport_pdf_serviceTitle,
            diverName: settings.diverName,
            printedLine: l10n.equipmentReport_pdf_printedOn(
              units.formatDate(settings.printedAt),
            ),
            detail: report.scopeLabel,
          ),
          summaryStrip([
            (
              value: '${report.overdue}',
              label: l10n.equipmentReport_pdf_overdue,
            ),
            (
              value: '${report.dueSoon}',
              label: l10n.equipmentReport_pdf_dueSoon,
            ),
            (
              value: '${report.upToDate}',
              label: l10n.equipmentReport_pdf_upToDate,
            ),
          ]),
          if (report.due.isNotEmpty)
            _dueTable(l10n, report, units, settings.printedAt)
          // With no clocks at all, nothing has been checked.
          else if (report.upToDate > 0)
            pw.Text(
              l10n.equipmentReport_pdf_allUpToDate,
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (report.noScheduleCount > 0)
            reportFootnote(
              l10n.equipmentReport_pdf_noSchedule(report.noScheduleCount),
            ),
          if (options.includeHistory && report.history.isEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              l10n.equipmentReport_pdf_noHistory,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          if (report.history.isNotEmpty) pw.NewPage(),
          for (final block in report.history) ...[
            groupHeading(
              [
                block.item.name,
                if (block.item.serialNumber case final serial?
                    when serial.trim().isNotEmpty)
                  serial,
              ].join(' · '),
              l10n.equipmentReport_pdf_dives(block.diveCount),
            ),
            _historyTable(l10n, report, block, options, units),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _dueTable(
    AppLocalizations l10n,
    ServiceReport report,
    UnitFormatter units,
    DateTime printedAt,
  ) => reportTable(
    headers: [
      l10n.equipmentReport_pdf_colItem,
      l10n.equipmentReport_pdf_colService,
      l10n.equipmentReport_pdf_colDue,
      l10n.equipmentReport_pdf_colStatus,
    ],
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(3),
      3: pw.FlexColumnWidth(1.5),
    },
    endAligned: const {3},
    rows: [
      for (final row in report.due)
        [
          reportCell(row.item.name),
          reportCell(row.status.kind.name),
          reportCell(
            serviceTriggerLinesFor(
              l10n,
              units: units,
              now: printedAt,
              dueDate: row.status.dueDate,
              usageByUnit: row.status.usageByUnit,
            ).join(' · '),
          ),
          reportCell(
            _statusLabel(l10n, row.severity),
            end: true,
            color: _statusColor(row.severity),
          ),
        ],
    ],
  );

  pw.Widget _historyTable(
    AppLocalizations l10n,
    ServiceReport report,
    ServiceHistoryBlock block,
    ServiceReportOptions options,
    UnitFormatter units,
  ) => reportTable(
    headers: [
      l10n.equipmentReport_pdf_colDate,
      l10n.equipmentReport_pdf_colWork,
      l10n.equipmentReport_pdf_colShop,
      if (options.showCosts) l10n.equipmentReport_pdf_colCost,
    ],
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(3),
      if (options.showCosts) 3: const pw.FlexColumnWidth(1.5),
    },
    endAligned: {if (options.showCosts) 3},
    rows: [
      for (final row in block.rows)
        [
          reportCell(units.formatDate(row.record.serviceDate)),
          reportCell(row.kindName ?? row.record.serviceCategory.label(l10n)),
          reportCell(row.record.provider ?? ''),
          if (options.showCosts)
            reportCell(
              reportMoney(
                row.record.cost,
                row.record.currency,
                report.fallbackCurrency,
              ),
              end: true,
            ),
        ],
    ],
  );

  String _statusLabel(AppLocalizations l10n, ServiceClockSeverity severity) =>
      switch (severity) {
        ServiceClockSeverity.overdue => l10n.equipmentReport_pdf_statusOverdue,
        ServiceClockSeverity.dueSoon => l10n.equipmentReport_pdf_statusDueSoon,
        ServiceClockSeverity.ok => l10n.equipmentReport_pdf_statusUpToDate,
      };

  /// The colour only reinforces the word, so the report survives a black and
  /// white printer.
  PdfColor? _statusColor(ServiceClockSeverity severity) => switch (severity) {
    ServiceClockSeverity.overdue => PdfColors.red800,
    ServiceClockSeverity.dueSoon => PdfColors.orange800,
    ServiceClockSeverity.ok => null,
  };
}
