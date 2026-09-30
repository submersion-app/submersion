import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';

/// Localised labels for the slate; built from l10n at the call site.
class LabSlateLabels {
  const LabSlateLabels({
    required this.title,
    required this.actual,
    required this.whatIf,
    required this.delta,
    required this.branch,
    required this.mode,
    required this.interventions,
    required this.gas,
    required this.runtime,
    required this.issues,
    required this.notes,
    required this.depth,
    required this.stop,
    required this.runtimeColumn,
    required this.gasColumn,
    required this.generated,
  });
  final String title;
  final String actual;
  final String whatIf;
  final String delta;
  final String branch;
  final String mode;
  final String interventions;
  final String gas;
  final String runtime;
  final String issues;
  final String notes;
  final String depth;
  final String stop;
  final String runtimeColumn;
  final String gasColumn;
  final String generated;
}

/// One scenario section, already formatted in the diver's units (the lab's
/// own strings, so panel and slate agree).
class LabSlateScenario {
  const LabSlateScenario({
    required this.diveTitle,
    required this.scenarioName,
    required this.branchText,
    required this.modeText,
    required this.interventionLabels,
    required this.deltaRows,
    required this.gasRows,
    this.runtimeRows,
    required this.issues,
    required this.notes,
    required this.settingsText,
    this.chartPng,
  });
  final String diveTitle;
  final String scenarioName;
  final String branchText;
  final String modeText;
  final List<String> interventionLabels;

  /// label, actual, what-if, delta
  final List<List<String>> deltaRows;

  /// tank, pressures, note
  final List<List<String>> gasRows;

  /// depth, stop, runtime, gas (re-plan only)
  final List<List<String>>? runtimeRows;
  final List<String> issues;
  final List<String> notes;
  final String settingsText;
  final Uint8List? chartPng;
}

/// The printable Dive Lab slate: one section per scenario.
class DiveLabSlatePdfService {
  const DiveLabSlatePdfService();

  Future<List<int>> buildSlate({
    required List<LabSlateScenario> scenarios,
    required LabSlateLabels labels,
  }) async {
    await PdfFonts.instance.initialize();
    final pdf = pw.Document(theme: PdfFonts.instance.theme);
    for (final s in scenarios) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${labels.generated} · ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                '${labels.title}: ${s.diveTitle}',
                style: const pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              s.scenarioName,
              style: const pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Bullet(text: '${labels.branch}: ${s.branchText}'),
            pw.Bullet(text: '${labels.mode}: ${s.modeText}'),
            pw.SizedBox(height: 4),
            pw.Text(
              labels.interventions,
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            for (final i in s.interventionLabels) pw.Bullet(text: i),
            if (s.chartPng != null) ...[
              pw.SizedBox(height: 8),
              pw.Image(
                pw.MemoryImage(s.chartPng!),
                height: 220,
                fit: pw.BoxFit.contain,
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Text(
              labels.delta,
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['', labels.actual, labels.whatIf, labels.delta],
              data: s.deltaRows,
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: const pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              labels.gas,
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            if (s.gasRows.isEmpty)
              pw.Text('-', style: const pw.TextStyle(fontSize: 9))
            else
              pw.TableHelper.fromTextArray(
                data: s.gasRows,
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            if (s.runtimeRows != null) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                labels.runtime,
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: [
                  labels.depth,
                  labels.stop,
                  labels.runtimeColumn,
                  labels.gasColumn,
                ],
                data: s.runtimeRows!,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
            if (s.issues.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                labels.issues,
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              for (final i in s.issues) pw.Bullet(text: i),
            ],
            if (s.notes.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                labels.notes,
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              for (final n in s.notes) pw.Bullet(text: n),
            ],
            pw.SizedBox(height: 10),
            pw.Text(
              s.settingsText,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      );
    }
    return pdf.save();
  }
}
