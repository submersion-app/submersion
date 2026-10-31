import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';

/// How an equipment report reaches the diver, whichever report it is. [R] is
/// the report and [O] the options chosen for it.
abstract class EquipmentReportPdfService<R, O> {
  /// [loadTheme] picks the fonts. The default loads Roboto plus the script
  /// font the language needs; tests pass a Helvetica theme because text drawn
  /// in an embedded TrueType font cannot be read back out of the PDF.
  EquipmentReportPdfService({
    required this.fileStem,
    Future<pw.ThemeData> Function(PdfLocalization localization)? loadTheme,
  }) : loadTheme = loadTheme ?? reportSharedTheme;

  /// What the file name starts with, ahead of the print date.
  final String fileStem;

  final Future<pw.ThemeData> Function(PdfLocalization localization) loadTheme;

  /// Builds the PDF bytes without touching the filesystem. A null localization
  /// in [settings] prints English.
  Future<List<int>> generateBytes(
    R report, {
    required O options,
    required ReportPrintSettings settings,
  });

  String _fileName(DateTime printedAt) =>
      '${fileStem}_${DateFormat('yyyy-MM-dd').format(printedAt)}.pdf';

  /// Writes the PDF to the documents directory and opens the system share
  /// sheet. Returns the saved path.
  Future<String> exportToPdf(
    R report, {
    required O options,
    required ReportPrintSettings settings,
  }) async => sharePdfBytes(
    await generateBytes(report, options: options, settings: settings),
    _fileName(settings.printedAt),
  );

  /// Saves the PDF where the diver chooses. Null when they cancel.
  Future<String?> saveToFile(
    R report, {
    required O options,
    required ReportPrintSettings settings,
  }) async => savePdfToFile(
    await generateBytes(report, options: options, settings: settings),
    _fileName(settings.printedAt),
  );
}
