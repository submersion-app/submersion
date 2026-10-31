import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Renders the equipment inventory: what the diver owns, with serial numbers
/// and what they paid, for an insurer or a customs officer.
class EquipmentInventoryPdfExportService {
  /// [loadTheme] picks the fonts. The default loads Roboto plus the script
  /// font the language needs; tests pass a Helvetica theme because text drawn
  /// in an embedded TrueType font cannot be read back out of the PDF.
  EquipmentInventoryPdfExportService({
    Future<pw.ThemeData> Function(PdfLocalization localization)? loadTheme,
  }) : _loadTheme = loadTheme ?? _sharedTheme;

  final Future<pw.ThemeData> Function(PdfLocalization localization) _loadTheme;

  static final _fileNameDate = DateFormat('yyyy-MM-dd');

  static Future<pw.ThemeData> _sharedTheme(PdfLocalization localization) async {
    await PdfFonts.instance.initialize();
    return PdfFonts.instance.themeFor(localization);
  }

  /// Builds the PDF bytes without touching the filesystem. Null [localization]
  /// prints English.
  Future<List<int>> generateBytes(
    InventoryReport report, {
    required InventoryReportOptions options,
    required String? diverName,
    required UnitFormatter units,
    required DateTime printedAt,
    PdfLocalization? localization,
  }) async {
    final loc = localization ?? PdfLocalization.english();
    final l10n = loc.l10n;
    final pdf = pw.Document(theme: await _loadTheme(loc));
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: loc.textDirection,
        margin: reportMargin,
        maxPages: reportMaxPages,
        build: (context) => [
          reportHeader(
            title: l10n.equipmentReport_pdf_inventoryTitle,
            diverName: diverName,
            printedLine: l10n.equipmentReport_pdf_printedOn(
              units.formatDate(printedAt),
            ),
          ),
          summaryStrip([
            (
              value: l10n.equipmentReport_pdf_items(report.itemCount),
              label: null,
            ),
            if (options.showPrices)
              for (final total in report.totals)
                (
                  value: formatMoney(total.value, total.key),
                  label: l10n.equipmentReport_pdf_currencyTotal(total.key),
                ),
          ]),
          for (final group in report.groups) ...[
            groupHeading(
              _groupTitle(l10n, group),
              options.showPrices ? _subtotal(group) : null,
            ),
            _table(l10n, report, group, options, units),
          ],
          if (options.showPrices)
            reportFootnote(
              [
                l10n.equipmentReport_pdf_pricesNote,
                if (report.unpricedCount > 0)
                  l10n.equipmentReport_pdf_noPrice(report.unpricedCount),
              ].join(' '),
            ),
        ],
      ),
    );
    return pdf.save();
  }

  String _groupTitle(AppLocalizations l10n, InventoryGroup group) =>
      group.type?.localizedName(l10n) ??
      group.location?.name ??
      l10n.equipmentReport_pdf_noLocation;

  /// One amount per currency, never added together.
  String? _subtotal(InventoryGroup group) => group.subtotals.isEmpty
      ? null
      : [
          for (final total in group.subtotals)
            formatMoney(total.value, total.key),
        ].join(' + ');

  pw.Widget _table(
    AppLocalizations l10n,
    InventoryReport report,
    InventoryGroup group,
    InventoryReportOptions options,
    UnitFormatter units,
  ) => reportTable(
    headers: [
      l10n.equipmentReport_pdf_colItem,
      l10n.equipmentReport_pdf_colSerial,
      l10n.equipmentReport_pdf_colBought,
      if (options.showPrices) l10n.equipmentReport_pdf_colPaid,
    ],
    columnWidths: {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(1.5),
      if (options.showPrices) 3: const pw.FlexColumnWidth(1.5),
    },
    endAligned: {if (options.showPrices) 3},
    rows: [
      for (final row in group.rows)
        [
          _itemCell(row),
          reportCell(row.item.serialNumber ?? ''),
          reportCell(
            row.item.purchaseDate == null
                ? ''
                : units.formatDate(row.item.purchaseDate),
          ),
          if (options.showPrices)
            reportCell(_paid(row.item, report.fallbackCurrency), end: true),
        ],
    ],
  );

  /// The name, indented under its parent, with the brand and model an insurer
  /// will ask for on a second line.
  pw.Widget _itemCell(ReportRow row) {
    final make = [
      ?row.item.brand,
      ?row.item.model,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return pw.Padding(
      padding: pw.EdgeInsetsDirectional.only(start: row.depth * 10.0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          reportCell(row.item.name),
          if (make.isNotEmpty) reportCell(make, color: reportMutedColor),
        ],
      ),
    );
  }

  String _paid(EquipmentItem item, String fallbackCurrency) {
    final price = item.purchasePrice;
    if (price == null) return '';
    final code = item.purchaseCurrency.trim();
    return formatMoney(price, code.isEmpty ? fallbackCurrency : code);
  }

  String _fileName(DateTime printedAt) =>
      'submersion_equipment_inventory_${_fileNameDate.format(printedAt)}.pdf';

  /// Writes the PDF to the documents directory and opens the system share
  /// sheet. Returns the saved path.
  Future<String> exportToPdf(
    InventoryReport report, {
    required InventoryReportOptions options,
    required String? diverName,
    required UnitFormatter units,
    required DateTime printedAt,
    PdfLocalization? localization,
    Rect? sharePositionOrigin,
  }) async => sharePdfBytes(
    await generateBytes(
      report,
      options: options,
      diverName: diverName,
      units: units,
      printedAt: printedAt,
      localization: localization,
    ),
    _fileName(printedAt),
    sharePositionOrigin: sharePositionOrigin,
  );

  /// Saves the PDF where the diver chooses. Null when they cancel.
  Future<String?> saveToFile(
    InventoryReport report, {
    required InventoryReportOptions options,
    required String? diverName,
    required UnitFormatter units,
    required DateTime printedAt,
    PdfLocalization? localization,
  }) async => savePdfToFile(
    await generateBytes(
      report,
      options: options,
      diverName: diverName,
      units: units,
      printedAt: printedAt,
      localization: localization,
    ),
    _fileName(printedAt),
  );
}
